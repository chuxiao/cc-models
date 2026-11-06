import AppKit

/// 窗口居中基座（I-3）：统一「窗口打开前居中」。内容尺寸设置由调用方自理，
/// `prepare` 内执行居中；被 PreferencesWindow / FirstRunCoordinator（Task 2 接线）
/// 与 ImportDialog（本任务接线）消费。
enum WindowPresenter {

    /// 居中窗口于所在屏（首次打开即主屏）；窗口曾被拖往副屏时，先归位主屏可见
    /// 范围再居中（「主屏为锚」，多显示器复用路径已裁决，2026-11-06）。
    /// 对已可见窗口重复调用除位置归中外无其他副作用。
    static func prepare(_ window: NSWindow) {
        window.center()
    }
}
