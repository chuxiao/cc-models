import AppKit

/// 状态项与菜单装配（Task 5）：图标与标题（I-1/I-2）、menuNeedsUpdate 全量重建、
/// 点击分发与自定义配置触发时机。NSStatusItem/NSMenu 装配不写单测，
/// 由 verification.md S1/S3 人工核对。
final class StatusItemController: NSObject, NSMenuDelegate {

    /// readEnv 失败（settings.json 损坏）或无法识别当前模型时的标题，
    /// 由装配层直接设置、不经 statusItemTitle（控制者裁定，2026-11-05）；
    /// ⇄ 前缀由状态项图标图像承担后仅保留文字「—」（I-1）。
    private static let unknownTitle = "—"

    private let store: ModelStore
    private let switcher: ModelSwitcher
    private let onCustomConfigDetected: ([String: String]) -> Void
    /// 偏好设置动作（Task 7 起由装配层注入真窗口呈现；默认空操作，
    /// 使 Task 5 既有调用点与测试无需改动）。
    private let onPreferences: () -> Void

    private let menu = NSMenu()
    private var statusItem: NSStatusItem?

    /// menuDidClose 判定的延后执行器：默认派发到 main queue 下一轮，保证菜单
    /// 跟踪期内的条目 action（点击切换）先落地；测试注入同步暂存以确定性断言。
    var deferMenuCloseEvaluation: (@escaping () -> Void) -> Void = { body in
        DispatchQueue.main.async(execute: body)
    }

    /// 标题写出器：nil 时写状态项按钮（生产路径）；测试注入记录器，
    /// 在不创建 NSStatusItem 的前提下断言标题刷新时序与文案。
    var titleWriter: ((String) -> Void)?

    /// 状态项图标供给缝（I-2）：默认解析系统符号「直线双向箭头」；返回 nil 时
    /// 回退为无图像、仅文字标题（不崩溃，单测注入 nil 覆盖回退分支）。
    var symbolProvider: () -> NSImage? = {
        NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)
    }

    init(
        store: ModelStore,
        switcher: ModelSwitcher,
        onCustomConfigDetected: @escaping ([String: String]) -> Void,
        onPreferences: @escaping () -> Void = {}
    ) {
        self.store = store
        self.switcher = switcher
        self.onCustomConfigDetected = onCustomConfigDetected
        self.onPreferences = onPreferences
        super.init()
    }

    /// 创建状态项并接线菜单；图标与标题立即装配一次。
    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        statusItem = item
        applyIcon(to: item.button)
        refreshTitle()
    }

    /// 图标装配（I-2）：symbolProvider 结果设为按钮模板图，点阵尺寸适配状态栏
    /// （约 16pt）。返回 nil → 提前返回，无图像、仅文字标题（不崩溃）；只设图像，
    /// 不触碰标题——titleWriter 缝只管标题字符串，两者互不干扰。
    /// 独立成方法使回退分支无需创建 NSStatusItem 即可单测。
    func applyIcon(to button: NSButton?) {
        guard let symbol = symbolProvider() else { return }
        symbol.isTemplate = true
        let side = NSStatusBar.system.thickness - 6
        symbol.size = NSSize(width: side, height: side)
        button?.image = symbol
        button?.imagePosition = .imageLeading
    }

    // MARK: - 标题

    private func refreshTitle() {
        if let id = switcher.currentModelID(),
           let profile = store.configuration.models.first(where: { $0.id == id }) {
            applyTitle(ProfileFields.statusItemTitle(displayName: profile.displayName))
        } else {
            applyTitle(Self.unknownTitle)
        }
    }

    private func applyTitle(_ title: String) {
        if let titleWriter {
            titleWriter(title)
            return
        }
        statusItem?.button?.title = title
    }

    // MARK: - 菜单构建

    /// 菜单即将展开：重新读 env 并以 MenuBuilder 全量重建全部条目。
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        // 标题与菜单同周期刷新：外部改 env（手改 settings.json、Claude Code 更新器写入）
        // 后开菜单即如实反映，不再等到下一次应用内切换（终审修复，2026-11-06）。
        refreshTitle()
        menu.removeAllItems()
        // readEnv 抛错 → currentModelID 为 nil → 菜单照常构建且 customConfig 置灰项显示。
        let currentID = switcher.currentModelID()
        let specs = MenuBuilder.buildItems(
            models: store.menuOrderedModels(),
            currentID: currentID,
            defaultID: store.configuration.defaultModelID,
            showsCustomConfig: currentID == nil
        )
        for spec in specs {
            guard spec.kind != .separator else {
                menu.addItem(.separator())
                continue
            }
            let item = SpecMenuItem(spec: spec)
            item.isEnabled = spec.isEnabled
            item.state = spec.isSelected ? .on : .off
            if spec.isEnabled {
                item.action = #selector(itemActivated(_:))
                item.target = self
            }
            menu.addItem(item)
        }
    }

    // MARK: - 点击分发

    @objc private func itemActivated(_ sender: NSMenuItem) {
        guard let item = sender as? SpecMenuItem else { return }
        switch item.spec.kind {
        case .model(let id):
            do {
                try switcher.switchTo(id: id)
                refreshTitle()
            } catch {
                // 失败通知已由 ModelSwitcher 发出；settings 与存储未变，标题无需刷新。
            }
        case .preferences:
            onPreferences()
        case .quit:
            NSApp.terminate(sender)
        case .customConfig, .separator:
            break // 置灰项与非交互项，不可达
        }
    }

    // MARK: - 自定义配置触发

    /// 菜单关闭：延后一轮再判定「env 未命中且未被忽略」→ 以该 env 回调恰一次。
    /// AppKit 未文档化条目 action 与 menuDidClose 的派发顺序；延后一轮使菜单
    /// 跟踪期内点击模型项触发的 switchTo 先落地，此后读到的 env 才是关菜单后
    /// 的真实状态，任何派发顺序下均正确。readEnv 抛错（无法获得 env）→ 不回调。
    func menuDidClose(_ menu: NSMenu) {
        deferMenuCloseEvaluation { [weak self] in
            guard let self else { return }
            guard let env = self.switcher.currentEnv() else { return }
            guard CurrentModelDetector.match(env: env, in: self.store.configuration.models) == nil else { return }
            guard !self.store.isDismissedEnv(env) else { return }
            self.onCustomConfigDetected(env)
        }
    }
}

/// 携带菜单规格的条目，点击分发时据此路由到 model/preferences/quit。
private final class SpecMenuItem: NSMenuItem {
    let spec: MenuItemSpec

    init(spec: MenuItemSpec) {
        self.spec = spec
        super.init(title: spec.title, action: nil, keyEquivalent: "")
    }

    required init(coder: NSCoder) {
        fatalError("不支持从 nib 恢复")
    }
}
