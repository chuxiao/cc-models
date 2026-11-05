import Foundation
import Testing
@testable import ccmodel

/// ModelStore 持久化、CRUD、排序与已忽略 env 状态（Task 2 验收标准对应）。
struct ModelStoreTests {

    // MARK: - 测试设施

    /// 内存级 store：init 不触碰文件系统，可直接用于不落盘的行为测试。
    private func makeStore() -> ModelStore {
        ModelStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ccmodel-tests-\(UUID().uuidString)", isDirectory: true))
    }

    /// 在唯一临时目录中执行（落盘测试用），结束即清理，绝不触碰真实配置目录。
    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccmodel-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func profile(
        _ name: String,
        env: [String: String] = [:],
        selectedAt: Date? = nil
    ) -> ModelProfile {
        ModelProfile(id: UUID(), displayName: name, env: env, lastSelectedAt: selectedAt)
    }

    private func posixPermissions(of path: String) throws -> Int? {
        (try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber)?.intValue
    }

    // MARK: - 往返与权限

    @Test func roundtripPreservesFullConfiguration() throws {
        try withTemporaryDirectory { dir in
            let store = ModelStore(directory: dir)
            let glm = profile(
                "GLM",
                env: ["ANTHROPIC_BASE_URL": "https://a.example", "OTHER": "noise"],
                selectedAt: Date(timeIntervalSinceReferenceDate: 800123456.7891235)
            )
            let kimi = profile(
                "Kimi",
                env: ["ANTHROPIC_AUTH_TOKEN": "sk-2", "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "Sonnet X"],
                selectedAt: Date(timeIntervalSinceReferenceDate: 700999.125)
            )
            store.add(glm)
            store.add(kimi)
            try store.setDefault(id: kimi.id)
            store.recordDismissedEnv(["ANTHROPIC_BASE_URL": "https://x", "PATH": "/usr/bin:/bin"])
            try store.save()

            let reloaded = ModelStore(directory: dir)
            try reloaded.load()
            #expect(reloaded.configuration == store.configuration)
        }
    }

    @Test func savedFileHas0600Permissions() throws {
        try withTemporaryDirectory { dir in
            let store = ModelStore(directory: dir)
            store.add(profile("GLM"))
            try store.save()
            #expect(try posixPermissions(of: dir.appendingPathComponent("config.json").path) == 0o600)
        }
    }

    @Test func saveCreatesMissingDirectoryWith0700Permissions() throws {
        try withTemporaryDirectory { base in
            let nested = base.appendingPathComponent("cc-model", isDirectory: true)
            let store = ModelStore(directory: nested)
            try store.save()
            #expect(try posixPermissions(of: nested.path) == 0o700)
        }
    }

    // MARK: - load

    @Test func loadWithMissingFileYieldsDefaultEmptyConfiguration() throws {
        try withTemporaryDirectory { dir in
            let store = ModelStore(directory: dir)
            try store.load()
            #expect(store.configuration == AppConfiguration())

            // 已有配置后文件被移除：再次 load 重置为默认空配置
            let model = profile("GLM")
            store.add(model)
            try store.save()
            try store.load()
            #expect(store.configuration.models == [model])
            try FileManager.default.removeItem(at: dir.appendingPathComponent("config.json"))
            try store.load()
            #expect(store.configuration == AppConfiguration())
        }
    }

    @Test func loadCorruptJSONThrowsAndKeepsPreviousConfiguration() throws {
        try withTemporaryDirectory { dir in
            let store = ModelStore(directory: dir)
            let model = profile("GLM", env: ["ANTHROPIC_BASE_URL": "https://a"])
            store.add(model)
            try store.save()

            let loaded = ModelStore(directory: dir)
            try loaded.load()
            let beforeCorruption = loaded.configuration
            #expect(beforeCorruption == store.configuration)

            try Data("{ not json".utf8).write(to: dir.appendingPathComponent("config.json"))
            #expect(throws: Error.self) { try loaded.load() }
            #expect(loaded.configuration == beforeCorruption)
        }
    }

    // MARK: - delete

    @Test func deleteDefaultPromotesFirstRemainingModelAsDefault() throws {
        let store = makeStore()
        let first = profile("GLM")
        let second = profile("Kimi")
        store.add(first)
        store.add(second)
        try store.setDefault(id: second.id)

        try store.delete(id: second.id)

        #expect(store.configuration.models == [first])
        #expect(store.configuration.defaultModelID == store.configuration.models.first?.id)
    }

    @Test func deleteNonDefaultKeepsDefaultUnchanged() throws {
        let store = makeStore()
        let first = profile("GLM")
        let second = profile("Kimi")
        store.add(first)
        store.add(second)
        try store.setDefault(id: second.id)

        try store.delete(id: first.id)

        #expect(store.configuration.models == [second])
        #expect(store.configuration.defaultModelID == second.id)
    }

    @Test func deleteLastRemainingModelThrows() throws {
        let store = makeStore()
        let only = profile("GLM")
        store.add(only)

        #expect(throws: ModelStore.ModelStoreError.cannotDeleteLastModel) { try store.delete(id: only.id) }
        #expect(store.configuration.models == [only])
    }

    // MARK: - 不存在的 id

    @Test func setDefaultUnknownIDThrows() throws {
        let store = makeStore()
        store.add(profile("GLM"))
        #expect(throws: ModelStore.ModelStoreError.modelNotFound) { try store.setDefault(id: UUID()) }
    }

    @Test func updateUnknownIDThrows() throws {
        let store = makeStore()
        store.add(profile("GLM"))
        #expect(throws: ModelStore.ModelStoreError.modelNotFound) { try store.update(profile("Ghost")) }
    }

    @Test func markSelectedUnknownIDThrows() throws {
        let store = makeStore()
        store.add(profile("GLM"))
        #expect(throws: ModelStore.ModelStoreError.modelNotFound) { try store.markSelected(id: UUID()) }
    }

    @Test func deleteUnknownIDThrows() throws {
        let store = makeStore()
        store.add(profile("GLM"))
        #expect(throws: ModelStore.ModelStoreError.modelNotFound) { try store.delete(id: UUID()) }
    }

    // MARK: - update / markSelected

    @Test func updateReplacesWholeModelIncludingEnv() throws {
        let store = makeStore()
        let original = profile(
            "GLM",
            env: ["ANTHROPIC_BASE_URL": "https://a", "ANTHROPIC_AUTH_TOKEN": "t1"]
        )
        store.add(original)
        var edited = original
        edited.displayName = "GLM 改"
        edited.env = ["ANTHROPIC_BASE_URL": "https://b"]

        try store.update(edited)

        #expect(store.configuration.models == [edited])
    }

    @Test func markSelectedStampsCurrentTime() throws {
        let store = makeStore()
        let model = profile("GLM")
        store.add(model)

        try store.markSelected(id: model.id)

        let stamped = try #require(store.configuration.models[0].lastSelectedAt)
        #expect(abs(stamped.timeIntervalSinceNow) < 60)
    }

    // MARK: - canDelete

    @Test func canDeleteRequiresAtLeastTwoModels() {
        let store = makeStore()
        store.add(profile("GLM"))
        #expect(!store.canDelete)

        store.add(profile("Kimi"))
        #expect(store.canDelete)
    }

    // MARK: - ModelSort.ordered

    @Test func orderedPutsSelectedModelsFirstInDescendingTimeOrder() {
        let older = profile("older", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let newer = profile("newer", selectedAt: Date(timeIntervalSinceReferenceDate: 300))
        let middle = profile("middle", selectedAt: Date(timeIntervalSinceReferenceDate: 200))

        #expect(ModelSort.ordered([older, newer, middle]) == [newer, middle, older])
    }

    @Test func orderedKeepsNeverSelectedModelsInAdditionOrderAfterSelected() {
        let a = profile("a", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let b = profile("b")
        let c = profile("c", selectedAt: Date(timeIntervalSinceReferenceDate: 300))
        let d = profile("d")

        #expect(ModelSort.ordered([a, b, c, d]) == [c, a, b, d])
    }

    @Test func orderedKeepsAllNeverSelectedModelsInOriginalOrder() {
        let x = profile("x")
        let y = profile("y")
        let z = profile("z")

        #expect(ModelSort.ordered([z, x, y]) == [z, x, y])
    }

    @Test func orderedBreaksDateTiesByOriginalOrder() {
        let first = profile("first", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let second = profile("second", selectedAt: Date(timeIntervalSinceReferenceDate: 100))

        #expect(ModelSort.ordered([second, first]) == [second, first])
    }

    @Test func menuOrderedModelsDelegatesToModelSort() {
        let store = makeStore()
        let older = profile("older", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let fresh = profile("fresh")
        let newer = profile("newer", selectedAt: Date(timeIntervalSinceReferenceDate: 300))
        store.add(older)
        store.add(fresh)
        store.add(newer)

        #expect(store.menuOrderedModels() == [newer, older, fresh])
    }

    // MARK: - 已忽略的自定义 env

    @Test func isDismissedEnvTrueForExactCapturedMatch() {
        let store = makeStore()
        store.recordDismissedEnv(["ANTHROPIC_BASE_URL": "https://x", "ANTHROPIC_MODEL": "m"])

        #expect(store.isDismissedEnv(["ANTHROPIC_BASE_URL": "https://x", "ANTHROPIC_MODEL": "m"]))
    }

    @Test func isDismissedEnvFalseWhenAnyPairDiffers() {
        let store = makeStore()
        store.recordDismissedEnv(["ANTHROPIC_BASE_URL": "https://x"])

        #expect(!store.isDismissedEnv(["ANTHROPIC_BASE_URL": "https://y"]))
        #expect(!store.isDismissedEnv(["ANTHROPIC_BASE_URL": "https://x", "ANTHROPIC_MODEL": "m"]))
        #expect(!store.isDismissedEnv([:]))
    }

    @Test func isDismissedEnvFiltersInputThroughCapture() {
        let store = makeStore()
        store.recordDismissedEnv(["ANTHROPIC_BASE_URL": "https://x"])

        #expect(store.isDismissedEnv(["ANTHROPIC_BASE_URL": "https://x", "PATH": "/usr/bin"]))
    }

    @Test func recordDismissedEnvStoresCapturedEnvOnly() {
        let store = makeStore()
        store.recordDismissedEnv(["ANTHROPIC_BASE_URL": "https://x", "PATH": "/usr/bin"])

        #expect(store.configuration.dismissedCustomEnvs == [["ANTHROPIC_BASE_URL": "https://x"]])
    }
}
