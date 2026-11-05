import Foundation

/// 受管理的七个表单字段（设计文档 §2 F5）。
///
/// `baseURL` / `token` / `mainModel` 为必填非档位字段；
/// `fable` / `opus` / `sonnet` / `haiku` 为四档（档位别名）字段，
/// 各有可选的 `_NAME` 配对显示键（`/model` 选择器显示名）。
enum ProfileField: String, CaseIterable {
    case baseURL
    case token
    case mainModel
    case fable
    case opus
    case sonnet
    case haiku

    /// 该字段对应的 env 解析键。
    var envKey: String {
        switch self {
        case .baseURL:
            return "ANTHROPIC_BASE_URL"
        case .token:
            return "ANTHROPIC_AUTH_TOKEN"
        case .mainModel:
            return "ANTHROPIC_MODEL"
        case .fable:
            return "ANTHROPIC_DEFAULT_FABLE_MODEL"
        case .opus:
            return "ANTHROPIC_DEFAULT_OPUS_MODEL"
        case .sonnet:
            return "ANTHROPIC_DEFAULT_SONNET_MODEL"
        case .haiku:
            return "ANTHROPIC_DEFAULT_HAIKU_MODEL"
        }
    }
}

/// 字段↔env 键映射、`_NAME` 显示键同步规则、校验与捕获的纯逻辑。
enum ProfileFields {
    static let anthropicPrefix = "ANTHROPIC_"

    /// 档位解析键 → 配对显示键（`..._SONNET_MODEL` → `..._SONNET_MODEL_NAME`）。
    /// 主模型键与其余非档位键返回 nil。
    static func tierDisplayKey(forTierKey tierKey: String) -> String? {
        let tierKeys = [ProfileField.fable, .opus, .sonnet, .haiku].map(\.envKey)
        guard tierKeys.contains(tierKey) else { return nil }
        return tierKey + "_NAME"
    }

    /// 去除结尾一个大小写不敏感的 `[1m]`/`[1M]` 上下文后缀；其余原样返回。
    static func stripContextSuffix(_ value: String) -> String {
        for suffix in ["[1m]", "[1M]"] where value.hasSuffix(suffix) {
            return String(value.dropLast(suffix.count))
        }
        return value
    }

    /// 从 env 读取七个规范字段的当前值；缺失键不出现在结果中。
    static func fieldValues(fromEnv env: [String: String]) -> [ProfileField: String] {
        var values: [ProfileField: String] = [:]
        for field in ProfileField.allCases where env[field.envKey] != nil {
            values[field] = env[field.envKey]
        }
        return values
    }

    /// 捕获：只保留 `ANTHROPIC_` 前缀键（含 `_NAME` 显示键等变体键）。
    static func capture(fromEnv env: [String: String]) -> [String: String] {
        env.filter { $0.key.hasPrefix(anthropicPrefix) }
    }

    /// 编辑一个字段：非空值去首尾空白后写入解析键（含上下文后缀，不改写）；
    /// 去空白后为空（含 nil）视为清空——移除解析键，存在配对显示键时一并移除。
    ///
    /// 同步规则（2026-11-04 裁决）：档位编辑时，配对显示键当前值恰为
    /// 旧解析键值去上下文后缀（即用户未自定义过标签）时，
    /// 显示键更新为新值去后缀；自定义标签保留不动。
    static func applyFieldEdit(
        field: ProfileField,
        newValue: String?,
        env: [String: String]
    ) -> [String: String] {
        var result = env
        let parseKey = field.envKey
        let displayKey = tierDisplayKey(forTierKey: parseKey)
        let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !trimmed.isEmpty else {
            result.removeValue(forKey: parseKey)
            if let displayKey {
                result.removeValue(forKey: displayKey)
            }
            return result
        }

        if let displayKey,
           let oldValue = env[parseKey],
           let currentDisplay = env[displayKey],
           currentDisplay == stripContextSuffix(oldValue) {
            result[displayKey] = stripContextSuffix(trimmed)
        }
        result[parseKey] = trimmed
        return result
    }

    /// 表单校验错误；`validate` 返回空数组即通过。
    enum ValidationError: Equatable, Error {
        case emptyDisplayName
        case duplicateDisplayName
        case emptyRequired(ProfileField)
    }

    /// 校验：收集全部错误（不因首个错误中断）。
    /// 显示名去空白后为空 → `emptyDisplayName`；与任一现有名去空白后相等 → `duplicateDisplayName`；
    /// baseURL/token/mainModel 缺失或去空白后为空 → `emptyRequired(对应字段)`；四档为空不报错。
    static func validate(
        displayName: String,
        values: [ProfileField: String],
        existingNames: [String]
    ) -> [ValidationError] {
        var errors: [ValidationError] = []
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append(.emptyDisplayName)
        }
        if existingNames.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedName }) {
            errors.append(.duplicateDisplayName)
        }
        for field in ProfileField.allCases {
            guard isRequired(field) else { continue }
            let value = values[field] ?? ""
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyRequired(field))
            }
        }
        return errors
    }

    /// 状态项标题：`⇄ ` 前缀加显示名；显示名超过 12 个字符时取前 12 字符追加省略号。
    static func statusItemTitle(displayName: String) -> String {
        if displayName.count > 12 {
            return "⇄ " + String(displayName.prefix(12)) + "…"
        }
        return "⇄ " + displayName
    }

    private static func isRequired(_ field: ProfileField) -> Bool {
        switch field {
        case .baseURL, .token, .mainModel:
            return true
        case .fable, .opus, .sonnet, .haiku:
            return false
        }
    }
}
