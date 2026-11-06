import AppKit

/// 窗口居中基座（I-3）：统一「窗口打开前居中」。内容尺寸设置由调用方自理，
/// `prepare` 内执行归位与居中；被 PreferencesWindow / FirstRunCoordinator
/// （Task 2 接线）与 ImportDialog（本任务接线）消费。
enum WindowPresenter {

    /// 居中窗口于主屏（多显示器已裁决，2026-11-06）：把窗口保持原尺寸
    /// `setFrame` 到「主屏可见范围的几何中心」——归位（曾被拖往副屏、复用
    /// 路径保存了离屏坐标）与居中一步到位，「主屏为锚」在复用路径仍成立。
    ///
    /// 不用 `window.center()`（双屏环境实证，2026-11-06）：`setFrame(display: false)`
    /// 之后 AppKit 对窗口屏幕归属的解析滞后，`center()` 按陈旧归属（如副屏）
    /// 计算，会把刚归位的窗口重新居中到副屏。因此全部窗口（含已在主屏可见
    /// 范围内、横跨双屏的窗口）都走纯几何路径，确定性不依赖窗口屏幕归属。
    ///
    /// 主屏判据：`NSScreen.screens.first`（origin (0,0) 的 AppKit 明确主屏定义，
    /// 不用随键盘焦点浮动的 `NSScreen.main`）。无屏环境（理论不可达）回退
    /// `window.center()`，不崩溃。
    static func prepare(_ window: NSWindow) {
        guard let visibleFrame = NSScreen.screens.first?.visibleFrame else {
            window.center()
            return
        }
        let size = window.frame.size
        window.setFrame(
            NSRect(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: false
        )
    }
}
