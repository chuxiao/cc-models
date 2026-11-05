import Foundation
import Testing
@testable import ccmodel

/// SettingsWriter 对 settings.json 的 env 块替换语义、失败不变性、创建路径与读取（Task 3 验收标准对应）。
struct SettingsWriterTests {

    // MARK: - 测试设施

    /// 在唯一临时目录中执行（落盘测试用），结束即清理，绝不触碰真实 ~/.claude。
    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccmodel-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func writeSettings(_ directory: URL, _ json: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("settings.json"))
    }

    private func settingsData(in directory: URL) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent("settings.json"))
    }

    private func parsedSettings(in directory: URL) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: settingsData(in: directory))
        return try #require(object as? [String: Any])
    }

    private func envDictionary(in directory: URL) throws -> [String: String] {
        let env = try #require(parsedSettings(in: directory)["env"] as? [String: Any])
        var result: [String: String] = [:]
        for (key, value) in env {
            result[key] = try #require(value as? String)
        }
        return result
    }

    private func posixPermissions(of path: String) throws -> Int? {
        (try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? NSNumber)?.intValue
    }

    // MARK: - 替换：保留语义

    @Test func replaceKeepsNonPrefixedEnvKeysAndOtherTopLevelFields() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(
                dir,
                """
                {
                  "env": {"DISABLE_AUTOUPDATER": "1", "ANTHROPIC_BASE_URL": "a"},
                  "model": "opus",
                  "permissions": {"allow": ["Bash(ls:*)"]}
                }
                """
            )

            try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b", "ANTHROPIC_MODEL": "m"])

            #expect(try envDictionary(in: dir) == ["DISABLE_AUTOUPDATER": "1", "ANTHROPIC_BASE_URL": "b", "ANTHROPIC_MODEL": "m"])
            #expect(try parsedSettings(in: dir)["model"] as? String == "opus")
            let permissions = try #require(parsedSettings(in: dir)["permissions"] as? [String: Any])
            #expect(permissions["allow"] as? [String] == ["Bash(ls:*)"])
        }
    }

    @Test func replaceRemovesAnthropicKeysAbsentFromNewEnv() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(
                dir,
                """
                {"env": {"ANTHROPIC_BASE_URL": "a", "ANTHROPIC_AUTH_TOKEN": "t1", "ANTHROPIC_MODEL": "old", "CLAUDE_CODE_MAX_TOKENS": "8"}}
                """
            )

            try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])

            #expect(try envDictionary(in: dir) == ["ANTHROPIC_BASE_URL": "b", "CLAUDE_CODE_MAX_TOKENS": "8"])
        }
    }

    @Test func replaceWithEmptyEnvStripsAllAnthropicKeysKeepingRest() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(
                dir,
                """
                {"env": {"ANTHROPIC_BASE_URL": "a", "OTHER": "keep"}, "model": "sonnet"}
                """
            )

            try writer.replaceAnthropicEnv(with: [:])

            #expect(try envDictionary(in: dir) == ["OTHER": "keep"])
            #expect(try parsedSettings(in: dir)["model"] as? String == "sonnet")
        }
    }

    @Test func replaceCreatesEnvBlockWhenMissingWhileKeepingOtherFields() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(dir, #"{"model": "opus"}"#)

            try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])

            #expect(try envDictionary(in: dir) == ["ANTHROPIC_BASE_URL": "b"])
            #expect(try parsedSettings(in: dir)["model"] as? String == "opus")
        }
    }

    @Test func replaceRoundtripsThroughReadEnv() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(
                dir,
                """
                {"env": {"DISABLE_AUTOUPDATER": "1", "ANTHROPIC_BASE_URL": "a"}}
                """
            )

            let newEnv = ["ANTHROPIC_BASE_URL": "b", "ANTHROPIC_MODEL": "m"]
            try writer.replaceAnthropicEnv(with: newEnv)

            #expect(try writer.readEnv() == newEnv)
        }
    }

    // MARK: - 创建路径

    @Test func replaceCreatesMissingSettingsFileWithEnvOnly() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)

            try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])

            #expect(try envDictionary(in: dir) == ["ANTHROPIC_BASE_URL": "b"])
            #expect(try parsedSettings(in: dir).count == 1)
            #expect(try posixPermissions(of: dir.appendingPathComponent("settings.json").path) == 0o600)
        }
    }

    @Test func replaceCreatesMissingDirectoryWith0700Permissions() throws {
        try withTemporaryDirectory { base in
            let nested = base.appendingPathComponent("claude", isDirectory: true)
            let writer = SettingsWriter(directory: nested)

            try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])

            #expect(try posixPermissions(of: nested.path) == 0o700)
            #expect(try envDictionary(in: nested) == ["ANTHROPIC_BASE_URL": "b"])
        }
    }

    // MARK: - 失败不变性：损坏 JSON

    @Test func replaceWithCorruptJSONThrowsAndKeepsBytesUnchanged() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(dir, #"{"env": {"ANTHROPIC_BASE_URL": "a"}, "model": "#)
            let originalBytes = try settingsData(in: dir)

            #expect(throws: SettingsWriter.SettingsWriterError.invalidJSON) {
                try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])
            }
            #expect(try settingsData(in: dir) == originalBytes)
        }
    }

    @Test func replaceWithTopLevelNonObjectJSONThrowsAndKeepsBytesUnchanged() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(dir, #"[1, 2, 3]"#)
            let originalBytes = try settingsData(in: dir)

            #expect(throws: SettingsWriter.SettingsWriterError.invalidJSON) {
                try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])
            }
            #expect(try settingsData(in: dir) == originalBytes)
        }
    }

    // MARK: - 失败不变性：写失败

    /// 构造一：settings.json 被同名目录占位 → 抛错，目标保持目录原样不被破坏。
    @Test func replaceWhenSettingsFileIsADirectoryThrowsAndKeepsTargetIntact() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            let placeholder = dir.appendingPathComponent("settings.json", isDirectory: true)
            try FileManager.default.createDirectory(at: placeholder, withIntermediateDirectories: true)

            #expect(throws: Error.self) {
                try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])
            }
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: placeholder.path, isDirectory: &isDirectory)
            #expect(isDirectory.boolValue)
        }
    }

    /// 构造二：settings.json 存在但所在目录无写权限（0555）→ 创建临时文件失败 →
    /// 抛错且原文件字节与调用前完全一致（解析成功、写入失败的完整链路）。
    @Test func replaceWhenDirectoryNotWritableThrowsAndKeepsBytesUnchanged() throws {
        guard getuid() != 0 else {
            Issue.record("以 root 运行时 0555 权限构造无效，本测试不可判定")
            return
        }
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(dir, #"{"env": {"ANTHROPIC_BASE_URL": "a"}, "model": "opus"}"#)
            let originalBytes = try settingsData(in: dir)
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)
            defer {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            }

            #expect(throws: Error.self) {
                try writer.replaceAnthropicEnv(with: ["ANTHROPIC_BASE_URL": "b"])
            }
            #expect(try settingsData(in: dir) == originalBytes)
        }
    }

    // MARK: - 读取

    @Test func settingsURLPointsAtSettingsJSONInInjectedDirectory() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            #expect(writer.settingsURL == dir.appendingPathComponent("settings.json"))
        }
    }

    @Test func readEnvWithMissingFileReturnsEmpty() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            let env = try writer.readEnv()
            #expect(env == [String: String]())
        }
    }

    @Test func readEnvReturnsOnlyAnthropicPrefixedKeys() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(
                dir,
                """
                {"env": {"ANTHROPIC_BASE_URL": "a", "PATH": "/usr/bin", "DISABLE_AUTOUPDATER": "1"}}
                """
            )

            #expect(try writer.readEnv() == ["ANTHROPIC_BASE_URL": "a"])
        }
    }

    @Test func readEnvIgnoresNonStringValuesAndNonDictionaryEnv() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(dir, #"{"env": {"ANTHROPIC_MAX_TOKENS": 64, "ANTHROPIC_BASE_URL": "a"}}"#)
            #expect(try writer.readEnv() == ["ANTHROPIC_BASE_URL": "a"])

            try writeSettings(dir, #"{"env": "oops"}"#)
            #expect(try writer.readEnv() == [:])
        }
    }

    @Test func readEnvWithCorruptJSONThrows() throws {
        try withTemporaryDirectory { dir in
            let writer = SettingsWriter(directory: dir)
            try writeSettings(dir, "{ not json")

            #expect(throws: SettingsWriter.SettingsWriterError.invalidJSON) {
                try writer.readEnv()
            }
        }
    }
}
