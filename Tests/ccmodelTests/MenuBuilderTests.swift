import Foundation
import Testing
@testable import ccmodel

/// 菜单规格五状态完整序列断言与退化输入（Task 4 验收标准对应）。
struct MenuBuilderTests {

    private func profile(
        _ name: String,
        selectedAt: Date? = nil
    ) -> ModelProfile {
        ModelProfile(id: UUID(), displayName: name, env: [:], lastSelectedAt: selectedAt)
    }

    private func modelItem(
        _ id: UUID,
        _ title: String,
        selected: Bool = false
    ) -> MenuItemSpec {
        MenuItemSpec(kind: .model(id), title: title, isSelected: selected, isEnabled: true)
    }

    private let separator = MenuItemSpec(kind: .separator, title: "", isSelected: false, isEnabled: false)
    private let preferences = MenuItemSpec(kind: .preferences, title: "偏好设置…", isSelected: false, isEnabled: true)
    private let quit = MenuItemSpec(kind: .quit, title: "退出 CC Models", isSelected: false, isEnabled: true)

    @Test func regularMenuCurrentPinnedCheckedWithDefaultAnnotation() {
        let zhipu = profile("智谱", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let deepseek = profile("DeepSeek", selectedAt: Date(timeIntervalSinceReferenceDate: 200))
        let items = MenuBuilder.buildItems(
            models: [zhipu, deepseek],
            currentID: zhipu.id,
            defaultID: deepseek.id,
            showsCustomConfig: false
        )
        #expect(items == [
            modelItem(zhipu.id, "智谱", selected: true),
            modelItem(deepseek.id, "DeepSeek（默认）"),
            separator,
            preferences,
            quit,
        ])
    }

    @Test func customConfigPinnedDisabledAndSelectionsCleared() {
        let zhipu = profile("智谱", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let deepseek = profile("DeepSeek", selectedAt: Date(timeIntervalSinceReferenceDate: 200))
        let items = MenuBuilder.buildItems(
            models: [zhipu, deepseek],
            currentID: zhipu.id,
            defaultID: deepseek.id,
            showsCustomConfig: true
        )
        #expect(items == [
            MenuItemSpec(kind: .customConfig, title: "自定义配置", isSelected: false, isEnabled: false),
            modelItem(zhipu.id, "智谱"),
            modelItem(deepseek.id, "DeepSeek（默认）"),
            separator,
            preferences,
            quit,
        ])
    }

    @Test func currentForcedAheadOfRecencyLeader() {
        // recency 首位是 deepseek（更近选中），current 是 zhipu——zhipu 被强制提前。
        let zhipu = profile("智谱", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let deepseek = profile("DeepSeek", selectedAt: Date(timeIntervalSinceReferenceDate: 200))
        let items = MenuBuilder.buildItems(
            models: [zhipu, deepseek],
            currentID: zhipu.id,
            defaultID: nil,
            showsCustomConfig: false
        )
        #expect(items == [
            modelItem(zhipu.id, "智谱", selected: true),
            modelItem(deepseek.id, "DeepSeek"),
            separator,
            preferences,
            quit,
        ])
    }

    @Test func defaultEqualsCurrentGetsBothAnnotationAndCheckmark() {
        let zhipu = profile("智谱")
        let items = MenuBuilder.buildItems(
            models: [zhipu],
            currentID: zhipu.id,
            defaultID: zhipu.id,
            showsCustomConfig: false
        )
        #expect(items == [
            modelItem(zhipu.id, "智谱（默认）", selected: true),
            separator,
            preferences,
            quit,
        ])
    }

    @Test func emptyModelsWithCustomConfig() {
        let items = MenuBuilder.buildItems(
            models: [],
            currentID: nil,
            defaultID: nil,
            showsCustomConfig: true
        )
        #expect(items == [
            MenuItemSpec(kind: .customConfig, title: "自定义配置", isSelected: false, isEnabled: false),
            separator,
            preferences,
            quit,
        ])
    }

    @Test func emptyModelsWithoutCustomConfig() {
        let items = MenuBuilder.buildItems(
            models: [],
            currentID: nil,
            defaultID: nil,
            showsCustomConfig: false
        )
        #expect(items == [separator, preferences, quit])
    }

    @Test func danglingCurrentIDIsIgnored() {
        // currentID 不在 models 中：不置顶不勾选，按 recency 原序。
        let zhipu = profile("智谱", selectedAt: Date(timeIntervalSinceReferenceDate: 100))
        let deepseek = profile("DeepSeek", selectedAt: Date(timeIntervalSinceReferenceDate: 200))
        let items = MenuBuilder.buildItems(
            models: [zhipu, deepseek],
            currentID: UUID(),
            defaultID: nil,
            showsCustomConfig: false
        )
        #expect(items == [
            modelItem(deepseek.id, "DeepSeek"),
            modelItem(zhipu.id, "智谱"),
            separator,
            preferences,
            quit,
        ])
    }

    @Test func undatedModelsKeepInsertionOrderAfterCurrent() {
        // 全部无 lastSelectedAt：current 置顶，其余保持添加顺序。
        let first = profile("甲")
        let second = profile("乙")
        let third = profile("丙")
        let items = MenuBuilder.buildItems(
            models: [first, second, third],
            currentID: second.id,
            defaultID: nil,
            showsCustomConfig: false
        )
        #expect(items.map(\.kind) == [
            .model(second.id),
            .model(first.id),
            .model(third.id),
            .separator,
            .preferences,
            .quit,
        ])
    }
}
