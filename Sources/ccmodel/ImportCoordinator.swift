import Foundation

/// 导入弹窗的三出口决策（Task 8）：弹窗层产出，落库由 `ImportCoordinator.decide` 消费。
enum ImportDecision: Equatable {
    /// 将当前 env 捕获为指定显示名的新模型。
    case newModel(name: String)
    /// 将指定模型的 env 整体替换为当前捕获的 env。
    case overwrite(targetID: UUID)
    /// 忽略该自定义配置（记录已询问）。
    case cancel
}

/// 导入落库编排（Task 8）：把弹窗决策落到 store 与 settings。纳入与覆盖两条正路径
/// 都经 `ModelSwitcher.switchTo` 落库并成为当前（settings 写入 → lastSelectedAt →
/// save → 通知），取消经 `ModelStore.recordDismissedEnv` 记录已询问。
enum ImportCoordinator {

    /// 空值兜底错误：`capture(env)` 为空（settings.json 读取失败或无 env 块的空 env）
    /// 时 newModel/overwrite 均抛此错，不入库、不写 settings（cancel 不在此路径）。
    enum ImportError: Error, Equatable {
        case emptyEnv
    }

    /// 执行导入决策。纯编排：不呈现 UI。任何抛错路径下 store 内存态回滚到磁盘基线
    /// （与 FirstRunCoordinator 的落盘失败回滚同模式），settings.json 字节由
    /// switchTo 的失败不变性保证与调用前一致。
    static func decide(
        _ decision: ImportDecision,
        env: [String: String],
        store: ModelStore,
        switcher: ModelSwitcher
    ) throws {
        switch decision {
        case .newModel(let name):
            try addNewModel(name: name, env: env, store: store, switcher: switcher)
        case .overwrite(let targetID):
            try overwriteTarget(id: targetID, env: env, store: store, switcher: switcher)
        case .cancel:
            // 记录已询问（存储前经 capture 过滤，dismissed 判定为内容等价口径）
            // 并持久化；此后同 env 打开菜单不再触发弹窗，env 变化后重新询问。
            store.recordDismissedEnv(env)
            try store.save()
        }
    }

    // MARK: - 纳入新模型

    private static func addNewModel(
        name: String,
        env: [String: String],
        store: ModelStore,
        switcher: ModelSwitcher
    ) throws {
        let captured = try captureOrThrow(env)
        // 显示名与重名校验同 §2 F5 表单规则（去空白后比较）；弹窗层已拦截，此处兜底。
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw ProfileFields.ValidationError.emptyDisplayName }
        let isDuplicate = store.configuration.models.contains {
            $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedName
        }
        guard !isDuplicate else { throw ProfileFields.ValidationError.duplicateDisplayName }

        let profile = ModelProfile(id: UUID(), displayName: trimmedName, env: captured, lastSelectedAt: nil)
        store.add(profile)
        // 经 switchTo 落库（settings 写入 + lastSelectedAt + save + 通知）并成为当前；
        // 失败 → 内存态回滚到磁盘基线后原样抛出（此刻尚未 save，磁盘本无新模型）。
        do {
            try switcher.switchTo(id: profile.id)
        } catch {
            try? store.load()
            throw error
        }
    }

    // MARK: - 覆盖已有模型

    private static func overwriteTarget(
        id: UUID,
        env: [String: String],
        store: ModelStore,
        switcher: ModelSwitcher
    ) throws {
        let captured = try captureOrThrow(env)
        guard var profile = store.configuration.models.first(where: { $0.id == id }) else {
            throw ModelStore.ModelStoreError.modelNotFound
        }
        // 目标 env 整体替换（键集合也换）；displayName 与 defaultModelID 保持，
        // lastSelectedAt 经 switchTo 更新，覆盖后成为当前。重名校验不适用此路径。
        profile.env = captured
        try store.update(profile)
        do {
            try switcher.switchTo(id: id)
        } catch {
            try? store.load()
            throw error
        }
    }

    /// 空值兜底：捕获后的 env 为空 → 抛错，调用方不触达 store 与 settings。
    private static func captureOrThrow(_ env: [String: String]) throws -> [String: String] {
        let captured = ProfileFields.capture(fromEnv: env)
        if captured.isEmpty { throw ImportError.emptyEnv }
        return captured
    }
}
