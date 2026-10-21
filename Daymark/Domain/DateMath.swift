import Foundation

/// 纯函数日历运算集(领域接缝 1)。全部显式接收 Calendar,测试用固定日历钉死行为。
enum DateMath {
    /// 用户当前时区的 Gregorian 日历(运行时入口)
    static func userCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// 当天 00:00
    static func startOfDay(_ date: Date, in calendar: Calendar) -> Date {
        calendar.startOfDay(for: date)
    }

    /// 两日期按自然日相差天数:to 在后为正,同一天(不论时刻)为 0
    static func daysBetween(_ from: Date, _ to: Date, in calendar: Calendar) -> Int {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: from),
            to: calendar.startOfDay(for: to)
        ).day ?? 0
        return days
    }

    /// 距目标日还有几天(目标在过去为负)
    static func daysUntil(_ target: Date, from reference: Date, in calendar: Calendar) -> Int {
        daysBetween(reference, target, in: calendar)
    }

    /// 距过去某日已过几天(未来为负)
    static func daysSince(_ past: Date, until reference: Date, in calendar: Calendar) -> Int {
        daysBetween(past, reference, in: calendar)
    }
}
