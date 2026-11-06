import AppKit
import SwiftUI

/// 首跑欢迎窗（Task 6，强制流入口；Task 2 深色观感）：应用用途说明
/// +「开始配置 / 退出」两出口，「开始配置」为渐变主按钮。无标准关闭按钮
/// （styleMask 不含 .closable），仅两条路径离开本窗；打开前归位主屏并居中由
/// FirstRunCoordinator 经 `WindowPresenter.prepare` 完成（I-3 接线）。
/// 装配不写单测，由 verification.md S6 人工核对。
final class WelcomeWindow: NSWindow {

    init(
        hasExistingConfig: Bool,
        onStart: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 230),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        title = "欢迎使用 CC Model"
        contentView = NSHostingView(rootView: WelcomeView(
            hasExistingConfig: hasExistingConfig,
            onStart: onStart,
            onQuit: onQuit
        ))
    }
}

private struct WelcomeView: View {
    let hasExistingConfig: Bool
    let onStart: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("欢迎使用 CC Model")
                .font(.title2.bold())
                .foregroundColor(UIPalette.primaryText)
            Text("在多个 Claude Code 模型配置之间一键切换。CC Model 通过改写 ~/.claude/settings.json 的 env 块来切换当前生效的模型。")
                .foregroundColor(UIPalette.auxiliaryText)
            Text(hasExistingConfig
                 ? "已检测到现有 ANTHROPIC 配置，开始配置后将自动预填。"
                 : "未检测到现有 ANTHROPIC 配置，需要手动填写。")
                .foregroundColor(UIPalette.auxiliaryText)
            Spacer()
            HStack {
                Spacer()
                Button("退出", action: onQuit)
                    .buttonStyle(.bordered)
                    .foregroundColor(UIPalette.auxiliaryText)
                Button("开始配置", action: onStart)
                    .buttonStyle(GradientPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(UIPalette.windowCard)
    }
}
