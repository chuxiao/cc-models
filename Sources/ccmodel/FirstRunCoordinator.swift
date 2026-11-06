import AppKit
import SwiftUI

/// 首跑编排（Task 6）：无模型 → 欢迎窗 → 表单窗 → 校验通过后
/// `store.add` + `setDefault` + `switcher.applyEnv`（写入与捕获同键组，幂等）+ `store.save`
/// → 关窗 + `onFinished`（装配层据此创建状态项进入常驻）。
/// 「退出」→ `NSApp.terminate`，全程无任何写入。欢迎窗与表单窗均无标准关闭按钮，
/// 强制出口由 verification.md S6 人工核对；UI 装配不写单测。
final class FirstRunCoordinator {

    private let store: ModelStore
    private let switcher: ModelSwitcher
    private let onFinished: () -> Void

    private var welcomeWindow: WelcomeWindow?
    private var formWindow: FirstRunFormWindow?
    private var formModel: ProfileFormModel?

    init(store: ModelStore, switcher: ModelSwitcher, onFinished: @escaping () -> Void) {
        self.store = store
        self.switcher = switcher
        self.onFinished = onFinished
    }

    /// 应用无模型时进入首跑流；已有模型为 no-op（装配层守卫之外的双保险）。
    func runIfNeeded() {
        guard store.configuration.models.isEmpty else { return }
        showWelcome()
    }

    // MARK: - 欢迎窗

    private func showWelcome() {
        let env = switcher.currentEnv() ?? [:]
        let window = WelcomeWindow(
            hasExistingConfig: !ProfileFields.capture(fromEnv: env).isEmpty,
            onStart: { [weak self] in self?.showForm() },
            onQuit: { NSApp.terminate(nil) }
        )
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
        // 打开前归位主屏并居中（I-3 接线，Task 2）
        WindowPresenter.prepare(window)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - 表单窗

    private func showForm() {
        let model = ProfileFormModel.fromCapturedEnv(switcher.currentEnv() ?? [:])
        formModel = model
        welcomeWindow?.orderOut(nil)
        welcomeWindow = nil
        let window = FirstRunFormWindow(model: model, onSave: { [weak self] in self?.saveForm() })
        formWindow = window
        NSApp.activate(ignoringOtherApps: true)
        // 打开前归位主屏并居中（I-3 接线，Task 2）
        WindowPresenter.prepare(window)
        window.makeKeyAndOrderFront(nil)
    }

    /// 保存：校验通过 → 入列 + 设默认 + 写 env（幂等）+ 持久化 → 关窗 + onFinished；
    /// 校验不通过 → 逐字段行内提示且不落库。
    private func saveForm() {
        guard let model = formModel else { return }
        let errors = model.validate(
            existingNames: store.configuration.models.map(\.displayName)
        )
        model.validationErrors = errors
        guard errors.isEmpty else { return }

        let profile = model.makeProfile(original: nil)
        store.add(profile)
        do {
            try store.setDefault(id: profile.id)
            try switcher.applyEnv(profile.env)
            try store.save()
        } catch {
            // 落盘事实回滚内存态（add/setDefault/上一次 save 只在内存或旧文件上），
            // 留在表单可重试；env 写失败时配置文件字节未动。
            try? store.load()
            presentSaveFailure(error)
            return
        }
        formModel = nil
        formWindow?.orderOut(nil)
        formWindow = nil
        onFinished()
    }

    private func presentSaveFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "保存失败"
        alert.informativeText = "写入配置时出错：\(error.localizedDescription)\n请检查文件权限后重试。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

// MARK: - 首跑表单窗

/// 首跑表单窗：共享 `ProfileFormView`（`hidesDefaultToggle: true`，无默认行）
/// +「保 存」渐变主按钮；无标准关闭按钮出口，仅「保存」路径。
private final class FirstRunFormWindow: NSWindow {

    init(model: ProfileFormModel, onSave: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        title = "配置模型"
        contentView = NSHostingView(rootView: FirstRunFormRoot(model: model, onSave: onSave))
    }
}

private struct FirstRunFormRoot: View {
    @ObservedObject var model: ProfileFormModel
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 首跑单模型必然成为默认：不渲染「设为默认」行（I-4），保存仍自动默认
            ProfileFormView(model: model, hidesDefaultToggle: true)
                .padding(20)
            Spacer(minLength: 0)
            Divider()
                .overlay(UIPalette.hairline)
            HStack {
                Spacer()
                Button("保 存", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GradientPrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(UIPalette.windowCard)
        .frame(minWidth: 520, minHeight: 520)
    }
}
