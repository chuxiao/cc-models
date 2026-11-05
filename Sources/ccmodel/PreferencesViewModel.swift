import Foundation
import Combine

/// 偏好窗口模型（Task 7）：侧栏列表（添加顺序稳定）、选中模型表单、增删改语义
/// 与登录项开关。落库编排在此完成——校验名单「除被编辑模型自身外」、默认唯一
/// （勾选覆盖旧默认 / 取消勾选回落 models 首个）、编辑生效中模型立即应用
/// （applyEnv + 成功通知）；删除当前生效模型只删记录不写 env（漂移交 F3 流程）。
final class PreferencesViewModel: ObservableObject {

    enum PreferencesError: Error, Equatable {
        /// 只剩一个模型时调用 deleteSelected（UI 置灰之外的兜底）。
        case cannotDeleteLastModel
        /// 无选中模型时调用 deleteSelected（新建态或空列表）。
        case noModelSelected
        /// saveForm 时被编辑模型已不在 store 中（防御性，正常不可达）。
        case modelNotFound
        /// saveForm 校验失败；关联值为逐字段错误数组，store 不变。
        case validation([ProfileFields.ValidationError])
    }

    // MARK: - 可观察状态

    /// 侧栏列表：按添加顺序稳定展示，不受菜单重排影响。
    @Published var modelList: [ModelProfile] = []
    /// 侧栏选中；nil 表示新建态（beginAdd 之后、保存之前）。
    @Published var selectedID: UUID?
    /// 详情表单；随选中或新建态整体替换。
    @Published var form = ProfileFormModel()
    /// 开关初值取 store 持久事实，不读 LoginItem.isEnabled（控制者裁定）。
    @Published var launchAtLogin = false
    /// 最近一次操作的失败提示（登录项失败、落盘失败）；nil 表示无待提示，
    /// 视图据此呈现说明框。
    @Published var alertMessage: String?

    private let store: ModelStore
    private let switcher: ModelSwitcher

    init(store: ModelStore, switcher: ModelSwitcher) {
        self.store = store
        self.switcher = switcher
        reload()
    }

    // MARK: - 派生状态

    /// 至少两个模型才可删除（对应 － 按钮置灰，设计 §2 F4）。
    var canDelete: Bool { store.canDelete }

    /// 当前默认模型 id（侧栏行内「默认」徽标）。
    var defaultModelID: UUID? { store.configuration.defaultModelID }

    // MARK: - 同步

    /// 从 store 重新同步列表、开关与选中表单（窗口重开或落库事实变化后调用）；
    /// 挂起的表单编辑被落库事实覆盖，选中失效时回落首个。
    func reload() {
        modelList = store.configuration.models
        launchAtLogin = store.launchAtLogin
        if let id = selectedID, modelList.contains(where: { $0.id == id }) {
            loadForm(for: id)
        } else {
            selectedID = modelList.first?.id
            if let id = selectedID {
                loadForm(for: id)
            } else {
                form = ProfileFormModel()
            }
        }
    }

    /// 选中模型并载入其表单（默认标记按配置事实）；id 不存在时忽略。
    func select(id: UUID) {
        guard store.configuration.models.contains(where: { $0.id == id }) else { return }
        selectedID = id
        loadForm(for: id)
    }

    /// 进入新建态：表单清空、取消选中；保存成功才追加到列表尾并选中，
    /// 不自动成为当前、不自动默认（除非勾选）。
    func beginAdd() {
        selectedID = nil
        form = ProfileFormModel()
    }

    // MARK: - 删除

    /// 删除选中模型并持久化。canDelete 为 false 或无选中 → 抛错；
    /// 删除默认模型由首个补位（Task 2 语义）；删除当前生效模型只删记录不写 env。
    /// 落盘失败回滚内存态后原样抛出。
    func deleteSelected() throws {
        guard canDelete else { throw PreferencesError.cannotDeleteLastModel }
        guard let id = selectedID else { throw PreferencesError.noModelSelected }
        try store.delete(id: id)
        do {
            try store.save()
        } catch {
            rollbackAndReload()
            throw error
        }
        reload()
    }

    // MARK: - 保存

    /// 保存表单（新建或编辑）。
    /// 校验名单为「除被编辑模型自身外」的全部显示名；校验失败 → 写入
    /// `form.validationErrors` 行内提示并抛出错误数组，store 不变。
    /// 通过 → 新模型 `add`（isDefault=true 则 `setDefault`）/ 已有模型 `update`；
    /// 默认唯一：勾选默认覆盖旧默认；取消勾选且原是默认 → defaultModelID 回落
    /// models 首个（首个即自身时保持不变）。被编辑模型为当前生效模型 → 追加
    /// `applyEnv`（成功通知由 switcher 发出）；不是当前 → 不写 env。
    /// 落盘失败回滚内存态后原样抛出。
    func saveForm() throws {
        if let id = selectedID {
            try saveExisting(id: id)
        } else {
            try saveNew()
        }
    }

    // MARK: - 开机自启

    /// 开启/关闭登录项并持久化。先乐观更新开关；`LoginItem` 抛错 → 回拨开关
    /// （true 失败回 false，false 失败回 true）、store 不变并给出界面提示；
    /// 成功后写 store 持久事实并落盘（落盘失败回滚内存态，开关随持久事实复位）。
    func setLaunchAtLogin(_ on: Bool) {
        launchAtLogin = on
        do {
            try LoginItem.setEnabled(on)
        } catch {
            launchAtLogin = !on
            alertMessage = "开机自启设置失败：\(error.localizedDescription)"
            return
        }
        store.setLaunchAtLogin(on)
        do {
            try store.save()
        } catch {
            try? store.load()
            launchAtLogin = store.launchAtLogin
            alertMessage = "开机自启状态保存失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 私有：保存路径

    /// 新建：追加到列表尾，勾选默认则设默认；新模型不可能是当前生效模型，不写 env。
    private func saveNew() throws {
        let errors = form.validate(
            existingNames: store.configuration.models.map(\.displayName)
        )
        guard errors.isEmpty else {
            form.validationErrors = errors
            throw PreferencesError.validation(errors)
        }
        let profile = form.makeProfile(original: nil)
        store.add(profile)
        do {
            if form.isDefault {
                try store.setDefault(id: profile.id)
            }
            try store.save()
        } catch {
            rollbackAndReload()
            throw error
        }
        selectedID = profile.id
        reload()
    }

    /// 编辑既有模型；当前生效判定先于任何 store 变更——update 之后旧 env 不再命中。
    private func saveExisting(id: UUID) throws {
        guard let original = store.configuration.models.first(where: { $0.id == id }) else {
            throw PreferencesError.modelNotFound
        }
        let wasCurrent = switcher.currentModelID() == id
        // 校验名单：除被编辑模型自身外的全部显示名（编辑不改名保存不误报重名）
        let names = store.configuration.models
            .filter { $0.id != id }
            .map(\.displayName)
        let errors = form.validate(existingNames: names)
        guard errors.isEmpty else {
            form.validationErrors = errors
            throw PreferencesError.validation(errors)
        }
        let profile = form.makeProfile(original: original)
        let wasDefault = store.configuration.defaultModelID == id
        do {
            try store.update(profile) // 存在性已由上方 guard 验证，实际不可达
            if form.isDefault {
                try store.setDefault(id: id)
            } else if wasDefault, let first = store.configuration.models.first {
                try store.setDefault(id: first.id)
            }
            if wasCurrent {
                try switcher.applyEnv(profile.env)
            }
            try store.save()
        } catch {
            rollbackAndReload()
            throw error
        }
        reload()
    }

    /// 落盘失败回滚：内存态恢复到最近持久事实并重新同步视图状态。
    private func rollbackAndReload() {
        try? store.load()
        reload()
    }

    /// 以落库事实整体替换表单（挂起编辑丢弃、校验错误清空）。
    private func loadForm(for id: UUID) {
        guard let model = store.configuration.models.first(where: { $0.id == id }) else { return }
        form = ProfileFormModel(
            profile: model,
            isDefault: store.configuration.defaultModelID == id
        )
    }
}
