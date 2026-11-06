import AppKit
import Foundation
import Testing
@testable import ccmodel

/// 切换编排：env 替换、lastSelectedAt 落盘、通知文案逐字与失败不变性（Task 5 验收标准对应）。
struct ModelSwitcherTests {

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

    // MARK: - switchTo 成功

    @Test func switchToReplacesEnvPersistsSelectionAndNotifiesSuccessVerbatim() throws {
        try withTemporaryDirectory { dir in
            let storeDir = dir.appendingPathComponent("store")
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: storeDir,
                settingsDirectory: settingsDir
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            let deepseek = profile("DeepSeek", env: deepseekEnv)
            store.add(zhipu)
            store.add(deepseek)

            try switcher.switchTo(id: deepseek.id)

            // settings env 已整体替换为目标模型键组
            #expect(try writer.readEnv() == deepseekEnv)
            // lastSelectedAt 已更新并落盘（新 store 重读验证）
            let reloaded = ModelStore(directory: storeDir)
            try reloaded.load()
            #expect(reloaded.configuration.models.first { $0.id == deepseek.id }?.lastSelectedAt != nil)
            #expect(reloaded.configuration.models.first { $0.id == zhipu.id }?.lastSelectedAt == nil)
            // 成功文案逐字
            #expect(delivered() == ["已切换到DeepSeek，对新建会话生效"])
        }
    }

    // MARK: - switchTo 失败

    @Test func switchToWithWriterFailureNotifiesFailureAndLeavesStoreAndSettingsUntouched() throws {
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

            #expect(throws: SettingsWriter.SettingsWriterError.invalidJSON) {
                try switcher.switchTo(id: zhipu.id)
            }

            // 失败文案逐字
            #expect(delivered() == ["切换到智谱失败，已保留原配置"])
            // store 未变：未 markSelected、未 save（config.json 不存在）
            #expect(store.configuration.models[0].lastSelectedAt == nil)
            #expect(!FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("store/config.json").path
            ))
            // settings.json 字节不变
            #expect(try settingsData(in: settingsDir) == corruptBytes)
        }
    }

    @Test func switchToWithUnknownIDThrowsWithoutTouchingWriterOrNotifier() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "a"}}"#)
            let originalBytes = try settingsData(in: settingsDir)
            let (_, _, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )

            #expect(throws: ModelSwitcher.ModelSwitcherError.modelNotFound) {
                try switcher.switchTo(id: UUID())
            }

            #expect(delivered() == [])
            #expect(try settingsData(in: settingsDir) == originalBytes)
        }
    }

    // MARK: - currentModelID

    @Test func currentModelIDMatchesModelWhoseEnvEqualsCapturedSettingsEnv() throws {
        try withTemporaryDirectory { dir in
            let (store, _, switcher, _) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: dir.appendingPathComponent("claude")
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            store.add(zhipu)
            try writeSettings(
                dir.appendingPathComponent("claude"),
                #"{"env": {"ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic", "ANTHROPIC_AUTH_TOKEN": "z-token", "ANTHROPIC_MODEL": "glm-4.7", "OTHER": "keep"}}"#
            )

            #expect(switcher.currentModelID() == zhipu.id)
        }
    }

    @Test func currentModelIDReturnsNilWhenNoModelMatches() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, _, switcher, _) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            store.add(profile("智谱", env: zhipuEnv))
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "https://unmatched"}}"#)

            #expect(switcher.currentModelID() == nil)
        }
    }

    @Test func currentModelIDAndCurrentEnvReturnNilWhenSettingsAreCorrupt() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, _, switcher, _) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            store.add(profile("智谱", env: zhipuEnv))
            try writeSettings(settingsDir, "{ not json")

            #expect(switcher.currentModelID() == nil)
            #expect(switcher.currentEnv() == nil)
        }
    }

    // MARK: - applyEnv

    @Test func applyEnvReplacesEnvNotifiesSuccessWithoutTouchingLastSelectedAt() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            let fixedDate = Date(timeIntervalSinceReferenceDate: 100)
            let zhipu = profile("智谱", env: zhipuEnv, selectedAt: fixedDate)
            store.add(zhipu)

            try switcher.applyEnv(zhipuEnv)

            #expect(try writer.readEnv() == zhipuEnv)
            #expect(store.configuration.models[0].lastSelectedAt == fixedDate)
            #expect(delivered() == ["已切换到智谱，对新建会话生效"])
        }
    }

    @Test func applyEnvWithUnmatchedEnvReplacesButStaysSilent() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, writer, switcher, delivered) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            store.add(profile("智谱", env: zhipuEnv))

            try switcher.applyEnv(["ANTHROPIC_BASE_URL": "https://custom"])

            #expect(try writer.readEnv() == ["ANTHROPIC_BASE_URL": "https://custom"])
            #expect(delivered() == [])
        }
    }

    // MARK: - Notifier 文案逐字

    @Test func notifierCopyIsVerbatimForSuccessAndFailure() {
        let (notifier, delivered) = makeSpyNotifier()

        notifier.postSwitchSuccess(modelName: "智谱")
        notifier.postSwitchFailure(modelName: "DeepSeek")

        #expect(delivered() == [
            "已切换到智谱，对新建会话生效",
            "切换到DeepSeek失败，已保留原配置",
        ])
    }

    // MARK: - menuDidClose 自定义配置触发时序

    /// 回调与延后判定的 spy（引用语义，可被逃逸闭包捕获）。
    private final class MenuCloseSpy {
        var callbacks: [[String: String]] = []
        var pendingEvaluations: [() -> Void] = []
    }

    /// 搭建带回调 spy 与「延后执行暂存」缝的控制器；测试手动推进延后的判定。
    private func makeController(
        store: ModelStore,
        switcher: ModelSwitcher,
        spy: MenuCloseSpy
    ) -> StatusItemController {
        let controller = StatusItemController(
            store: store,
            switcher: switcher,
            onCustomConfigDetected: { spy.callbacks.append($0) }
        )
        controller.deferMenuCloseEvaluation = { spy.pendingEvaluations.append($0) }
        return controller
    }

    @Test func menuDidCloseDefersEvaluationAndSkipsCallbackAfterPendingSwitchLands() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, _, switcher, _) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            let zhipu = profile("智谱", env: zhipuEnv)
            store.add(zhipu)
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "https://unmatched"}}"#)

            let spy = MenuCloseSpy()
            let controller = makeController(store: store, switcher: switcher, spy: spy)

            // 关菜单：判定被延后一轮，此刻不回调
            controller.menuDidClose(NSMenu())
            #expect(spy.callbacks.isEmpty)
            #expect(spy.pendingEvaluations.count == 1)

            // 菜单跟踪期内的条目 action（点击模型项 → switchTo）先于延后判定落地
            try switcher.switchTo(id: zhipu.id)

            // 延后一轮执行判定：env 已命中 → 不回调
            for evaluate in spy.pendingEvaluations { evaluate() }
            #expect(spy.callbacks.isEmpty)
        }
    }

    @Test func menuDidCloseTriggersCallbackOnceWhenEnvStillUnmatchedAfterDeferredEvaluation() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, _, switcher, _) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            store.add(profile("智谱", env: zhipuEnv))
            let unmatchedEnv = ["ANTHROPIC_BASE_URL": "https://unmatched"]
            try writeSettings(settingsDir, #"{"env": {"ANTHROPIC_BASE_URL": "https://unmatched"}}"#)

            let spy = MenuCloseSpy()
            let controller = makeController(store: store, switcher: switcher, spy: spy)

            controller.menuDidClose(NSMenu())
            #expect(spy.callbacks.isEmpty)

            for evaluate in spy.pendingEvaluations { evaluate() }
            #expect(spy.callbacks == [unmatchedEnv])
        }
    }

    // MARK: - 状态项标题刷新时序

    @Test func menuNeedsUpdateRefreshesTitleAfterExternalEnvChange() throws {
        try withTemporaryDirectory { dir in
            let settingsDir = dir.appendingPathComponent("claude")
            let (store, writer, switcher, _) = makeComponents(
                storeDirectory: dir.appendingPathComponent("store"),
                settingsDirectory: settingsDir
            )
            store.add(profile("智谱", env: zhipuEnv))
            // settings.json 尚不存在 → env 为空，无法识别当前模型
            let controller = StatusItemController(store: store, switcher: switcher, onCustomConfigDetected: { _ in })
            var titles: [String] = []
            controller.titleWriter = { titles.append($0) }

            // 外部改动前的第一次开菜单：未知态标题
            controller.menuNeedsUpdate(NSMenu())
            #expect(titles == ["⇄ —"])

            // 外部把 env 改为命中智谱（手改 settings.json / Claude Code 更新器写入）
            try writer.replaceAnthropicEnv(with: zhipuEnv)

            // 第二次开菜单：标题随菜单同周期刷新，不再显示旧状态（终审修复行为）
            controller.menuNeedsUpdate(NSMenu())
            #expect(titles == ["⇄ —", "⇄ 智谱"])
        }
    }
}
