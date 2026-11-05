import SwiftUI

/// 模型表单（Task 6）：8 输入行 +「设为默认」开关。model 由外部视图持有
/// （首跑 FirstRunCoordinator / Task 7 PreferencesViewModel）。
/// 仅负责展示与输入绑定；校验与落库由持有方编排，校验错误经
/// `model.validationErrors` 逐字段行内提示。
struct ProfileFormView: View {
    @ObservedObject var model: ProfileFormModel

    var body: some View {
        Form {
            fieldRow(title: "显示名", placeholder: "如：智谱", field: nil) {
                TextField("如：智谱", text: $model.displayName)
            }
            fieldRow(title: "Base URL", placeholder: "https://…", field: .baseURL) {
                TextField("https://…", text: $model.baseURL)
            }
            fieldRow(title: "Token", placeholder: "sk-…", field: .token) {
                HStack(spacing: 8) {
                    if model.isTokenSecure {
                        SecureField("sk-…", text: $model.token)
                    } else {
                        TextField("sk-…", text: $model.token)
                    }
                    Button {
                        model.isTokenSecure.toggle()
                    } label: {
                        Image(systemName: model.isTokenSecure ? "eye" : "eye.slash")
                    }
                    .buttonStyle(.borderless)
                    .help(model.isTokenSecure ? "显示明文" : "隐藏为密文")
                }
            }
            fieldRow(title: "主模型", placeholder: "如：glm-4.6", field: .mainModel) {
                TextField("如：glm-4.6", text: $model.mainModel)
            }
            fieldRow(title: "Fable 档", placeholder: "可选", field: .fable) {
                TextField("可选", text: $model.fable)
            }
            fieldRow(title: "Opus 档", placeholder: "可选", field: .opus) {
                TextField("可选", text: $model.opus)
            }
            fieldRow(title: "Sonnet 档", placeholder: "可选", field: .sonnet) {
                TextField("可选", text: $model.sonnet)
            }
            fieldRow(title: "Haiku 档", placeholder: "可选", field: .haiku) {
                TextField("可选", text: $model.haiku)
            }
            Toggle("设为默认", isOn: $model.isDefault)
        }
    }

    // MARK: - 行构造

    private func fieldRow<Content: View>(
        title: String,
        placeholder: String,
        field: ProfileField?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        LabeledContent(title) {
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
