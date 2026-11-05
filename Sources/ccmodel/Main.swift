import AppKit

/// 进程入口：accessory 策略（无 Dock 图标）+ 应用委托装配。
@main
struct Main {
    static func main() {
        // NSApplication.delegate 为 unowned 引用，本地常量随 app.run() 的栈帧存活全程。
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
