import Foundation
import SwiftData

/// Daymark(日标):用户的一条重要日期记录。字段对齐 spec,同步字段刻意没有(ADR-0003)。
@Model
final class Daymark {
    var id: UUID
    /// 名称(必填)
    var name: String
    /// Emoji(票 06 前为占位)
    var emoji: String
    /// 预设色板下标(票 06 前为 0)
    var colorIndex: Int
    /// 锚定日(区间 Daymark 为开始日,票 07)
    var startDate: Date
    /// 区间结束日,nil 为单日(票 07)
    var endDate: Date?
    /// 日期是否含具体时刻(票 07)
    var hasTime: Bool
    /// 重复周期原始值(SwiftData 存 raw string,规避枚举编码演进问题)
    private var repeatCycleRaw: String = RepeatCycle.none.rawValue
    /// 提前提醒天数,0 = 不提醒(票 05)
    var remindDays: Int
    /// 手动排序权重(票 06)
    var sortWeight: Double
    var createdAt: Date
    var updatedAt: Date

    var repeatCycle: RepeatCycle {
        get { RepeatCycle(rawValue: repeatCycleRaw) ?? .none }
        set { repeatCycleRaw = newValue.rawValue }
    }

    init(name: String,
         date: Date,
         emoji: String = "📌",
         colorIndex: Int = 0,
         endDate: Date? = nil,
         hasTime: Bool = false,
         repeatCycle: RepeatCycle = .none,
         remindDays: Int = 0,
         sortWeight: Double = 0) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.startDate = date
        self.endDate = endDate
        self.hasTime = hasTime
        self.repeatCycleRaw = repeatCycle.rawValue
        self.remindDays = remindDays
        self.sortWeight = sortWeight
        self.createdAt = .now
        self.updatedAt = .now
    }
}
