import Foundation

/// 重复周期:不重复/每周/每月/每年(领域词:Repeat Cycle)
enum RepeatCycle: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }
}
