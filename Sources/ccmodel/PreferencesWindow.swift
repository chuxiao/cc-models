import AppKit
import SwiftUI

/// 偏好窗口（Task 7；Task 2 视觉规格）：侧栏+详情 NavigationSplitView——侧栏模型
/// 列表（默认行内含「默认」徽标逐字、渐变底同主按钮）+ 侧栏底部 ＋/－ 与
/// 「开机自启」开关；详情为共享 `ProfileFormView` +「保 存」渐变主按钮。
/// 内容尺寸 720×480、最小 660×430（无上限）；打开前的归位居中由装配层
/// AppDelegate 两条路径经 `WindowPresenter.prepare` 完成（I-3 接线归属）。
/// 窗口 UI 不写单测，由 verification.md S7/S8/S12/S14 人工核对。
final class PreferencesWindow: NSWindow {

    init(viewModel: PreferencesViewModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        // 装配层长期强持有并重复 useKeyAndOrderFront，关闭仅隐去不释放
        isReleasedWhenClosed = false
        title = "CC Model 设置"
        // 最小 660×430；contentMaxSize 不设（默认零值即无上限）
        contentMinSize = NSSize(width: 660, height: 430)
        contentView = NSHostingView(rootView: PreferencesRoot(viewModel: viewModel))
    }
}

private struct PreferencesRoot: View {
    @ObservedObject var viewModel: PreferencesViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 320)
        } detail: {
            detail
        }
        .frame(minWidth: 660, minHeight: 430)
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
            .listStyle(.sidebar)
            // 侧栏底色取色值表 #24242C：去系统滚转底后自绘
            .scrollContentBackground(.hidden)
            // 选中行 #3A3F4D：macOS List 选中高亮随 tint 取色
            .tint(UIPalette.selectedRow)
            Divider()
                .overlay(UIPalette.hairline)
            HStack(spacing: 12) {
                Button("＋添加", action: { viewModel.beginAdd() })
                Button("－删除", action: deleteSelected)
                    .disabled(!viewModel.canDelete || viewModel.selectedID == nil)
                Spacer()
                Toggle("开机自启", isOn: launchAtLoginBinding)
                    .tint(UIPalette.accentBlue)
            }
            .padding(12)
        }
        .background(UIPalette.sidebar)
    }

    /// 列表行：显示名 + 默认徽标「默认」（逐字；徽标底与主按钮同渐变）。
    private func row(for model: ModelProfile) -> some View {
        HStack(spacing: 6) {
            Text(model.displayName)
                .foregroundColor(UIPalette.primaryText)
            if viewModel.defaultModelID == model.id {
                Text("默认")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(UIPalette.primaryGradient, in: Capsule())
            }
        }
    }

    // MARK: - 详情

    private var detail: some View {
        VStack(spacing: 0) {
            ProfileFormView(model: viewModel.form)
                .padding(20)
            Spacer(minLength: 0)
            Divider()
                .overlay(UIPalette.hairline)
            HStack {
                Spacer()
                Button("保 存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GradientPrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(UIPalette.windowCard)
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
