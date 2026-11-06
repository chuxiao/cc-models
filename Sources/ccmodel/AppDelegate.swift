import AppKit

/// 应用委托：进程装配。加载应用配置；配置损坏 → 说明窗（含配置文件路径与解决
/// 建议）后退出，绝不静默按空配置进入首跑（裁决，2026-11-05）；
/// 有模型 → 启动状态项；无模型 → FirstRunCoordinator（欢迎窗 → 表单 → 保存，
/// 完成回调创建状态项进入常驻，Task 6 接入）。
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let store = ModelStore(directory: AppDelegate.configDirectory)
    private let notifier = Notifier()
    private lazy var switcher = ModelSwitcher(store: store, writer: SettingsWriter(), notifier: notifier)
    private var statusItemController: StatusItemController?
    private var firstRunCoordinator: FirstRunCoordinator?
    /// 偏好窗口与模型（Task 7）：菜单「偏好设置…」打开；已存在时 reload + 前置复用，
    /// 不重复开窗。
    private var preferencesWindow: PreferencesWindow?
    private var preferencesViewModel: PreferencesViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 全局固定深色外观：启动时一次性设置，三窗口 + 弹窗统一继承（UI 规格全局项）。
        // 规格行文作 NSAppearance(named: .dark)；macOS AppKit 无 .dark（UIKit 常量），
        // 对应常量为 .darkAqua，语义一致（固定深色外观）。
        NSApp.appearance = NSAppearance(named: .darkAqua)

        do {
            try store.load()
        } catch {
            presentCorruptConfigurationAlertThenExit()
            return
        }

        guard !store.configuration.models.isEmpty else {
            // 首跑分支：空配置走欢迎窗 → 表单，保存完成后回调创建状态项。
            let coordinator = FirstRunCoordinator(store: store, switcher: switcher) { [weak self] in
                self?.startStatusItem()
            }
            firstRunCoordinator = coordinator
            coordinator.runIfNeeded()
            return
        }

        startStatusItem()
    }

    // MARK: - 常驻装配

    private func startStatusItem() {
        let controller = StatusItemController(
            store: store,
            switcher: switcher,
            // Task 8：自定义配置导入弹窗（呈现时机由 StatusItemController 保证在
            // menuDidClose 后，见 presentImportDialog）。
            onCustomConfigDetected: { [weak self] env in self?.presentImportDialog(env: env) },
            // Task 7：菜单「偏好设置…」打开偏好窗口（原空操作占位接线真窗口）。
            onPreferences: { [weak self] in self?.showPreferences() }
        )
        controller.start()
        statusItemController = controller
        firstRunCoordinator = nil
    }

    // MARK: - 自定义配置导入

    /// 自定义配置导入弹窗（Task 8）：menuDidClose 的延后判定回调 → 三出口决策
    /// 经 `ImportCoordinator.decide` 落库（纳入/覆盖经 switchTo 成为当前，取消记录
    /// 已忽略 env）。落库抛错（空 env 兜底、写失败）不在此叠加错误弹窗：内存态已由
    /// decide 回滚到磁盘基线、settings 字节不变，该 env 未记录 dismissed，下次菜单
    /// 关闭会再次询问（自愈）。
    private func presentImportDialog(env: [String: String]) {
        let dialog = ImportDialog(models: store.menuOrderedModels()) { [weak self] decision in
            guard let self else { return }
            try? ImportCoordinator.decide(decision, env: env, store: self.store, switcher: self.switcher)
        }
        dialog.present()
    }

    // MARK: - 偏好窗口

    /// 打开偏好窗口；已存在时从 store 重新同步（reload）并前置复用同一窗口。
    /// 首开与复用两条路径均在 makeKeyAndOrderFront 前经 `WindowPresenter.prepare`
    /// 归位主屏并居中（I-3 偏好窗接线归属，Task 2）。
    private func showPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = preferencesWindow {
            preferencesViewModel?.reload()
            WindowPresenter.prepare(window)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let viewModel = PreferencesViewModel(store: store, switcher: switcher)
        let window = PreferencesWindow(viewModel: viewModel)
        preferencesViewModel = viewModel
        preferencesWindow = window
        WindowPresenter.prepare(window)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - 配置目录解析

    /// 应用配置目录：环境变量 `CC_MODEL_CONFIG_DIR` 优先（verification.md S6 验证
    /// 用，无 UI、文档记录；裁决 2026-11-05），否则默认应用支持目录。
    /// SettingsWriter 不受影响——真实 ~/.claude/settings.json 始终是写入目标。
    private static var configDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["CC_MODEL_CONFIG_DIR"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cc-model", isDirectory: true)
    }

    // MARK: - 配置损坏

    private func presentCorruptConfigurationAlertThenExit() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "CC Model 配置文件已损坏"
        alert.informativeText = """
            无法读取应用配置文件：
            \(Self.configurationFileURL.path)

            请修复该文件的 JSON 语法，或删除该文件后重启应用、重新完成首次配置。
            """
        alert.addButton(withTitle: "退出")
        alert.runModal()
        NSApp.terminate(nil)
    }

    /// 与 `ModelStore` 实际存储位置一致的 config.json 路径（含 `CC_MODEL_CONFIG_DIR`
    /// 覆盖），仅用于说明窗展示。ModelStore 未暴露该路径，装配层按同一规则重建，
    /// 两者同源演进。
    private static var configurationFileURL: URL {
        configDirectory.appendingPathComponent("config.json", isDirectory: false)
    }
}
