import AppKit
import SwiftUI

/// 偏好窗口（Task 7）：侧栏+详情 NavigationSplitView——侧栏模型列表（默认行
/// 内含「默认」徽标逐字）+ 侧栏底部 ＋/－ 与「开机自启」开关；详情为共享
/// `ProfileFormView` +「保存」按钮。窗口 UI 不写单测，由 verification.md
/// S7/S8/S12/S14 人工核对。
final class PreferencesWindow: NSWindow {

    init(viewModel: PreferencesViewModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        // 装配层长期强持有并重复 useKeyAndOrderFront，关闭仅隐去不释放
        isReleasedWhenClosed = false
        title = "偏好设置"
        contentView = NSHostingView(rootView: PreferencesRoot(viewModel: viewModel))
    }
}

private struct PreferencesRoot: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        } detail: {
            detail
        }
        .frame(minWidth: 680, minHeight: 520)
        .alert("操作失败", isPresented: alertPresented) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    // MARK: - 侧栏

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: selectedIDBinding) {
                ForEach(viewModel.modelList) { model in
                    row(for: model)
                        .tag(model.id)
                }
            }
            Divider()
            HStack(spacing: 12) {
                Button("＋添加", action: { viewModel.beginAdd() })
                Button("－删除", action: deleteSelected)
                    .disabled(!viewModel.canDelete || viewModel.selectedID == nil)
                Spacer()
                Toggle("开机自启", isOn: launchAtLoginBinding)
            }
            .padding(12)
        }
    }

    /// 列表行：显示名 + 默认徽标「默认」（逐字）。
    private func row(for model: ModelProfile) -> some View {
        HStack(spacing: 6) {
            Text(model.displayName)
            if viewModel.defaultModelID == model.id {
                Text("默认")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    // MARK: - 详情

    private var detail: some View {
        VStack(spacing: 0) {
            ProfileFormView(model: viewModel.form)
            Divider()
            HStack {
                Spacer()
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }

    // MARK: - 动作

    private func save() {
        do {
            try viewModel.saveForm()
        } catch {
            // 校验错误已由 form.validationErrors 行内提示；其余为落盘失败 → 说明框。
            if viewModel.form.validationErrors.isEmpty {
                viewModel.alertMessage = "保存失败：\(error.localizedDescription)"
            }
        }
    }

    private func deleteSelected() {
        do {
            try viewModel.deleteSelected()
        } catch {
            viewModel.alertMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 绑定（禁 @State，绑定一律由 ViewModel 派生）

    /// 侧栏选择：经 `select(id:)` 派生——选中变更必须走 VM 才会同步载入目标模型
    /// 表单（loadForm），直接写 @Published selectedID 会让详情停留在旧模型表单，
    /// 保存即污染错误记录。List 反选回写 nil 时忽略，保持当前选中。
    private var selectedIDBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedID },
            set: { newValue in
                guard let id = newValue else { return }
                viewModel.select(id: id)
            }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { viewModel.launchAtLogin },
            set: { viewModel.setLaunchAtLogin($0) }
        )
    }

    private var alertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { shown in
                if !shown {
                    viewModel.alertMessage = nil
                }
            }
        )
    }
}
