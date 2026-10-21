import Foundation

/// 重复周期:不重复/每周/每月/每年(领域词:Repeat Cycle)
enum RepeatCycle: String, Codable, CaseIterable, Sendable, Identifiable {
    case none
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    /// 本地化文案 key(选择器/详情展示用)
    var labelKey: String {
        switch self {
        case .none: return "repeat.none"
        case .weekly: return "repeat.weekly"
        case .monthly: return "repeat.monthly"
        case .yearly: return "repeat.yearly"
        }
    }
}
