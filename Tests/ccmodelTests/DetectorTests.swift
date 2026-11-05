import Foundation
import Testing
@testable import ccmodel

/// 当前模型识别的四断言与 capture 过滤语义（Task 4 验收标准对应）。
struct DetectorTests {

    private func profile(
        _ name: String,
        env: [String: String],
        selectedAt: Date? = nil
    ) -> ModelProfile {
        ModelProfile(id: UUID(), displayName: name, env: env, lastSelectedAt: selectedAt)
    }

    @Test func exactKeySetAndValuesMatchReturnsID() {
        let model = profile(
            "智谱",
            env: [
                "ANTHROPIC_BASE_URL": "https://a.example",
                "ANTHROPIC_AUTH_TOKEN": "sk-1",
                "ANTHROPIC_MODEL": "glm-4",
            ]
        )
        let env = [
            "ANTHROPIC_BASE_URL": "https://a.example",
            "ANTHROPIC_AUTH_TOKEN": "sk-1",
            "ANTHROPIC_MODEL": "glm-4",
        ]
        #expect(CurrentModelDetector.match(env: env, in: [model]) == model.id)
    }

    @Test func differingValueDoesNotMatch() {
        let model = profile(
            "智谱",
            env: [
                "ANTHROPIC_BASE_URL": "https://a.example",
                "ANTHROPIC_AUTH_TOKEN": "sk-1",
            ]
        )
        let env = [
            "ANTHROPIC_BASE_URL": "https://a.example",
            "ANTHROPIC_AUTH_TOKEN": "sk-other",
        ]
        #expect(CurrentModelDetector.match(env: env, in: [model]) == nil)
    }

    @Test func differingKeySetDoesNotMatch() {
        let model = profile(
            "智谱",
            env: [
                "ANTHROPIC_BASE_URL": "https://a.example",
                "ANTHROPIC_AUTH_TOKEN": "sk-1",
            ]
        )
        // 值全部相同，但键集合多出一个键。
        let env = [
            "ANTHROPIC_BASE_URL": "https://a.example",
            "ANTHROPIC_AUTH_TOKEN": "sk-1",
            "ANTHROPIC_MODEL": "glm-4",
        ]
        #expect(CurrentModelDetector.match(env: env, in: [model]) == nil)
    }

    @Test func emptyEnvDoesNotMatchEvenAgainstEmptyModelEnv() {
        let model = profile("空档位", env: [:])
        #expect(CurrentModelDetector.match(env: [:], in: [model]) == nil)
    }

    @Test func nonAnthropicKeysAreFilteredBeforeMatching() {
        // 非 ANTHROPIC_ 前缀键（PATH）经 capture 过滤后不参与比较。
        let model = profile(
            "智谱",
            env: ["ANTHROPIC_BASE_URL": "https://a.example"]
        )
        let env = [
            "ANTHROPIC_BASE_URL": "https://a.example",
            "PATH": "/usr/bin:/bin",
        ]
        #expect(CurrentModelDetector.match(env: env, in: [model]) == model.id)
    }
}
