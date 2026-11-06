import AppKit

/// 自定义配置导入弹窗（Task 8）：NSAlert 呈现——说明文字 + 显示名 NSTextField +
/// 已有模型 NSPopUpButton，三出口（纳入新模型 / 覆盖已有模型 / 取消）回调
/// `ImportDecision`，落库由 `ImportCoordinator.decide` 完成。
///
/// 重名（或空白）输入时弹窗保持呈现并提示改名，直至输入有效或用户取消——NSAlert
/// 无原生校验循环，以 runModal 循环重呈现实现（accessory view 复用同一实例，
/// 已输入的显示名保留）。
///
/// 呈现时机由调用方保证在 menuDidClose 后（Task 5 契约）；呈现期间重复触发被忽略
/// （可重复触发前需先关闭）。NSAlert 装配不写单测，由 verification.md S3/S4/S5 人工核对。
final class ImportDialog {

    private let models: [ModelProfile]
    private let handler: (ImportDecision) -> Void

    /// 呈现互斥：runModal 为同步模态，但 menuDidClose 的延后判定块在模态期间仍会
    /// 派发，防重入叠加第二只弹窗；被忽略的触发在该 env 未 dismissed 时下次菜单
    /// 关闭会重新询问。
    private static var isPresenting = false

    private static let explanation = "检测到尚未录入的自定义配置。\n可将其纳入为新模型，或覆盖一个已有模型。"
    private static let blankNamePrompt = "显示名不能为空，请输入显示名。"

    /// `models` 为下拉可选的已有模型（顺序由调用方给定）；`handler` 在弹窗关闭时
    /// 以三出口之一回调恰一次。
    init(models: [ModelProfile], handler: @escaping (ImportDecision) -> Void) {
        self.models = models
        self.handler = handler
    }

    /// 以应用模态呈现并阻塞至用户完成三出口之一（menuDidClose 后主线程调用）。
    func present() {
        guard !Self.isPresenting else { return }
        Self.isPresenting = true
        defer { Self.isPresenting = false }

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        nameField.placeholderString = "新模型的显示名"

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26), pullsDown: false)
        for model in models {
            popup.addItem(withTitle: model.displayName)
        }
        popup.selectItem(at: 0)

        let accessory = NSStackView(views: [
            Self.labeledRow("显示名：", nameField),
            Self.labeledRow("覆盖已有模型：", popup),
        ])
        accessory.orientation = .vertical
        accessory.alignment = .leading
        accessory.spacing = 8
        accessory.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "自定义配置"
        alert.informativeText = Self.explanation
        alert.accessoryView = accessory
        alert.addButton(withTitle: "纳入新模型")
        alert.addButton(withTitle: "覆盖已有模型")
        alert.addButton(withTitle: "取消")
        alert.buttons.last?.keyEquivalent = "\u{1b}" // Esc → 取消
        alert.window.initialFirstResponder = nameField

        // runModal 前居中（I-3）：弹窗窗口中心 == 所在屏中心。
        WindowPresenter.prepare(alert.window)

        NSApp.activate(ignoringOtherApps: true)
        while true {
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                let trimmed = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    alert.informativeText = Self.blankNamePrompt
                    continue
                }
                if isDuplicate(displayName: trimmed) {
                    alert.informativeText = "显示名「\(trimmed)」已被使用，请改名。"
                    continue
                }
                handler(.newModel(name: trimmed))
                return
            case .alertSecondButtonReturn:
                if let target = selectedModel(in: popup) {
                    handler(.overwrite(targetID: target.id))
                    return
                }
                alert.informativeText = "请选择要覆盖的已有模型。"
                continue
            default:
                handler(.cancel)
                return
            }
        }
    }

    // MARK: - 私有

    /// 与落库口径一致的重名判定（§2 F5：去空白后与任一已有名相等）。
    private func isDuplicate(displayName: String) -> Bool {
        models.contains {
            $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines) == displayName
        }
    }

    /// 下拉当前选中的目标模型；无有效选中（模型列表为空，正常运行不可达）→ nil。
    private func selectedModel(in popup: NSPopUpButton) -> ModelProfile? {
        let index = popup.indexOfSelectedItem
        guard index >= 0, models.indices.contains(index) else { return nil }
        return models[index]
    }

    private static func labeledRow(_ title: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }
}
