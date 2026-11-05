import AppKit

/// 应用委托：进程装配。加载应用配置；配置损坏 → 说明窗（含配置文件路径与解决
/// 建议）后退出，绝不静默按空配置进入首跑（裁决，2026-11-05）；
/// 有模型 → 启动状态项；无模型 → 首跑接缝（Task 6 接入 FirstRunCoordinator）。
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let store = ModelStore()
    private let notifier = Notifier()
    private lazy var switcher = ModelSwitcher(store: store, writer: SettingsWriter(), notifier: notifier)
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try store.load()
        } catch {
            presentCorruptConfigurationAlertThenExit()
            return
        }

        guard !store.configuration.models.isEmpty else {
            // 首跑分支接缝：Task 6 接入 FirstRunCoordinator——
            // 空配置走欢迎窗 → 表单，完成后回调创建状态项；本任务不建任何窗口。
            return
        }

        let controller = StatusItemController(
            store: store,
            switcher: switcher,
            // Task 5 内为空实现占位；Task 8 注入自定义配置弹窗。
            onCustomConfigDetected: { _ in }
        )
        controller.start()
        statusItemController = controller
    }

    // MARK: - 配置损坏

    private func presentCorruptConfigurationAlertThenExit() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "CC Model 配置文件已损坏"
        alert.informativeText = """
            无法读取应用配置文件：
            \(Self.defaultConfigurationFileURL.path)

            请修复该文件的 JSON 语法，或删除该文件后重启应用、重新完成首次配置。
            """
        alert.addButton(withTitle: "退出")
        alert.runModal()
        NSApp.terminate(nil)
    }

    /// 与 `ModelStore` 默认存储位置一致的 config.json 路径，仅用于说明窗展示。
    /// ModelStore 未暴露该路径，装配层按同一规则重建，两者同源演进。
    private static var defaultConfigurationFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cc-model", isDirectory: true)
            .appendingPathComponent("config.json", isDirectory: false)
    }
}
