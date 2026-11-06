import SwiftUI

/// 模型表单（Task 6；Task 2 视觉参数化）：显示名 / 接入点 URL / API Token /
/// 主模型 + 四档横排四列等宽（HStack spacing 8，长模型名截断省略不撑破列宽）
/// +「设为默认模型」开关。`hidesDefaultToggle: true` 不渲染该行（首跑窗），
/// `false`（缺省，偏好窗）渲染不变——仅影响该行渲染，保存链路零变更（首跑
/// 保存仍自动成为默认）。model 由外部视图持有（首跑 FirstRunCoordinator /
/// 偏好窗 PreferencesViewModel）。仅负责展示与输入绑定；校验与落库由持有方
/// 编排，校验错误经 `model.validationErrors` 逐字段行内提示。
/// 视图不写单测，UI 效果由 verification 人工核对。
struct ProfileFormView: View {
    @ObservedObject var model: ProfileFormModel

    /// true 隐藏「设为默认模型」勾选行（I-4，参数置于初始化列表末尾，缺省 false
    /// 保既有调用点零改动）。
    var hidesDefaultToggle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldRow(title: "显示名", placeholder: "如：智谱", field: nil) {
                TextField("如：智谱", text: $model.displayName)
                    .darkInputField()
            }
            fieldRow(title: "接入点 URL", placeholder: "https://…", field: .baseURL) {
                TextField("https://…", text: $model.baseURL)
                    .darkInputField()
            }
            fieldRow(title: "API Token", placeholder: "sk-…", field: .token) {
                tokenField
            }
            fieldRow(title: "主模型", placeholder: "如：glm-4.6", field: .mainModel) {
                TextField("如：glm-4.6", text: $model.mainModel)
                    .darkInputField()
            }
            tierRow
            if !hidesDefaultToggle {
                Toggle("设为默认模型", isOn: $model.isDefault)
                    .foregroundColor(UIPalette.primaryText)
                    .tint(UIPalette.accentBlue)
            }
        }
    }

    // MARK: - 行构造

    /// 横排标签（左，定宽右对齐）+ 内容（右）；校验错误在内容下方逐字段提示。
    private func fieldRow<Content: View>(
        title: String,
        placeholder: String,
        field: ProfileField?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(UIPalette.auxiliaryText)
                .frame(width: 72, alignment: .trailing)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 2) {
                content()
                if let message = errorMessage(for: field) {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    /// Token 行：密文/明文输入框 + 行内明密切换（密文态默认，简报既有语义）。
    private var tokenField: some View {
        HStack(spacing: 8) {
            Group {
                if model.isTokenSecure {
                    SecureField("sk-…", text: $model.token)
                } else {
                    TextField("sk-…", text: $model.token)
                }
            }
            .darkInputField()
            Button {
                model.isTokenSecure.toggle()
            } label: {
                Image(systemName: model.isTokenSecure ? "eye" : "eye.slash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(UIPalette.auxiliaryText)
            .help(model.isTokenSecure ? "显示明文" : "隐藏为密文")
        }
    }

    /// 四档横排四列等宽（implementation §5：HStack spacing 8）；长模型名截断
    /// 省略，不撑破列宽。
    private var tierRow: some View {
        HStack(spacing: 8) {
            tierColumn(title: "Fable 档", placeholder: "可选", field: .fable, text: $model.fable)
            tierColumn(title: "Opus 档", placeholder: "可选", field: .opus, text: $model.opus)
            tierColumn(title: "Sonnet 档", placeholder: "可选", field: .sonnet, text: $model.sonnet)
            tierColumn(title: "Haiku 档", placeholder: "可选", field: .haiku, text: $model.haiku)
        }
    }

    /// 单个档位列：档名小字在上、输入框在下、校验提示随行；四列等宽由
    /// `maxWidth: .infinity` 均分。
    private func tierColumn(
        title: String,
        placeholder: String,
        field: ProfileField,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(UIPalette.auxiliaryText)
            TextField(placeholder, text: text)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .darkInputField()
            if let message = errorMessage(for: field) {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 该行对应的校验提示；无错误返回 nil。displayName 行传 nil。
    private func errorMessage(for field: ProfileField?) -> String? {
        for error in model.validationErrors {
            switch error {
            case .emptyDisplayName where field == nil:
                return "显示名不能为空"
            case .duplicateDisplayName where field == nil:
                return "显示名与现有模型重名"
            case .emptyRequired(let required) where required == field:
                return "该项为必填"
            default:
                continue
            }
        }
        return nil
    }
}

// MARK: - 深色视觉取值（implementation.md §5 色值表，三窗口共用）

/// 色值表组件级取值（冻结稿 mockups/preferences.html）：偏好窗 / 首跑两窗的
/// 深色观感统一取值，避免逐处散落硬编码。
enum UIPalette {
    /// 窗口卡面 #1E1E24
    static let windowCard = Color(red: 30 / 255, green: 30 / 255, blue: 36 / 255)
    /// 侧栏/标题栏 #24242C
    static let sidebar = Color(red: 36 / 255, green: 36 / 255, blue: 44 / 255)
    /// 输入框底 #16161B
    static let inputBackground = Color(red: 22 / 255, green: 22 / 255, blue: 27 / 255)
    /// 选中行 #3A3F4D
    static let selectedRow = Color(red: 58 / 255, green: 63 / 255, blue: 77 / 255)
    /// 主文字 #E2E2EA
    static let primaryText = Color(red: 226 / 255, green: 226 / 255, blue: 234 / 255)
    /// 辅助文字 #8F8F9C
    static let auxiliaryText = Color(red: 143 / 255, green: 143 / 255, blue: 156 / 255)
    /// 系统勾选蓝 #0A84FF
    static let accentBlue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    /// 分隔线/描边下限 rgba(255,255,255,0.06)
    static let hairline = Color.white.opacity(0.06)
    /// 输入框描边上限 rgba(255,255,255,0.10)
    static let inputStroke = Color.white.opacity(0.10)
    /// 主按钮渐变（135° #4F8DFF → #7C5CFF）；「默认」徽标同渐变
    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 79 / 255, green: 141 / 255, blue: 255 / 255),
            Color(red: 124 / 255, green: 92 / 255, blue: 255 / 255),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 渐变主按钮（implementation §5：135° 渐变底、白字）：偏好窗与首跑表单窗的
/// 「保 存」、首跑欢迎窗的「开始配置」共用。
struct GradientPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 26)
            .padding(.vertical, 7)
            .background(UIPalette.primaryGradient, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    /// 输入框深色样式（implementation §5：底 #16161B、描边 rgba(255,255,255,0.10)、
    /// 圆角 7）；plain 去系统 bezel 后自绘底与描边。
    func darkInputField() -> some View {
        textFieldStyle(.plain)
            .foregroundColor(UIPalette.primaryText)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(UIPalette.inputBackground, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(UIPalette.inputStroke, lineWidth: 1)
            )
    }
}
