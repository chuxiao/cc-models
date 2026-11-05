import Foundation
import Testing
@testable import ccmodel

/// 导入落库编排（Task 8）：三出口 `decide` 的全部行为——空值兜底、纳入新模型、
/// 覆盖已有模型、取消记录已忽略 env、落库失败回滚（对应简报验收标准逐条）。
struct ImportCoordinatorTests {

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

    /// 搭建注入临时目录的 store + writer + spy notifier。
    private func makeComponents(
        storeDirectory: URL,
        settingsDirectory: URL
    ) -> (ModelStore, SettingsWriter, ModelSwitcher, () -> [String]) {
        let store = ModelStore(directory: storeDirectory)
        let writer = SettingsWriter(directory: settingsDirectory)
        let (notifier, delivered) = makeSpyNotifier()
        let switcher = ModelSwitcher(store: store, writer: writer, notifier: notifier)
        return (store, writer, switcher, delivered)
    }

    private func profile(_ name: String, env: [String: String], selectedAt: Date? = nil) -> ModelProfile {
        ModelProfile(id: UUID(), displayName: name, env: env, lastSelectedAt: selectedAt)
    }

    private func writeSettings(_ directory: URL, _ json: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("settings.json"))
    }

    private func settingsData(in directory: URL) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent("settings.json"))
    }

    /// 载入后的可持久化准备：save 使磁盘状态与内存一致，回滚经 load 才有确定基线。
    private func persist(_ store: ModelStore) throws {
        try store.save()
    }

    private let customEnv = [
        "ANTHROPIC_BASE_URL": "https://custom.example.com",
        "ANTHROPIC_AUTH_TOKEN": "c-token",
        "ANTHROPIC_MODEL": "custom-model",
    ]
    private let zhipuEnv = [
        "ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "z-token",
        "ANTHROPIC_MODEL": "glm-4.7",
    ]
    private let deepseekEnv = [
        "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
        "ANTHROPIC_AUTH_TOKEN": "d-token",
        "ANTHROPIC_MODEL": "deepseek-chat",
    ]

    // MARK: - 空值兜底

    @Test func emptyEnvThrowsForNewModelAndOverwriteWithoutTouchingStoreOrSettings() throws {
        try withTemporaryDirectory { dir in
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            store.add(zhipu)
            try persist(store)

            #expect(throws: ImportCoordinator.ImportError.emptyEnv) {
                try ImportCoordinator.decide(.newModel(name: "Test"), env: [:], store: store, switcher: switcher)
            }
            #expect(throws: ImportCoordinator.ImportError.emptyEnv) {
                try ImportCoordinator.decide(.overwrite(targetID: zhipu.id), env: [:], store: store, switcher: switcher)
            }

            // store 不变、settings 未被写入、无任何通知
            #expect(store.configuration.models == [zhipu])
            #expect(!FileManager.default.fileExists(atPath: writer.settingsURL.path))
            #expect(delivered() == [])
        }
    }

    // MARK: - 纳入新模型

    @Test func duplicateDisplayNameThrowsAndAddsNothing() throws {
        try withTemporaryDirectory { dir in
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            store.add(zhipu)
            try persist(store)

            #expect(throws: ProfileFields.ValidationError.duplicateDisplayName) {
                try ImportCoordinator.decide(.newModel(name: "智谱"), env: customEnv, store: store, switcher: switcher)
            }

            #expect(store.configuration.models.count == 1)
            #expect(try writer.readEnv() == [:])
            #expect(delivered() == [])
        }
    }

    @Test func blankDisplayNameThrowsAndAddsNothing() throws {
        try withTemporaryDirectory { dir in
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            store.add(profile("智谱", env: zhipuEnv))
            try persist(store)

            #expect(throws: ProfileFields.ValidationError.emptyDisplayName) {
                try ImportCoordinator.decide(.newModel(name: "   "), env: customEnv, store: store, switcher: switcher)
            }

            #expect(store.configuration.models.count == 1)
            #expect(delivered() == [])
        }
    }

    @Test func newModelAddsTrimmedModelBecomesCurrentAndNotifies() throws {
        try withTemporaryDirectory { dir in
            let storeDir = dir.appendingPathComponent("store")
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: settingsDir
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            store.add(zhipu)
            try store.setDefault(id: zhipu.id)
            try persist(store)
            // 当前 env 未命中任何模型（自定义配置状态）
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "https://unmatched"}}"#)

            try ImportCoordinator.decide(.newModel(name: "  Test  "), env: customEnv, store: store, switcher: switcher)

            // 列表 +1；显示名去空白落库；env 快照为捕获后的完整键组
            #expect(store.configuration.models.count == 2)
            let added = store.configuration.models[1]
            #expect(added.displayName == "Test")
            #expect(added.env == customEnv)
            // 经 switchTo 成为当前 + lastSelectedAt 更新 + settings 写入 + 成功通知逐字
            #expect(switcher.currentModelID() == added.id)
            #expect(added.lastSelectedAt != nil)
            #expect(try writer.readEnv() == customEnv)
            #expect(delivered() == ["已切换到Test，对新建会话生效"])
            // 默认标记不被纳入路径改动
            #expect(store.configuration.defaultModelID == zhipu.id)
            // 落盘持久化（switchTo 内部 save）：新 store 重读可验证
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.configuration.models.count == 2)
        }
    }

    // MARK: - 覆盖已有模型

    @Test func overwriteReplacesTargetEnvKeepsIdentityAndBecomesCurrent() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            let oldDate = Date(timeIntervalSinceReferenceDate: 100)
            // 目标 env 多一键，覆盖后键集合应整体替换
            var zhipuEnvWithExtraKey = zhipuEnv
            zhipuEnvWithExtraKey["ANTHROPIC_DEFAULT_SONNET_MODEL"] = "glm-x"
            let zhipu = profile("智谱", env: zhipuEnvWithExtraKey, selectedAt: oldDate)
            let deepseek = profile("DeepSeek", env: deepseekEnv)
            store.add(zhipu)
            store.add(deepseek)
            try store.setDefault(id: zhipu.id)
            try persist(store)
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "https://unmatched"}}"#)

            try ImportCoordinator.decide(.overwrite(targetID: zhipu.id), env: customEnv, store: store, switcher: switcher)

            // 目标 env 整体替换（键集合也换）；displayName 与 defaultModelID 保持
            let overwritten = store.configuration.models[0]
            #expect(overwritten.id == zhipu.id)
            #expect(overwritten.env == customEnv)
            #expect(overwritten.displayName == "智谱")
            #expect(store.configuration.defaultModelID == zhipu.id)
            // lastSelectedAt 更新、成为当前、settings 写入、成功通知
            #expect(overwritten.lastSelectedAt != nil)
            #expect((overwritten.lastSelectedAt?.timeIntervalSince(oldDate) ?? 0) > 0)
            #expect(switcher.currentModelID() == zhipu.id)
            #expect(try writer.readEnv() == customEnv)
            #expect(delivered() == ["已切换到智谱，对新建会话生效"])
            // 非目标模型不受影响
            #expect(store.configuration.models[1] == deepseek)
        }
    }

    // MARK: - 取消

    @Test func cancelRecordsDismissedEnvWithContentEquivalenceAndPersists() throws {
        try withTemporaryDirectory { dir in
            let storeDir = dir.appendingPathComponent("store")
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: settingsDir
            )
            store.add(profile("智谱", env: zhipuEnv))
            try persist(store)

            // 入参含非 ANTHROPIC 键：dismissed 以捕获后的内容为准（内容等价口径）
            var envWithNoise = customEnv
            envWithNoise["UNRELATED_KEY"] = "noise"
            try ImportCoordinator.decide(.cancel, env: envWithNoise, store: store, switcher: switcher)

            // 同 env 查 true（内容等价：噪声键被捕获过滤）
            #expect(store.isDismissedEnv(customEnv))
            // 任一 ANTHROPIC 键值变化 → 视为新状态
            var changedEnv = customEnv
            changedEnv["ANTHROPIC_MODEL"] = "another-model"
            #expect(!store.isDismissedEnv(changedEnv))
            // settings 不被取消路径触碰
            #expect(try writer.readEnv() == [:])
            #expect(delivered() == [])
            // 取消持久化：新 store 重读后 dismissed 仍在
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.isDismissedEnv(customEnv))
        }
    }

    // MARK: - 落库失败回滚

    @Test func newModelRollsBackMemoryWhenSwitchFailsAndSettingsUntouched() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "a"}, "#)
            let corruptBytes = try settingsData(in: settingsDir)
            let (store, _, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            store.add(zhipu)
            try persist(store)

            #expect(throws: SettingsWriter.SettingsWriterError.invalidJSON) {
                try ImportCoordinator.decide(.newModel(name: "Test"), env: customEnv, store: store, switcher: switcher)
            }

            // 内存回滚：新模型不入列表；settings 字节不变
            #expect(store.configuration.models == [zhipu])
            #expect(try settingsData(in: settingsDir) == corruptBytes)
            #expect(delivered() == ["切换到Test失败，已保留原配置"])
        }
    }

    @Test func overwriteRollsBackTargetEnvWhenSwitchFails() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "a"}, "#)
            let (store, _, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            store.add(zhipu)
            try persist(store)

            #expect(throws: SettingsWriter.SettingsWriterError.invalidJSON) {
                try ImportCoordinator.decide(.overwrite(targetID: zhipu.id), env: customEnv, store: store, switcher: switcher)
            }

            // 内存回滚：目标 env 保持原键组
            #expect(store.configuration.models == [zhipu])
            #expect(delivered() == ["切换到智谱失败，已保留原配置"])
        }
    }

    // MARK: - 决策枚举

    @Test func importDecisionIsEquatable() {
        let id = UUID()
        #expect(ImportDecision.newModel(name: "A") == ImportDecision.newModel(name: "A"))
        #expect(ImportDecision.overwrite(targetID: id) == ImportDecision.overwrite(targetID: id))
        #expect(ImportDecision.cancel == .cancel)
        #expect(ImportDecision.newModel(name: "A") != .cancel)
    }
}
