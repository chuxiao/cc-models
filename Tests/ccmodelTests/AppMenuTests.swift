import AppKit
import Testing
@testable import ccmodel

/// 主菜单装配（缺陷 2 修复）：accessory 应用从未设置 NSApp.mainMenu，
/// 「编辑」菜单缺失导致文本框收不到 paste:/copy:/cut:/selectAll: 派发，Cmd+V 等失效。
/// 断言经响应链派发的动作与快捷键绑定齐备。
struct AppMenuTests {

    private func item(withAction action: String, in menu: NSMenu) -> NSMenuItem? {
        menu.items.first { $0.action == NSSelectorFromString(action) }
    }

    @Test func mainMenuContainsEditMenuWithStandardTextEditingShortcuts() throws {
        let menu = AppMenu.buildMainMenu()

        let edit = try #require(menu.items.first { $0.title == "编辑" }?.submenu)
        for (action, key) in [("cut:", "x"), ("copy:", "c"), ("paste:", "v"), ("selectAll:", "a")] {
            let item = try #require(item(withAction: action, in: edit), "\(action) 缺失")
            #expect(item.keyEquivalent == key)
            #expect(item.keyEquivalentModifierMask == .command)
        }

        let appMenu = try #require(menu.items.first?.submenu)
        let quit = try #require(item(withAction: "terminate:", in: appMenu))
        #expect(quit.keyEquivalent == "q")
    }
}
