import Foundation
import Combine

/// 表单模型（Task 6）：首跑与偏好窗口（Task 7）共用的可编辑状态。
/// 只负责字段↔env 的编辑规则（经 `ProfileFields.applyFieldEdit`）与校验委托，
/// 落库编排由持有方（FirstRunCoordinator / PreferencesViewModel）完成。
///
/// `extras` 定义：`capture(env)` 剔除 7 个规范解析键与 4 个档位 `_NAME` 显示键
/// 后的剩余集合——表单 7 个 env 字段与档位显示键由 `applyFieldEdit`（含同步规则）
/// 管辖，extras 与其零交集，合并时不存在覆盖冲突。
final class ProfileFormModel: ObservableObject {

    // MARK: - 可编辑状态

    @Published var displayName: String
    @Published var baseURL: String
    @Published var token: String
    @Published var mainModel: String
    @Published var fable: String
    @Published var opus: String
    @Published var sonnet: String
    @Published var haiku: String
    @Published var isDefault: Bool

    /// 表单之外的额外键值（不做查看/编辑界面，随模型一起保存与切换）。
    let extras: [String: String]

    // MARK: - 表单 UI 态（简报签名之外的两项新增，因状态红线禁用 @State 而落在模型上）

    /// Token 行是否处于密码态（简报：默认密码态）。SwiftUI 视图禁用 @State，
    /// 该切换状态由本模型承载。
    @Published var isTokenSecure = true

    /// 最近一次校验的错误（保存方在保存时写入，视图据此逐字段提示）。
    @Published var validationErrors: [ProfileFields.ValidationError] = []

    // MARK: - 构造

    /// 全空表单（extras 空）。
    init() {
        displayName = ""
        baseURL = ""
        token = ""
        mainModel = ""
        fable = ""
        opus = ""
        sonnet = ""
        haiku = ""
        isDefault = false
        extras = [:]
    }

    /// 从已有模型载入表单；`isDefault` 由持有方按配置中的默认标记传入。
    init(profile: ModelProfile, isDefault: Bool) {
        displayName = profile.displayName
        let values = ProfileFields.fieldValues(fromEnv: profile.env)
        baseURL = values[.baseURL] ?? ""
        token = values[.token] ?? ""
        mainModel = values[.mainModel] ?? ""
        fable = values[.fable] ?? ""
        opus = values[.opus] ?? ""
        sonnet = values[.sonnet] ?? ""
        haiku = values[.haiku] ?? ""
        self.isDefault = isDefault
        extras = Self.extras(fromEnv: profile.env)
    }

    /// 首跑预填落点：8 字段取 `fieldValues(fromEnv:)`（displayName 留空待命名）、
    /// extras 取 `capture(fromEnv:)` 剔除受管键后的剩余集合、isDefault false。
    static func fromCapturedEnv(_ env: [String: String]) -> ProfileFormModel {
        let snapshot = ModelProfile(id: UUID(), displayName: "", env: env, lastSelectedAt: nil)
        return ProfileFormModel(profile: snapshot, isDefault: false)
    }

    // MARK: - 读取

    /// 表单 7 个 env 字段的当前值（原样返回，未去空白；去空白由消费规则负责）。
    func fieldValues() -> [ProfileField: String] {
        var values: [ProfileField: String] = [:]
        for field in ProfileField.allCases {
            values[field] = value(for: field)
        }
        return values
    }

    /// 校验（委托 Task 1 规则）；返回空数组即通过。
    /// `existingNames` 为「除当前编辑对象外」的全部显示名。
    func validate(existingNames: [String]) -> [ProfileFields.ValidationError] {
        ProfileFields.validate(
            displayName: displayName,
            values: fieldValues(),
            existingNames: existingNames
        )
    }

    /// 落库：以 `original?.env` 为基底逐字段 `applyFieldEdit`（同步规则随之生效），
    /// 末尾并入 extras（与受管键零交集，不覆盖任何已处理键）。
    /// original 为 nil → 新 UUID、lastSelectedAt nil；非 nil → 沿用 id 与选中历史。
    func makeProfile(original: ModelProfile?) -> ModelProfile {
        var env = original?.env ?? [:]
        for field in ProfileField.allCases {
            env = ProfileFields.applyFieldEdit(field: field, newValue: value(for: field), env: env)
        }
        for (key, extraValue) in extras {
            env[key] = extraValue
        }
        return ModelProfile(
            id: original?.id ?? UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            env: env,
            lastSelectedAt: original?.lastSelectedAt
        )
    }

    // MARK: - 私有

    private func value(for field: ProfileField) -> String {
        switch field {
        case .baseURL: return baseURL
        case .token: return token
        case .mainModel: return mainModel
        case .fable: return fable
        case .opus: return opus
        case .sonnet: return sonnet
        case .haiku: return haiku
        }
    }

    /// 受管键集合 = 7 个规范解析键 + 4 个档位 `_NAME` 显示键。
    private static func managedKeys() -> Set<String> {
        let tierKeys = Set(ProfileField.allCases.map(\.envKey))
        let displayKeys = Set(ProfileField.allCases.compactMap { ProfileFields.tierDisplayKey(forTierKey: $0.envKey) })
        return tierKeys.union(displayKeys)
    }

    private static func extras(fromEnv env: [String: String]) -> [String: String] {
        let managed = managedKeys()
        return ProfileFields.capture(fromEnv: env).filter { !managed.contains($0.key) }
    }
}
