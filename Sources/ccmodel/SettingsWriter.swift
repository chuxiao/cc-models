import Foundation

/// 对外部接口 `~/.claude/settings.json` 的 env 块替换引擎（Task 3），
/// 是切换、覆盖、编辑应用、首跑四条链路的唯一写入点。
///
/// 失败不变性是生命线：任何抛错路径下，settings.json 的字节内容与调用前完全一致。
/// 写入采用「0600 临时文件 → POSIX rename 原子替换」：临时文件从诞生起就是 0600，
/// 所有可抛错步骤都发生在替换之前，rename 失败时原文件不动。
struct SettingsWriter {

    enum SettingsWriterError: Error, Equatable {
        /// 文件存在但内容不是合法 JSON，或顶层不是 JSON 对象。
        case invalidJSON
    }

    private static let anthropicPrefix = "ANTHROPIC_"

    private let directory: URL

    /// settings.json 的完整路径。
    var settingsURL: URL {
        directory.appendingPathComponent("settings.json", isDirectory: false)
    }

    /// `directory` 为 nil 时使用默认目录 `~/.claude`；测试一律注入临时目录，绝不读写真实配置。
    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            self.directory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude", isDirectory: true)
        }
    }

    // MARK: - 读取

    /// 返回 env 块中 `ANTHROPIC_` 前缀的字符串键值；文件缺失 → `[:]`。
    /// 非前缀键、非字符串值、env 块缺失或不是对象均不进入结果；JSON 损坏 → 抛错。
    func readEnv() throws -> [String: String] {
        guard let root = try readRootObject() else { return [:] }
        guard let env = root["env"] as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in env where key.hasPrefix(Self.anthropicPrefix) {
            if let stringValue = value as? String {
                result[key] = stringValue
            }
        }
        return result
    }

    // MARK: - 替换

    /// 将 env 块中全部 `ANTHROPIC_` 前缀键替换为 `env`；env 中的非前缀键与
    /// 全部其他顶层字段原值保留（键序与缩进不保证保留，内容级保留）。
    /// env 块缺失视为空；文件缺失则创建（目录缺失先创建，0700；文件 0600）。
    func replaceAnthropicEnv(with env: [String: String]) throws {
        var root = try readRootObject() ?? [:]
        var envBlock = ((root["env"] as? [String: Any]) ?? [:])
            .filter { !$0.key.hasPrefix(Self.anthropicPrefix) }
        for (key, value) in env {
            envBlock[key] = value
        }
        root["env"] = envBlock

        try writeAtomically(JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ))
    }

    // MARK: - 写入（失败不变性）

    /// 同目录临时文件 + rename 原子替换。目录无条件收紧到 0700；临时文件以
    /// 0600 诞生（先建空文件再截断写入，无「先 0644 后 chmod」的凭据暴露窗口）；
    /// rename 之外的一切可抛错步骤先于替换，任一失败即抛错并清理临时文件，
    /// 原文件字节不变。
    private func writeAtomically(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
        let temporaryURL = directory.appendingPathComponent(
            ".settings.json.tmp-\(UUID().uuidString)", isDirectory: false
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        guard FileManager.default.createFile(
            atPath: temporaryURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try data.write(to: temporaryURL)
        guard rename(temporaryURL.path, settingsURL.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    /// 读取并解析 settings.json 顶层对象；文件缺失 → nil。
    /// 内容不是合法 JSON 或顶层不是 JSON 对象 → `invalidJSON`（只读，文件字节不变）。
    private func readRootObject() throws -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return nil }
        let data = try Data(contentsOf: settingsURL)
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any] else {
            throw SettingsWriterError.invalidJSON
        }
        return root
    }
}
