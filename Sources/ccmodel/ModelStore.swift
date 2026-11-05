import Foundation

/// 应用自有配置：模型列表、默认标记、开机自启与已忽略的自定义 env。
struct AppConfiguration: Codable, Equatable {
    var models: [ModelProfile] = []
    var defaultModelID: UUID?
    var launchAtLogin = false
    var dismissedCustomEnvs: [[String: String]] = []
}

/// 菜单排序的唯一实现（Task 4 复用，防漂移）：
/// 有 `lastSelectedAt` 的按时间降序在前；无历史的保持添加顺序排在其后。
enum ModelSort {
    static func ordered(_ models: [ModelProfile]) -> [ModelProfile] {
        let indexed = models.enumerated().map { (offset: $0.offset, model: $0.element) }
        let dated = indexed
            .filter { $0.model.lastSelectedAt != nil }
            .sorted { lhs, rhs in
                let lhsDate = lhs.model.lastSelectedAt ?? .distantPast
                let rhsDate = rhs.model.lastSelectedAt ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return lhs.offset < rhs.offset
            }
        let undated = indexed.filter { $0.model.lastSelectedAt == nil }
        return (dated + undated).map(\.model)
    }
}

/// 应用自有配置的持久化与 CRUD、排序、已忽略 env 状态管理。
/// 存储于 `config.json`（文件 0600、目录 0700）；
/// 默认目录 `~/Library/Application Support/cc-model`，测试注入临时目录。
final class ModelStore {
    enum ModelStoreError: Error, Equatable {
        /// setDefault/update/markSelected/delete 传入不存在的模型 id。
        case modelNotFound
        /// delete 将使模型列表为空（UI 置灰守卫之外的兜底）。
        case cannotDeleteLastModel
    }

    private let directory: URL
    private var fileURL: URL { directory.appendingPathComponent("config.json", isDirectory: false) }

    private(set) var configuration = AppConfiguration()

    /// `directory` 为 nil 时使用默认应用支持目录；注入时由调用方负责目录的隔离。
    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = appSupport.appendingPathComponent("cc-model", isDirectory: true)
        }
    }

    // MARK: - 持久化

    /// 读取配置。文件缺失 → configuration 重置为默认空配置，不抛错；
    /// JSON 损坏 → 抛错，且 configuration 保持载入前的值。
    func load() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            configuration = AppConfiguration()
            return
        }
        let data = try Data(contentsOf: fileURL)
        configuration = try JSONDecoder().decode(AppConfiguration.self, from: data)
    }

    /// 写入配置。目录不存在则创建（0700）；写后文件权限 0600。
    func save() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    // MARK: - CRUD

    /// 追加模型（列表保持添加顺序）。默认标记为纯标记，add 不改动它。
    func add(_ model: ModelProfile) {
        configuration.models.append(model)
    }

    /// 以同 id 整体替换模型（含 env 全键组）；id 不存在 → 抛错。
    func update(_ model: ModelProfile) throws {
        guard let index = indexOfModel(model.id) else { throw ModelStoreError.modelNotFound }
        configuration.models[index] = model
    }

    /// 删除模型；id 不存在 → `modelNotFound`；删除将使列表为空 → `cannotDeleteLastModel`。
    /// 删除默认模型时由首个剩余模型补位为默认；删除非默认模型时默认标记不变。
    func delete(id: UUID) throws {
        guard let index = indexOfModel(id) else { throw ModelStoreError.modelNotFound }
        guard configuration.models.count > 1 else { throw ModelStoreError.cannotDeleteLastModel }
        let wasDefault = configuration.defaultModelID == id
        configuration.models.remove(at: index)
        if wasDefault {
            configuration.defaultModelID = configuration.models.first?.id
        }
    }

    /// 设默认；id 不存在 → 抛错。
    func setDefault(id: UUID) throws {
        guard indexOfModel(id) != nil else { throw ModelStoreError.modelNotFound }
        configuration.defaultModelID = id
    }

    /// 记录选中时间；id 不存在 → 抛错。只改内存，由调用方 save。
    func markSelected(id: UUID) throws {
        guard let index = indexOfModel(id) else { throw ModelStoreError.modelNotFound }
        configuration.models[index].lastSelectedAt = Date()
    }

    // MARK: - 已忽略的自定义 env

    /// 记录一条被忽略的自定义 env（只保留 `ANTHROPIC_` 前缀键，与 `isDismissedEnv` 对齐）。
    func recordDismissedEnv(_ env: [String: String]) {
        configuration.dismissedCustomEnvs.append(ProfileFields.capture(fromEnv: env))
    }

    /// 入参经 `ProfileFields.capture` 过滤后与任一已忽略 env 完全相等 → true。
    func isDismissedEnv(_ env: [String: String]) -> Bool {
        let captured = ProfileFields.capture(fromEnv: env)
        return configuration.dismissedCustomEnvs.contains(captured)
    }

    // MARK: - 派生状态

    /// 至少两个模型才可删除（UI 置灰守卫）。
    var canDelete: Bool { configuration.models.count >= 2 }

    /// 菜单顺序：最近选择在前，无历史的保持添加顺序（委托 `ModelSort.ordered`）。
    func menuOrderedModels() -> [ModelProfile] {
        ModelSort.ordered(configuration.models)
    }

    private func indexOfModel(_ id: UUID) -> Int? {
        configuration.models.firstIndex { $0.id == id }
    }
}
