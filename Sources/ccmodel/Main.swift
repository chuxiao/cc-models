import AppKit

/// 进程入口：accessory 策略（无 Dock 图标）+ 应用委托装配。
@main
struct Main {

    /// 进程级强持有：`NSApplication.delegate` 是 weak 引用，仅靠局部变量赋值
    /// 不能保证委托存活——ARC 可在最后一次使用后立即释放对象。static let 与
    /// 进程同寿，为委托提供独立于赋值语句的全程强引用。
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
