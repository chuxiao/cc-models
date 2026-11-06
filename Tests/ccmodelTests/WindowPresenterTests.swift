import AppKit
import Testing
@testable import ccmodel

/// 窗口居中基座（I-3）：多显示器复用路径的「主屏为锚」归位语义。
struct WindowPresenterTests {

    /// 窗口 frame 不在主屏可见范围（副屏窗口或复用路径保存的离屏坐标）时，
    /// prepare 先归位主屏可见范围再居中——prepare 后窗口位于主屏可见范围内。
    ///
    /// 构造方式：NSWindow 构造参数会被 AppKit constrainFrameRect 拉回屏内，
    /// 呈现不了「副屏/离屏」位置，故窗口创建后以 setFrame（窗口拖动机制，
    /// 不受约束）放置。副屏 frame 优先取真实副屏可见范围中心（多屏环境精确
    /// 复现裁决场景：窗口所在屏为副屏，center() 的 AppKit 语义只会居中于副屏、
    /// 不会归位主屏）；单屏环境退化为远离主屏的离屏 frame。两种构造共用同一
    /// 归位判据：frame 与主屏可见范围不相交。NSWindow 须主线程实例化，
    /// 故测试标注 @MainActor。
    @Test @MainActor
    func prepareMovesWindowOutsideMainScreenIntoMainScreenVisibleFrame() throws {
        let visible = try #require(NSScreen.screens.first?.visibleFrame)
        let secondaryVisible = NSScreen.screens.count > 1 ? NSScreen.screens.last?.visibleFrame : nil
        let offMainScreenFrame: NSRect
        if let secondaryVisible {
            offMainScreenFrame = NSRect(
                x: secondaryVisible.midX - 200,
                y: secondaryVisible.midY - 150,
                width: 400,
                height: 300
            )
        } else {
            offMainScreenFrame = NSRect(
                x: visible.maxX + 4000,
                y: visible.maxY + 4000,
                width: 400,
                height: 300
            )
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: offMainScreenFrame.size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.setFrame(offMainScreenFrame, display: false)

        // 前提：窗口确实不在主屏可见范围（所在屏为副屏或完全离屏）
        #expect(!visible.intersects(window.frame))

        WindowPresenter.prepare(window)

        #expect(visible.intersects(window.frame))
        // 精度：窗口中心 ≈ 主屏可见范围中心（容差 1pt）——AppKit 对窗口坐标做
        // 亚像素对齐（实测 visibleFrame.midY 为半点时 frame y 恒定取整，偏差恒
        // 0.5pt），亚点中心在像素对齐约束下不可精确命中，1pt 内视为几何居中。
        #expect(abs(window.frame.midX - visible.midX) < 1.0)
        #expect(abs(window.frame.midY - visible.midY) < 1.0)
    }
}
