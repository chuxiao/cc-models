import Foundation

/// 切换编排（Task 5）：settings.json 写入 → 选中记录 → 通知，是切换、编辑生效、
/// 首跑、导入四条链路共用的编排件。
final class ModelSwitcher {

    enum ModelSwitcherError: Error, Equatable {
        /// switchTo 传入不存在于 store 的模型 id。
        case modelNotFound
    }

    private let store: ModelStore
    private let writer: SettingsWriter
    private let notifier: Notifier

    init(store: ModelStore, writer: SettingsWriter, notifier: Notifier) {
        self.store = store
        self.writer = writer
        self.notifier = notifier
    }

    // MARK: - 切换

    /// 切换到指定模型：先 `writer.replaceAnthropicEnv(profile.env)`，成功后
    /// `store.markSelected(id)` 并 save，再发成功通知。
    /// writer 抛错 → 不 markSelected、不 save，发失败通知并原样抛出；
    /// id 不存在 → 抛 `modelNotFound`，不触达 writer。
    func switchTo(id: UUID) throws {
        guard let profile = store.configuration.models.first(where: { $0.id == id }) else {
            throw ModelSwitcherError.modelNotFound
        }
        do {
            try writer.replaceAnthropicEnv(with: profile.env)
        } catch {
            notifier.postSwitchFailure(modelName: profile.displayName)
            throw error
        }
        try store.markSelected(id: id)
        try store.save()
        notifier.postSwitchSuccess(modelName: profile.displayName)
    }

    /// 仅替换 env + 成功通知，不改 lastSelectedAt（供编辑生效中模型与首跑落库使用）。
    /// 通知中的模型名按写入的 env 重新识别；env 与任何模型都不匹配时不发通知。
    func applyEnv(_ env: [String: String]) throws {
        try writer.replaceAnthropicEnv(with: env)
        if let id = CurrentModelDetector.match(env: env, in: store.configuration.models),
           let profile = store.configuration.models.first(where: { $0.id == id }) {
            notifier.postSwitchSuccess(modelName: profile.displayName)
        }
    }

    // MARK: - 当前模型识别

    /// `readEnv` + `match`；readEnv 抛错（settings.json 损坏）→ 返回 nil。
    func currentModelID() -> UUID? {
        guard let env = currentEnv() else { return nil }
        return CurrentModelDetector.match(env: env, in: store.configuration.models)
    }

    /// 当前 settings.json 的 `ANTHROPIC_` env；readEnv 抛错 → nil。
    /// 供状态项装配层在 menuDidClose 等时刻以同一份 env 做判定。
    func currentEnv() -> [String: String]? {
        try? writer.readEnv()
    }
}
