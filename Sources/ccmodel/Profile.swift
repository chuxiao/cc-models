import Foundation

/// 一个模型配置档：显示名、捕获的 env 快照与最后选中时间。
struct ModelProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var env: [String: String]
    var lastSelectedAt: Date?
}
