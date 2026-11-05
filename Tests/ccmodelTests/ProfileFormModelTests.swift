import Foundation
import Testing
@testable import ccmodel

/// ProfileFormModel 表单行为（Task 6 验收标准对应）：
/// makeProfile 四断言、fromCapturedEnv 预填两断言、validate 对接断言与字段映射。
struct ProfileFormModelTests {

    // MARK: - 测试设施

    /// 标准三必填表单（档位留空）。
    private func makeFilledForm(
        displayName: String = "GLM",
        baseURL: String = "https://open.bigmodel.cn/api/anthropic",
        token: String = "sk-token",
        mainModel: String = "glm-4.6"
    ) -> ProfileFormModel {
        let form = ProfileFormModel()
        form.displayName = displayName
        form.baseURL = baseURL
        form.token = token
        form.mainModel = mainModel
        return form
    }

    private func profile(
        _ name: String,
        env: [String: String],
        selectedAt: Date? = nil
    ) -> ModelProfile {
        ModelProfile(id: UUID(), displayName: name, env: env, lastSelectedAt: selectedAt)
    }

    /// 三必填解析键的基底 env。
    private func baseEnv(baseURL: String = "https://a", token: String = "sk-1", model: String = "glm-4.6") -> [String: String] {
        [
            "ANTHROPIC_BASE_URL": baseURL,
            "ANTHROPIC_AUTH_TOKEN": token,
            "ANTHROPIC_MODEL": model,
        ]
    }

    // MARK: - makeProfile 四断言

    /// 断言一：全空表单填三必填后新建，env 恰含 3 个必填规范键。
    @Test func makeProfileOnBlankFormProducesOnlyThreeRequiredKeys() {
        let form = makeFilledForm(displayName: "  GLM  ")
        let saved = form.makeProfile(original: nil)
        #expect(saved.env == baseEnv(baseURL: "https://open.bigmodel.cn/api/anthropic", token: "sk-token"))
        #expect(saved.lastSelectedAt == nil)
        #expect(saved.displayName == "GLM")
    }

    /// 断言二：从已有模型载入再保存，extras 保留且不被写回覆盖；id 与选中历史保持。
    @Test func makeProfileFromExistingProfilePreservesExtrasAndIdentity() throws {
        let selectedAt = Date(timeIntervalSinceReferenceDate: 700999.125)
        let original = profile("GLM", env: baseEnv().merging([
            "ANTHROPIC_SMALL_FAST_MODEL": "glm-4-lite",
            "ANTHROPIC_CUSTOM_FLAG": "on",
        ], uniquingKeysWith: { current, _ in current }), selectedAt: selectedAt)
        let form = ProfileFormModel(profile: original, isDefault: true)
        let saved = form.makeProfile(original: original)
        #expect(saved.id == original.id)
        #expect(saved.lastSelectedAt == selectedAt)
        #expect(saved.env["ANTHROPIC_SMALL_FAST_MODEL"] == "glm-4-lite")
        #expect(saved.env["ANTHROPIC_CUSTOM_FLAG"] == "on")
        #expect(saved.displayName == "GLM")
    }

    /// 断言三：清空档位后，解析键与显示键均不存在（extras 不加回）。
    @Test func clearingTierRemovesParseAndDisplayKeys() {
        let original = profile("GLM", env: baseEnv().merging([
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "自定义",
        ], uniquingKeysWith: { current, _ in current }))
        let form = ProfileFormModel(profile: original, isDefault: false)
        form.sonnet = "   "
        let saved = form.makeProfile(original: original)
        #expect(saved.env["ANTHROPIC_DEFAULT_SONNET_MODEL"] == nil)
        #expect(saved.env["ANTHROPIC_DEFAULT_SONNET_MODEL_NAME"] == nil)
    }

    /// 断言四（派生标签）：显示键当前值为旧值去后缀时随新值同步。
    @Test func tierEditSyncsDerivedDisplayName() {
        let original = profile("GLM", env: baseEnv().merging([
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6[1M]",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "glm-4.6",
        ], uniquingKeysWith: { current, _ in current }))
        let form = ProfileFormModel(profile: original, isDefault: false)
        form.sonnet = " glm-5[1m] "
        let saved = form.makeProfile(original: original)
        #expect(saved.env["ANTHROPIC_DEFAULT_SONNET_MODEL"] == "glm-5[1m]")
        #expect(saved.env["ANTHROPIC_DEFAULT_SONNET_MODEL_NAME"] == "glm-5")
    }

    /// 断言四（自定义标签）：用户自定义标签保留不动。
    @Test func tierEditPreservesCustomLabel() {
        let original = profile("GLM", env: baseEnv().merging([
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "o1",
            "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME": "我的 opus",
        ], uniquingKeysWith: { current, _ in current }))
        let form = ProfileFormModel(profile: original, isDefault: false)
        form.opus = "o2"
        let saved = form.makeProfile(original: original)
        #expect(saved.env["ANTHROPIC_DEFAULT_OPUS_MODEL"] == "o2")
        #expect(saved.env["ANTHROPIC_DEFAULT_OPUS_MODEL_NAME"] == "我的 opus")
    }

    // MARK: - fromCapturedEnv 预填两断言

    /// 断言一：空 env → 表单全空、extras 空、displayName 空、isDefault false。
    @Test func fromCapturedEnvWithEmptyEnvYieldsBlankForm() {
        let form = ProfileFormModel.fromCapturedEnv([:])
        #expect(form.displayName == "")
        #expect(form.baseURL == "")
        #expect(form.token == "")
        #expect(form.mainModel == "")
        #expect(form.fable == "")
        #expect(form.opus == "")
        #expect(form.sonnet == "")
        #expect(form.haiku == "")
        #expect(form.extras.isEmpty)
        #expect(form.isDefault == false)
    }

    /// 断言二：有值 env → 字段齐全、extras 已剔除规范键与档位显示键、displayName 空。
    @Test func fromCapturedEnvPrefillsFieldsAndExtractsDisjointExtras() {
        let env = baseEnv(baseURL: "https://bigmodel", token: "sk-z").merging([
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.6",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "GLM 4.6",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "孤儿显示键",
            "ANTHROPIC_SMALL_FAST_MODEL": "glm-4-lite",
            "PATH": "/usr/bin",
        ], uniquingKeysWith: { current, _ in current })
        let form = ProfileFormModel.fromCapturedEnv(env)
        #expect(form.baseURL == "https://bigmodel")
        #expect(form.token == "sk-z")
        #expect(form.mainModel == "glm-4.6")
        #expect(form.sonnet == "glm-4.6")
        #expect(form.fable == "")
        #expect(form.opus == "")
        #expect(form.haiku == "")
        #expect(form.displayName == "")
        #expect(form.isDefault == false)
        #expect(form.extras == ["ANTHROPIC_SMALL_FAST_MODEL": "glm-4-lite"])
    }

    /// extras 零交集：受管的 11 键（7 规范键 + 4 档位显示键）全部剔除。
    @Test func fromCapturedEnvExtrasExcludesAllManagedKeys() {
        let env = baseEnv().merging([
            "ANTHROPIC_DEFAULT_FABLE_MODEL": "f",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "o",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "s",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "h",
            "ANTHROPIC_DEFAULT_FABLE_MODEL_NAME": "F",
            "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME": "O",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "S",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME": "H",
        ], uniquingKeysWith: { current, _ in current })
        #expect(ProfileFormModel.fromCapturedEnv(env).extras.isEmpty)
    }

    // MARK: - init(profile:isDefault:)

    @Test func initProfilePrefillsNameDefaultAndFields() {
        let original = profile("GLM", env: baseEnv())
        let form = ProfileFormModel(profile: original, isDefault: true)
        #expect(form.displayName == "GLM")
        #expect(form.isDefault == true)
        #expect(form.baseURL == "https://a")
        #expect(form.token == "sk-1")
        #expect(form.mainModel == "glm-4.6")
        #expect(form.extras.isEmpty)
    }

    // MARK: - validate 对接断言

    @Test func validateDelegatesEmptyDisplayName() {
        let form = makeFilledForm(displayName: "   ")
        #expect(form.validate(existingNames: []) == [.emptyDisplayName])
    }

    @Test func validateDelegatesDuplicateDisplayNameAfterTrimming() {
        let form = makeFilledForm(displayName: " GLM ")
        #expect(form.validate(existingNames: ["Kimi", "GLM"]) == [.duplicateDisplayName])
    }

    @Test func validateDelegatesMissingRequiredFields() {
        let form = ProfileFormModel()
        form.displayName = "GLM"
        form.mainModel = "glm-4.6"
        #expect(form.validate(existingNames: []) == [.emptyRequired(.baseURL), .emptyRequired(.token)])
    }

    // MARK: - 字段映射与默认态

    @Test func fieldValuesMapsAllSevenEnvFields() {
        let form = ProfileFormModel()
        form.baseURL = "u"
        form.token = "t"
        form.mainModel = "m"
        form.fable = "f"
        form.opus = "o"
        form.sonnet = "s"
        form.haiku = "h"
        #expect(form.fieldValues() == [
            .baseURL: "u",
            .token: "t",
            .mainModel: "m",
            .fable: "f",
            .opus: "o",
            .sonnet: "s",
            .haiku: "h",
        ])
    }

    /// Token 行默认密码态（简报：SecureField + 行内明/密文切换，默认密码态）。
    @Test func tokenFieldDefaultsToSecureAndToggles() {
        let form = ProfileFormModel()
        #expect(form.isTokenSecure)
        form.isTokenSecure = false
        #expect(!form.isTokenSecure)
    }
}
