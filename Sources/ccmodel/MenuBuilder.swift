import Foundation

/// 菜单单项规格：`kind` 决定语义，其余为呈现属性；由状态项与导入弹窗装配消费。
struct MenuItemSpec: Equatable {
    enum Kind: Equatable {
        case model(UUID)
        case customConfig
        case separator
        case preferences
        case quit
    }

    var kind: Kind
    var title: String
    var isSelected: Bool
    var isEnabled: Bool
}

/// 菜单规格构建：纯函数，产出 `[MenuItemSpec]`；排序委托 `ModelSort.ordered`。
enum MenuBuilder {
    /// 顺序：currentID 对应模型排第 1 且 isSelected=true（不在 models 中则忽略）；
    /// 其余按 `ModelSort.ordered`（lastSelectedAt 降序、nil 保持添加顺序）。
    /// showsCustomConfig=true 时 customConfig 项排最前、isEnabled=false，
    /// 且此时所有模型项 isSelected=false（导入弹窗形态）。
    /// defaultID 对应项 title 追加「（默认）」（含它同时是 current 的情形）。
    /// 模型组与偏好设置之间恰一个 separator。
    static func buildItems(
        models: [ModelProfile],
        currentID: ModelProfile.ID?,
        defaultID: UUID?,
        showsCustomConfig: Bool
    ) -> [MenuItemSpec] {
        let allowsSelection = !showsCustomConfig
        var modelItems: [MenuItemSpec] = []

        if let currentID, let current = models.first(where: { $0.id == currentID }) {
            modelItems.append(makeItem(for: current, isSelected: allowsSelection, defaultID: defaultID))
        }
        let rest = models.filter { $0.id != currentID }
        modelItems.append(
            contentsOf: ModelSort.ordered(rest).map {
                makeItem(for: $0, isSelected: false, defaultID: defaultID)
            }
        )

        var items: [MenuItemSpec] = []
        if showsCustomConfig {
            items.append(MenuItemSpec(
                kind: .customConfig,
                title: "自定义配置",
                isSelected: false,
                isEnabled: false
            ))
        }
        items.append(contentsOf: modelItems)
        items.append(MenuItemSpec(kind: .separator, title: "", isSelected: false, isEnabled: false))
        items.append(MenuItemSpec(kind: .preferences, title: "偏好设置…", isSelected: false, isEnabled: true))
        items.append(MenuItemSpec(kind: .quit, title: "退出 CC Model", isSelected: false, isEnabled: true))
        return items
    }

    private static func makeItem(
        for model: ModelProfile,
        isSelected: Bool,
        defaultID: UUID?
    ) -> MenuItemSpec {
        var title = model.displayName
        if model.id == defaultID {
            title += "（默认）"
        }
        return MenuItemSpec(kind: .model(model.id), title: title, isSelected: isSelected, isEnabled: true)
    }
}
