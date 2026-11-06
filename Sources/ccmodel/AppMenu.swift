import AppKit

/// 主菜单装配（缺陷 2 修复）：accessory 应用同样需要 `NSApp.mainMenu`——
/// 文本编辑快捷键（Cmd+V/C/X/A）由「编辑」菜单的 paste:/copy:/cut:/selectAll:
/// 动作经响应链派发，无主菜单则所有文本框收不到粘贴等命令。
enum AppMenu {

    /// 最小主菜单：应用菜单（退出 CC Models，Cmd+Q）+ 编辑菜单
    /// （剪切 Cmd+X / 拷贝 Cmd+C / 粘贴 Cmd+V / 全选 Cmd+A）。
    /// 菜单项 target 为 nil：文本动作沿响应链到 first responder，terminate: 到 NSApplication。
    static func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        appItem.title = "CC Models"
        let appMenu = NSMenu(title: "CC Models")
        appMenu.addItem(NSMenuItem(
            title: "退出 CC Models",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        editItem.title = "编辑"
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(
            title: "剪切",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        ))
        editMenu.addItem(NSMenuItem(
            title: "拷贝",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        ))
        editMenu.addItem(NSMenuItem(
            title: "粘贴",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        ))
        editMenu.addItem(NSMenuItem(
            title: "全选",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        ))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        return mainMenu
    }
}
