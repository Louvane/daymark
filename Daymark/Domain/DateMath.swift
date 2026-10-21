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

    /// 下一次发生日:重复 Daymark 滚动到 ≥ 参考日的第一场(含当天);
    /// 每月/每年始终从原锚日推 k 个周期,避免夹钳漂移。
    static func nextOccurrence(anchor: Date, repeat: RepeatCycle,
                               reference: Date, calendar: Calendar) -> Date {
        switch `repeat` {
        case .none:
            return anchor
        case .weekly, .monthly, .yearly:
            break
        }

        let referenceDay = calendar.startOfDay(for: reference)
        // 参考日恰好是发生日当天 → 今天就是发生日
        if calendar.isDate(anchor, inSameDayAs: referenceDay) { return anchor }

        // k = 1, 2, 3… 从原锚日推周期,第一个 ≥ 今天的即下一次发生
        for k in 1...12_000 {
            guard let candidate = step(anchor, by: `repeat`, units: k, calendar: calendar) else { continue }
            if calendar.startOfDay(for: candidate) >= referenceDay {
                return candidate
            }
        }
        return anchor // 防御:理论不可达
    }

    /// 锚日推 k 个周期;月末/闰日夹钳规则在此定义
    private static func step(_ anchor: Date, by cycle: RepeatCycle, units: Int,
                             calendar: Calendar) -> Date? {
        switch cycle {
        case .none:
            return anchor
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * units, to: anchor)
        case .monthly:
            return date(byAddingMonths: units, to: anchor, calendar: calendar)
        case .yearly:
            return date(byAddingYears: units, to: anchor, calendar: calendar)
        }
    }

    /// 加 k 个月:日超出目标月长度时夹钳到月末(1/31 + 1月 → 2/28,而非溢出到 3 月)
    static func date(byAddingMonths months: Int, to date: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let monthIndex = (comps.year! * 12 + comps.month! - 1) + months
        comps.year = monthIndex / 12
        comps.month = monthIndex % 12 + 1
        guard let firstOfMonth = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)),
              let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count else { return nil }
        comps.day = min(comps.day!, daysInMonth)
        return calendar.date(from: comps)
    }

    /// 加 k 年:锚日 2/29 在平年定义为 3/1(测试钉死)
    static func date(byAddingYears years: Int, to date: Date, calendar: Calendar) -> Date? {
        var comps = calendar.dateComponents([.month, .day, .hour, .minute, .second], from: date)
        let year = calendar.component(.year, from: date) + years
        if comps.month == 2 && comps.day == 29 {
            let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            if !isLeap {
                comps.month = 3
                comps.day = 1
            }
        }
        comps.year = year
        return calendar.date(from: comps)
    }
}
