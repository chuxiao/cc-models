import Foundation

/// 当前生效模型识别：捕获过滤后的 env 与各模型快照做全等比较。
enum CurrentModelDetector {
    /// `env` 先经 `ProfileFields.capture` 过滤；过滤后键集合与某模型 env
    /// 完全相等且逐键值相等 → 返回该模型 id，否则 nil。
    /// 空 env（含过滤后为空）一律不命中，即使某模型快照也为空。
    static func match(env: [String: String], in models: [ModelProfile]) -> ModelProfile.ID? {
        let captured = ProfileFields.capture(fromEnv: env)
        guard !captured.isEmpty else { return nil }
        return models.first { $0.env == captured }?.id
    }
}
