import Foundation

/// 提醒请求值对象:调度器(真/假)消费的统一形态
struct ReminderRequest: Equatable, Sendable {
    let daymarkID: UUID
    /// 本次提醒面向的发生日(重复事件为下一次)
    let occurrence: Date
    let fireDate: Date
    let title: String
    let body: String

    /// 标识 = 日标 id + 发生日派生(同数据重排幂等;同日标不同发生互不覆盖)
    var identifier: String {
        "\(daymarkID.uuidString)|\(Int(occurrence.timeIntervalSince1970))"
    }
}

/// 提醒规划(纯函数):输入日标事实集合,输出应存在的全部提醒请求
enum ReminderPlanning {
    /// 无具体时刻的日标使用的默认提醒时刻(票 08 起可由设置覆盖)
    static let defaultReminderHour = 9
    static let defaultReminderMinute = 0

    static func requests(from facts: [DaymarkReminderFacts],
                         reference: Date,
                         calendar: Calendar) -> [ReminderRequest] {
        facts.compactMap { fact in
            guard fact.remindDays > 0 else { return nil }

            let occurrence = DateMath.nextOccurrence(anchor: fact.anchor, repeat: fact.repeatCycle,
                                                     reference: reference, calendar: calendar)
            // 提醒时刻:有时刻的日标落在发生时刻;无时刻落在发生日默认时刻
            let reminderDate: Date
            if fact.hasTime {
                reminderDate = occurrence
            } else {
                var comps = calendar.dateComponents([.year, .month, .day], from: occurrence)
                comps.hour = defaultReminderHour
                comps.minute = defaultReminderMinute
                guard let at = calendar.date(from: comps) else { return nil }
                reminderDate = at
            }

            // 触发日 = 发生日 - N 天;已过触发点不再排
            guard let fireDate = calendar.date(byAdding: .day, value: -fact.remindDays, to: reminderDate),
                  fireDate > reference else { return nil }

            let daysLeft = DateMath.daysUntil(occurrence, from: fireDate, in: calendar)
            return ReminderRequest(
                daymarkID: fact.id,
                occurrence: occurrence,
                fireDate: fireDate,
                title: fact.name,
                body: String(localized: "reminder.body \(daysLeft)")
            )
        }
    }
}

/// 日标中与提醒相关的不可变事实切片(规划输入,与 @Model 解耦)
struct DaymarkReminderFacts: Equatable, Sendable {
    let id: UUID
    let name: String
    let anchor: Date
    let hasTime: Bool
    let repeatCycle: RepeatCycle
    let remindDays: Int
}
