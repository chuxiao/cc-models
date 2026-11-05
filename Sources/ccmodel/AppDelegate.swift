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

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            // Task 5 内为空实现占位；Task 8 注入自定义配置弹窗。
            onCustomConfigDetected: { _ in }
        )
        controller.start()
        statusItemController = controller
        firstRunCoordinator = nil
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
