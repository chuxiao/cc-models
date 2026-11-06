import AppKit

/// 窗口居中基座（I-3）：统一「窗口打开前居中」。内容尺寸设置由调用方自理，
/// `prepare` 内执行归位与居中；被 PreferencesWindow / FirstRunCoordinator
/// （Task 2 接线）与 ImportDialog（本任务接线）消费。
enum WindowPresenter {

    /// 居中窗口于主屏（多显示器已裁决，2026-11-06）：窗口 frame 与主屏可见
    /// 范围不相交（曾被拖往副屏，或复用路径保存了离屏坐标）时，先保持原尺寸
    /// 归位主屏可见范围再居中——「主屏为锚」在复用路径仍成立；已在主屏可见
    /// 范围内的窗口直接居中。对已可见窗口重复调用除位置归中外无其他副作用。
    ///
    /// 归位判据取「与主屏可见范围相交检测」（主屏 = `NSScreen.screens.first`，
    /// origin (0,0) 的 AppKit 明确主屏定义；不用随键盘焦点浮动的 `NSScreen.main`），
    /// 而非 `window.screen == 主屏`——后者对完全离屏（window.screen 为 nil）的
    /// 窗口需另行分支。无屏环境（理论不可达）跳过归位仅居中，不崩溃。
    static func prepare(_ window: NSWindow) {
        if let visibleFrame = NSScreen.screens.first?.visibleFrame,
           !visibleFrame.intersects(window.frame) {
            window.setFrame(
                NSRect(origin: visibleFrame.origin, size: window.frame.size),
                display: false
            )
        }
        window.center()
    }
}
