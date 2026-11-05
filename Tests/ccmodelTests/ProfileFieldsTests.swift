import Foundation
import Testing
@testable import ccmodel

/// 映射、同步规则、捕获与状态项标题（Task 1 验收标准对应）。
struct ProfileFieldsTests {

    // MARK: - env 键映射（设计文档 §2 F5，逐字）

    @Test func envKeysMatchDesignMappingVerbatim() {
        #expect(ProfileField.baseURL.envKey == "ANTHROPIC_BASE_URL")
        #expect(ProfileField.token.envKey == "ANTHROPIC_AUTH_TOKEN")
        #expect(ProfileField.mainModel.envKey == "ANTHROPIC_MODEL")
        #expect(ProfileField.fable.envKey == "ANTHROPIC_DEFAULT_FABLE_MODEL")
        #expect(ProfileField.opus.envKey == "ANTHROPIC_DEFAULT_OPUS_MODEL")
        #expect(ProfileField.sonnet.envKey == "ANTHROPIC_DEFAULT_SONNET_MODEL")
        #expect(ProfileField.haiku.envKey == "ANTHROPIC_DEFAULT_HAIKU_MODEL")
    }

    @Test func allCasesCoverSevenFields() {
        #expect(ProfileField.allCases.count == 7)
    }

    // MARK: - fieldValues(fromEnv:)

    @Test func fieldValuesReadsAllSevenCanonicalKeys() {
        let env = [
            "ANTHROPIC_BASE_URL": "https://api.example.com",
            "ANTHROPIC_AUTH_TOKEN": "sk-token",
            "ANTHROPIC_MODEL": "glm-5.3-flash[1M]",
            "ANTHROPIC_DEFAULT_FABLE_MODEL": "fable-x",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "opus-x",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "sonnet-x",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "haiku-x",
        ]
        let values = ProfileFields.fieldValues(fromEnv: env)
        #expect(values.count == 7)
        #expect(values[.baseURL] == "https://api.example.com")
        #expect(values[.token] == "sk-token")
        #expect(values[.mainModel] == "glm-5.3-flash[1M]")
        #expect(values[.fable] == "fable-x")
        #expect(values[.opus] == "opus-x")
        #expect(values[.sonnet] == "sonnet-x")
        #expect(values[.haiku] == "haiku-x")
    }

    @Test func fieldValuesIgnoresNonCanonicalKeys() {
        let env = [
            "ANTHROPIC_BASE_URL": "https://api.example.com",
            "ANTHROPIC_FOO": "non-canonical anthropic key",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "display key",
            "PATH": "/usr/bin",
        ]
        let values = ProfileFields.fieldValues(fromEnv: env)
        #expect(values.count == 1)
        #expect(values[.baseURL] == "https://api.example.com")
    }

    @Test func fieldValuesOmitsMissingKeys() {
        #expect(ProfileFields.fieldValues(fromEnv: [:]) == [:])
    }

    // MARK: - tierDisplayKey(forTierKey:)

    @Test func tierDisplayKeyAppendsNameSuffixForTierKeys() {
        #expect(ProfileFields.tierDisplayKey(forTierKey: "ANTHROPIC_DEFAULT_SONNET_MODEL") == "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME")
        #expect(ProfileFields.tierDisplayKey(forTierKey: "ANTHROPIC_DEFAULT_OPUS_MODEL") == "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME")
    }

    @Test func tierDisplayKeyReturnsNilForNonTierKeys() {
        #expect(ProfileFields.tierDisplayKey(forTierKey: "ANTHROPIC_MODEL") == nil)
        #expect(ProfileFields.tierDisplayKey(forTierKey: "ANTHROPIC_BASE_URL") == nil)
        #expect(ProfileFields.tierDisplayKey(forTierKey: "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME") == nil)
        #expect(ProfileFields.tierDisplayKey(forTierKey: "SOMETHING_ELSE") == nil)
    }

    // MARK: - stripContextSuffix(_:)

    @Test func stripContextSuffixRemovesOneTrailingSuffixCaseInsensitively() {
        #expect(ProfileFields.stripContextSuffix("glm-4.6[1m]") == "glm-4.6")
        #expect(ProfileFields.stripContextSuffix("glm-4.6[1M]") == "glm-4.6")
        #expect(ProfileFields.stripContextSuffix("[1m][1m]") == "[1m]")
    }

    @Test func stripContextSuffixKeepsValuesWithoutTrailingSuffix() {
        #expect(ProfileFields.stripContextSuffix("glm-4.6[1m]x") == "glm-4.6[1m]x")
        #expect(ProfileFields.stripContextSuffix("glm-4.6") == "glm-4.6")
    }

    // MARK: - applyFieldEdit(field:newValue:env:)

    /// 简报调用示例逐字：派生显示键跟随更新；旧值 `[1M]`、新值 `[1m]` 混合大小写。
    @Test func tierEditUpdatesDerivedDisplayName() {
        let result = ProfileFields.applyFieldEdit(
            field: .sonnet,
            newValue: "kimi-k3[1m]",
            env: [
                "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.3-flash[1M]",
                "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "glm-5.3-flash",
            ]
        )
        #expect(result == [
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "kimi-k3[1m]",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "kimi-k3",
        ])
    }

    /// 混合大小写另一方向：旧值 `[1m]`、新值 `[1M]`，派生值仍跟随。
    @Test func tierEditUpdatesDerivedDisplayNameReverseCase() {
        let result = ProfileFields.applyFieldEdit(
            field: .opus,
            newValue: "opus-new[1M]",
            env: [
                "ANTHROPIC_DEFAULT_OPUS_MODEL": "opus-old[1m]",
                "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME": "opus-old",
            ]
        )
        #expect(result == [
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "opus-new[1M]",
            "ANTHROPIC_DEFAULT_OPUS_MODEL_NAME": "opus-new",
        ])
    }

    /// 自定义标签（≠ 旧值去后缀）不被派生值覆盖。
    @Test func tierEditKeepsCustomLabel() {
        let result = ProfileFields.applyFieldEdit(
            field: .sonnet,
            newValue: "kimi-k3[1M]",
            env: [
                "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.3-flash[1m]",
                "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "我的自定义标签",
            ]
        )
        #expect(result == [
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "kimi-k3[1M]",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "我的自定义标签",
        ])
    }

    /// 清空（含纯空白与 nil）：解析键与配对显示键双删，其余键保留。
    @Test func clearingTierRemovesParseAndDisplayKeys() {
        let result = ProfileFields.applyFieldEdit(
            field: .sonnet,
            newValue: "   ",
            env: [
                "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.3-flash[1m]",
                "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "glm-5.3-flash",
                "ANTHROPIC_BASE_URL": "https://api.example.com",
            ]
        )
        #expect(result == ["ANTHROPIC_BASE_URL": "https://api.example.com"])
    }

    @Test func nilNewValueClearsField() {
        let result = ProfileFields.applyFieldEdit(
            field: .haiku,
            newValue: nil,
            env: ["ANTHROPIC_DEFAULT_HAIKU_MODEL": "haiku-x"]
        )
        #expect(result == [:])
    }

    /// 非档位字段没有配对显示键，编辑只写解析键；值含后缀时不改写。
    @Test func nonTierEditWritesParseKeyOnlyVerbatim() {
        let result = ProfileFields.applyFieldEdit(
            field: .mainModel,
            newValue: "  glm-5.3-flash[1M]  ",
            env: ["ANTHROPIC_BASE_URL": "https://api.example.com"]
        )
        #expect(result == [
            "ANTHROPIC_BASE_URL": "https://api.example.com",
            "ANTHROPIC_MODEL": "glm-5.3-flash[1M]",
        ])
    }

    /// 无配对显示键时编辑档位，不创建显示键。
    @Test func tierEditWithoutDisplayKeyCreatesNone() {
        let result = ProfileFields.applyFieldEdit(
            field: .fable,
            newValue: "fable-x[1m]",
            env: [:]
        )
        #expect(result == ["ANTHROPIC_DEFAULT_FABLE_MODEL": "fable-x[1m]"])
    }

    // MARK: - capture(fromEnv:)

    @Test func captureKeepsOnlyAnthropicPrefixedKeys() {
        let env = [
            "ANTHROPIC_BASE_URL": "https://api.example.com",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "sonnet",
            "ANTHROPICRO": "prefix without underscore",
            "PATH": "/usr/bin",
            "HTTP_PROXY": "http://127.0.0.1:7890",
        ]
        let result = ProfileFields.capture(fromEnv: env)
        #expect(result == [
            "ANTHROPIC_BASE_URL": "https://api.example.com",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_NAME": "sonnet",
        ])
    }

    @Test func anthropicPrefixIsVerbatim() {
        #expect(ProfileFields.anthropicPrefix == "ANTHROPIC_")
    }

    // MARK: - statusItemTitle(displayName:)

    @Test func statusItemTitleKeepsShortNameAsIs() {
        #expect(ProfileFields.statusItemTitle(displayName: "abc") == "⇄ abc")
        #expect(ProfileFields.statusItemTitle(displayName: "abcdefghijkl") == "⇄ abcdefghijkl")
    }

    @Test func statusItemTitleTruncatesLongNameToTwelveCharacters() {
        #expect(ProfileFields.statusItemTitle(displayName: "abcdefghijklm") == "⇄ abcdefghijkl…")
        #expect(ProfileFields.statusItemTitle(displayName: "abcdefghijklmn") == "⇄ abcdefghijkl…")
    }

    // MARK: - ModelProfile

    @Test func modelProfileCodableRoundTrip() throws {
        let id = try #require(UUID(uuidString: "12345678-1234-1234-1234-123456789012"))
        let profile = ModelProfile(
            id: id,
            displayName: "Kimi",
            env: ["ANTHROPIC_BASE_URL": "https://api.example.com"],
            lastSelectedAt: Date(timeIntervalSince1970: 1_000_000)
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ModelProfile.self, from: data)
        #expect(decoded == profile)
    }
}
