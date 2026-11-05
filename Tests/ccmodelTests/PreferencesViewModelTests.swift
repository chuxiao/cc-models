import Foundation
import Testing
@testable import ccmodel

/// PreferencesViewModel 全行为（Task 7 验收标准对应）：列表稳定顺序与选中表单、
/// 删除守卫与默认补位、删除当前生效模型不触 writer、校验名单排自身、
/// 默认唯一两向、编辑生效中模型立即应用与登录项开关回拨。
/// `LoginItem.setEnabledHandler` 是进程级静态测试缝，套件必须串行以防并行互踩。
@Suite(.serialized)
struct PreferencesViewModelTests {

    /// LoginItem 替身的抛错类型。
    private struct LoginItemFailure: Error {}

    // MARK: - 测试设施

    /// 在唯一临时目录中执行（落盘测试用），结束即清理，绝不触碰真实 ~/.claude。
    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccmodel-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    /// 经 deliveryHandler 注入缝捕获全部文案，返回读取闭包（捕获变量按引用）。
    private func makeSpyNotifier() -> (Notifier, () -> [String]) {
        let notifier = Notifier()
        var delivered: [String] = []
        notifier.deliveryHandler = { delivered.append($0) }
        return (notifier, { delivered })
    }

    /// 搭建注入临时目录的 store + writer + spy notifier + switcher；
    /// ViewModel 由用例在模型入列后自行构造（init 即完成首次同步）。
    private func makeComponents(
        storeDirectory: URL,
        settingsDirectory: URL
    ) -> (store: ModelStore, writer: SettingsWriter, switcher: ModelSwitcher, delivered: () -> [String]) {
        let store = ModelStore(directory: storeDirectory)
        let writer = SettingsWriter(directory: settingsDirectory)
        let (notifier, delivered) = makeSpyNotifier()
        let switcher = ModelSwitcher(store: store, writer: writer, notifier: notifier)
        return (store, writer, switcher, delivered)
    }

    private func writeSettings(_ directory: URL, _ json: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("settings.json"))
    }

    private func settingsData(in directory: URL) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent("settings.json"))
    }

    private func profile(
        _ name: String,
        env: [String: String] = [:],
        selectedAt: Date? = nil
    ) -> ModelProfile {
        ModelProfile(id: UUID(), displayName: name, env: env, lastSelectedAt: selectedAt)
    }

    /// 进入新建态并填好三必填（displayName、isDefault 由用例给定）。
    private func beginFilledAdd(
        _ viewModel: PreferencesViewModel,
        displayName: String,
        isDefault: Bool = false
    ) {
        viewModel.beginAdd()
        viewModel.form.displayName = displayName
        viewModel.form.baseURL = "https://new.example"
        viewModel.form.token = "token-new"
        viewModel.form.mainModel = "model-new"
        viewModel.form.isDefault = isDefault
    }

    private let envA = [
        "ANTHROPIC_BASE_URL": "https://a.example",
        "ANTHROPIC_AUTH_TOKEN": "token-a",
        "ANTHROPIC_MODEL": "model-a",
    ]
    private let envB = [
        "ANTHROPIC_BASE_URL": "https://b.example",
        "ANTHROPIC_AUTH_TOKEN": "token-b",
        "ANTHROPIC_MODEL": "model-b",
    ]

    // MARK: - 列表与选中

    @Test func initLoadsListInAdditionOrderSelectsFirstAndLoadsItsForm() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A", env: envA) // 从未选中
            let b = profile("B", env: envB, selectedAt: Date(timeIntervalSinceReferenceDate: 300))
            c.store.add(a)
            c.store.add(b)
            try c.store.setDefault(id: b.id)

            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            // 侧栏按添加顺序稳定展示，不受菜单重排（b 最近选中会被菜单置顶）影响
            #expect(viewModel.modelList == [a, b])
            #expect(viewModel.selectedID == a.id)
            // 表单载入首个模型，默认标记按配置事实（a 非默认）
            #expect(viewModel.form.displayName == "A")
            #expect(viewModel.form.baseURL == "https://a.example")
            #expect(viewModel.form.token == "token-a")
            #expect(viewModel.form.mainModel == "model-a")
            #expect(viewModel.form.isDefault == false)
            #expect(viewModel.defaultModelID == b.id)
        }
    }

    @Test func selectLoadsFormAndReflectsDefaultMarker() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A", env: envA)
            let b = profile("B", env: envB)
            c.store.add(a)
            c.store.add(b)
            try c.store.setDefault(id: b.id)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            viewModel.select(id: b.id)
            #expect(viewModel.selectedID == b.id)
            #expect(viewModel.form.displayName == "B")
            #expect(viewModel.form.isDefault == true)

            viewModel.select(id: a.id)
            #expect(viewModel.form.isDefault == false)

            // 不存在的 id 忽略，选中不变
            viewModel.select(id: UUID())
            #expect(viewModel.selectedID == a.id)
        }
    }

    @Test func reloadRefreshesListFromStoreAndDiscardsPendingFormEdits() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A")
            let b = profile("B")
            c.store.add(a)
            c.store.add(b)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            viewModel.select(id: a.id)
            viewModel.form.displayName = "挂起改动"
            let newModel = profile("C")
            c.store.add(newModel)

            viewModel.reload()

            #expect(viewModel.modelList.map(\.displayName) == ["A", "B", "C"])
            #expect(viewModel.selectedID == a.id)
            #expect(viewModel.form.displayName == "A") // 挂起编辑被落库事实覆盖

            // 选中失效时回落首个
            try c.store.delete(id: a.id)
            viewModel.reload()
            #expect(viewModel.selectedID == b.id)
            #expect(viewModel.form.displayName == "B")
        }
    }

    // MARK: - 开机自启初值

    @Test func launchAtLoginInitialValueComesFromPersistedStore() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            c.store.add(profile("A"))

            // 持久事实缺省 → 关
            let fresh = PreferencesViewModel(store: c.store, switcher: c.switcher)
            #expect(fresh.launchAtLogin == false)

            // 持久事实为开 → 初值取 store（不读 LoginItem.isEnabled）
            c.store.setLaunchAtLogin(true)
            try c.store.save()
            let persisted = PreferencesViewModel(store: c.store, switcher: c.switcher)
            #expect(persisted.launchAtLogin == true)
        }
    }

    // MARK: - canDelete 边界

    @Test func canDeleteRequiresAtLeastTwoModels() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A")
            c.store.add(a)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            #expect(!viewModel.canDelete) // 仅剩一个 → false，对应 － 置灰

            c.store.add(profile("B"))
            viewModel.reload()
            #expect(viewModel.canDelete)
        }
    }

    // MARK: - deleteSelected

    @Test func deleteSelectedThrowsWhenOnlyOneModelRemains() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A")
            c.store.add(a)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            #expect(throws: PreferencesViewModel.PreferencesError.cannotDeleteLastModel) { try viewModel.deleteSelected() }
            #expect(viewModel.modelList.count == 1)
        }
    }

    @Test func deleteSelectedThrowsWhenNothingSelected() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            c.store.add(profile("A"))
            c.store.add(profile("B"))
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            viewModel.beginAdd() // 新建态：selectedID == nil
            #expect(throws: PreferencesViewModel.PreferencesError.noModelSelected) { try viewModel.deleteSelected() }
            #expect(viewModel.modelList.count == 2)
        }
    }

    @Test func deleteSelectedRemovesModelPromotesFirstAsDefaultAndReselects() throws {
        try withTemporaryDirectory { dir in
            let storeDir = dir.appendingPathComponent("store")
            let c = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A")
            let b = profile("B")
            c.store.add(a)
            c.store.add(b)
            try c.store.setDefault(id: b.id)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: b.id)

            try viewModel.deleteSelected()

            #expect(viewModel.modelList.map(\.displayName) == ["A"])
            #expect(viewModel.defaultModelID == a.id) // 删除默认 → 首个补位（Task 2 语义）
            #expect(viewModel.selectedID == a.id) // 选中回落
            #expect(viewModel.form.displayName == "A")
            // 已落盘
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.configuration.models.count == 1)
            #expect(reloaded.configuration.defaultModelID == a.id)
        }
    }

    @Test func deleteCurrentModelKeepsSettingsBytesAndStaysSilent() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(
                settingsDir,
                #"{"env": {"ANTHROPIC_BASE_URL": "https://a.example", "ANTHROPIC_AUTH_TOKEN": "token-a", "ANTHROPIC_MODEL": "model-a"}}"#
            )
            let originalBytes = try settingsData(in: settingsDir)
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            let a = profile("A", env: envA)
            c.store.add(a)
            c.store.add(profile("B", env: envB))
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: a.id) // a 为当前生效模型

            try viewModel.deleteSelected()

            // 只删记录不写 env：settings.json 字节不变、无通知、env 未漂移
            #expect(try settingsData(in: settingsDir) == originalBytes)
            #expect(c.delivered() == [])
            #expect(try c.writer.readEnv() == envA)
            #expect(viewModel.modelList.map(\.displayName) == ["B"])
        }
    }

    // MARK: - saveForm：校验

    @Test func saveFormValidationFailureThrowsAndKeepsStoreAndSettingsUntouched() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(
                settingsDir,
                #"{"env": {"ANTHROPIC_BASE_URL": "https://a.example", "ANTHROPIC_AUTH_TOKEN": "token-a", "ANTHROPIC_MODEL": "model-a"}}"#
            )
            let originalBytes = try settingsData(in: settingsDir)
            let storeDir = dir.appendingPathComponent("store")
            let c = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: settingsDir
            )
            c.store.add(profile("A", env: envA))
            let b = profile("B", env: envB)
            c.store.add(b)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: b.id)
            viewModel.form.displayName = "A" // 与已有模型重名

            #expect(throws: PreferencesViewModel.PreferencesError.validation([.duplicateDisplayName])) {
                try viewModel.saveForm()
            }

            // 逐字段提示已写入表单
            #expect(viewModel.form.validationErrors == [.duplicateDisplayName])
            // store 不变（未落库、未落盘）
            #expect(c.store.configuration.models.map(\.displayName) == ["A", "B"])
            #expect(!FileManager.default.fileExists(
                atPath: storeDir.appendingPathComponent("config.json").path
            ))
            // settings 未触达
            #expect(try settingsData(in: settingsDir) == originalBytes)
            #expect(c.delivered() == [])
        }
    }

    @Test func saveFormKeepsUnchangedNameWithoutDuplicateFalsePositive() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A", env: envA)
            c.store.add(a)
            c.store.add(profile("B", env: envB))
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: a.id)
            viewModel.form.token = "token-a-rotated" // 编辑不改名

            try viewModel.saveForm() // 不误报重名

            #expect(c.store.configuration.models.first { $0.id == a.id }?
                .env["ANTHROPIC_AUTH_TOKEN"] == "token-a-rotated")
            #expect(viewModel.form.validationErrors.isEmpty)
        }
    }

    // MARK: - saveForm：编辑生效中模型立即应用

    @Test func saveFormOnCurrentModelAppliesEnvImmediatelyPersistsAndNotifies() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(
                settingsDir,
                #"{"env": {"ANTHROPIC_BASE_URL": "https://a.example", "ANTHROPIC_AUTH_TOKEN": "token-a", "ANTHROPIC_MODEL": "model-a"}}"#
            )
            let storeDir = dir.appendingPathComponent("store")
            let c = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: settingsDir
            )
            let a = profile("A", env: envA)
            c.store.add(a)
            c.store.add(profile("B", env: envB))
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: a.id) // a 为当前生效模型
            viewModel.form.mainModel = "model-a2"

            try viewModel.saveForm()

            // env 替换发生（以临时目录 writer 的文件状态断言）
            #expect(try c.writer.readEnv() == [
                "ANTHROPIC_BASE_URL": "https://a.example",
                "ANTHROPIC_AUTH_TOKEN": "token-a",
                "ANTHROPIC_MODEL": "model-a2",
            ])
            // 成功通知逐字（applyEnv → detector 命中新 env）
            #expect(c.delivered() == ["已切换到A，对新建会话生效"])
            // store 已更新并落盘
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.configuration.models.first { $0.id == a.id }?
                .env["ANTHROPIC_MODEL"] == "model-a2")
            // 表单与落库事实一致
            #expect(viewModel.form.mainModel == "model-a2")
        }
    }

    @Test func saveFormOnNonCurrentModelDoesNotTouchWriter() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(
                settingsDir,
                #"{"env": {"ANTHROPIC_BASE_URL": "https://a.example", "ANTHROPIC_AUTH_TOKEN": "token-a", "ANTHROPIC_MODEL": "model-a"}}"#
            )
            let originalBytes = try settingsData(in: settingsDir)
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            c.store.add(profile("A", env: envA))
            let b = profile("B", env: envB)
            c.store.add(b)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: b.id) // b 不是当前生效模型
            viewModel.form.mainModel = "model-b2"

            try viewModel.saveForm()

            // 不是当前 → 不写 env、无通知
            #expect(try settingsData(in: settingsDir) == originalBytes)
            #expect(c.delivered() == [])
            // store 已更新
            #expect(c.store.configuration.models.first { $0.id == b.id }?
                .env["ANTHROPIC_MODEL"] == "model-b2")
        }
    }

    // MARK: - saveForm：新建

    @Test func saveNewModelAppendsSelectsAndStaysNonCurrentNonDefault() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(
                settingsDir,
                #"{"env": {"ANTHROPIC_BASE_URL": "https://a.example", "ANTHROPIC_AUTH_TOKEN": "token-a", "ANTHROPIC_MODEL": "model-a"}}"#
            )
            let originalBytes = try settingsData(in: settingsDir)
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            let a = profile("A", env: envA)
            c.store.add(a)
            try c.store.setDefault(id: a.id)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            beginFilledAdd(viewModel, displayName: "B")
            try viewModel.saveForm()

            let newID = try #require(viewModel.selectedID)
            #expect(viewModel.modelList.map(\.displayName) == ["A", "B"]) // 追加到列表尾
            #expect(viewModel.defaultModelID == a.id) // 不自动默认
            // 不自动成为当前：settings 未触达、无通知
            #expect(try settingsData(in: settingsDir) == originalBytes)
            #expect(c.delivered() == [])
            #expect(try c.writer.readEnv() == envA)
            // 表单进入已保存态
            #expect(viewModel.form.displayName == "B")
            #expect(viewModel.form.validationErrors.isEmpty)
        }
    }

    @Test func saveNewModelWithDefaultCheckedMovesDefaultMarker() throws {
        try withTemporaryDirectory { dir in
            let storeDir = dir.appendingPathComponent("store")
            let c = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A")
            c.store.add(a)
            try c.store.setDefault(id: a.id)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)

            beginFilledAdd(viewModel, displayName: "B", isDefault: true)
            try viewModel.saveForm()

            #expect(viewModel.defaultModelID == viewModel.selectedID) // 勾选 → 新模型成为默认
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.configuration.defaultModelID == viewModel.selectedID)
        }
    }

    // MARK: - 默认唯一

    @Test func saveExistingWithDefaultCheckedOverridesOldDefault() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A", env: envA)
            let b = profile("B", env: envB)
            c.store.add(a)
            c.store.add(b)
            try c.store.setDefault(id: a.id)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: b.id)
            viewModel.form.isDefault = true

            try viewModel.saveForm()

            #expect(viewModel.defaultModelID == b.id) // 覆盖旧默认
        }
    }

    @Test func saveExistingUncheckedDefaultFallsBackToFirstModel() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A", env: envA)
            let b = profile("B", env: envB)
            c.store.add(a)
            c.store.add(b)
            try c.store.setDefault(id: b.id)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: b.id)
            #expect(viewModel.form.isDefault == true)
            viewModel.form.isDefault = false

            try viewModel.saveForm()

            #expect(viewModel.defaultModelID == a.id) // 回落 models 首个
        }
    }

    @Test func saveExistingUncheckedDefaultOnFirstModelStaysDefault() throws {
        try withTemporaryDirectory { dir in
            let c = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let a = profile("A", env: envA)
            let b = profile("B", env: envB)
            c.store.add(a)
            c.store.add(b)
            try c.store.setDefault(id: a.id)
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            viewModel.select(id: a.id) // 首个即被编辑模型自身
            viewModel.form.isDefault = false

            try viewModel.saveForm()

            // 「回落 models 首个」的字面语义：首个即自身 → 保持默认
            #expect(viewModel.defaultModelID == a.id)
        }
    }

    // MARK: - setLaunchAtLogin

    @Test func setLaunchAtLoginPersistsStoreFactAndDelegatesToLoginItem() throws {
        try withTemporaryDirectory { dir in
            let storeDir = dir.appendingPathComponent("store")
            let c = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            c.store.add(profile("A"))
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            var calls: [Bool] = []
            LoginItem.setEnabledHandler = { calls.append($0) }
            defer { LoginItem.setEnabledHandler = nil }

            viewModel.setLaunchAtLogin(true)

            #expect(calls == [true])
            #expect(viewModel.launchAtLogin == true)
            #expect(viewModel.alertMessage == nil)
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.configuration.launchAtLogin == true) // 已持久化

            viewModel.setLaunchAtLogin(false)

            #expect(calls == [true, false])
            #expect(viewModel.launchAtLogin == false)
            let reloadedAgain = ModelStore(directory: storeDir)
            try reloadedAgain.load()
            #expect(reloadedAgain.configuration.launchAtLogin == false)
        }
    }

    @Test func setLaunchAtLoginFailureRollsBackToggleKeepsStoreUntouchedAndAlerts() throws {
        try withTemporaryDirectory { dir in
            let storeDir = dir.appendingPathComponent("store")
            let c = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            c.store.add(profile("A"))
            let viewModel = PreferencesViewModel(store: c.store, switcher: c.switcher)
            LoginItem.setEnabledHandler = { _ in throw LoginItemFailure() }
            defer { LoginItem.setEnabledHandler = nil }

            viewModel.setLaunchAtLogin(true)

            // 开关回拨为 false、store 不变、界面提示
            #expect(viewModel.launchAtLogin == false)
            #expect(c.store.configuration.launchAtLogin == false)
            #expect(!FileManager.default.fileExists(
                atPath: storeDir.appendingPathComponent("config.json").path
            ))
            #expect(viewModel.alertMessage != nil)

            // 反方向：先成功开启，再失败关闭 → 回拨为 true、store 保持 true
            LoginItem.setEnabledHandler = { _ in }
            viewModel.setLaunchAtLogin(true)
            #expect(viewModel.launchAtLogin == true)
            LoginItem.setEnabledHandler = { _ in throw LoginItemFailure() }
            viewModel.setLaunchAtLogin(false)
            #expect(viewModel.launchAtLogin == true)
            #expect(c.store.configuration.launchAtLogin == true)
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.configuration.launchAtLogin == true)
        }
    }
}
