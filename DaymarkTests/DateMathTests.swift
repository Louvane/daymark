import XCTest
@testable import Daymark

/// DateMath 测试:固定日历(Gregorian + Asia/Shanghai,UTC+8 无夏令时)+ 固定参考日,
/// 不依赖运行机器时区。票 02:daysBetween 与状态判定。
final class DateMathTests: XCTestCase {
    // MARK: - 固定日历工具

    /// UTC+8、无夏令时,所有用例共用
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return cal
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int,
                     hour: Int = 9, minute: Int = 0,
                     calendar: Calendar = calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour, minute: minute))!
    }

    // MARK: - daysBetween(今天=0,未来为正,过去为负)

    func testDaysBetweenSameDayIsZero() {
        let cal = Self.calendar
        let a = Self.date(2026, 10, 21, hour: 0)
        let b = Self.date(2026, 10, 21, hour: 23, minute: 59)
        XCTAssertEqual(DateMath.daysBetween(a, b, in: cal), 0)
    }

    func testDaysAcrossMonth() {
        let cal = Self.calendar
        let from = Self.date(2026, 2, 28)
        let to = Self.date(2026, 3, 2)
        XCTAssertEqual(DateMath.daysBetween(from, to, in: cal), 2)
        XCTAssertEqual(DateMath.daysBetween(to, from, in: cal), -2)
    }

    func testDaysAcrossYear() {
        let cal = Self.calendar
        let from = Self.date(2025, 12, 31)
        let to = Self.date(2026, 1, 1)
        XCTAssertEqual(DateMath.daysBetween(from, to, in: cal), 1)
    }

    func testDaysAcrossLeapDay() {
        let cal = Self.calendar
        // 2024 是闰年:2/28 → 2/29 相差 1 天;2/29 → 2025/2/28 相差 365 天
        XCTAssertEqual(DateMath.daysBetween(Self.date(2024, 2, 28), Self.date(2024, 2, 29), in: cal), 1)
        XCTAssertEqual(DateMath.daysBetween(Self.date(2024, 2, 29), Self.date(2025, 2, 28), in: cal), 365)
        // 平年:2/28 → 3/1 相差 1 天
        XCTAssertEqual(DateMath.daysBetween(Self.date(2025, 2, 28), Self.date(2025, 3, 1), in: cal), 1)
    }

    // MARK: - 状态判定(非重复:过去/未来/今天)

    func testStateUpcoming() {
        let cal = Self.calendar
        let reference = Self.date(2026, 10, 21)
        let anchor = Self.date(2026, 10, 25)
        let state = DaymarkStatus.state(anchor: anchor, repeat: .none,
                                        reference: reference, calendar: cal)
        XCTAssertEqual(state.phase, .upcoming(daysLeft: 4))
    }

    func testStateElapsed() {
        let cal = Self.calendar
        let reference = Self.date(2026, 10, 21)
        let anchor = Self.date(2026, 1, 1)
        let state = DaymarkStatus.state(anchor: anchor, repeat: .none,
                                        reference: reference, calendar: cal)
        XCTAssertEqual(state.phase, .elapsed(daysElapsed: 293))
    }

    func testStateTodayIgnoresTimeOfDay() {
        let cal = Self.calendar
        // 参考日 09:00,锚定日当天 23:30,仍判定"就是今天"
        let reference = Self.date(2026, 10, 21, hour: 9)
        let anchor = Self.date(2026, 10, 21, hour: 23, minute: 30)
        let state = DaymarkStatus.state(anchor: anchor, repeat: .none,
                                        reference: reference, calendar: cal)
        XCTAssertEqual(state.phase, .today)
        // 反过来:参考日在深夜,锚定日当天凌晨,同为今天
        let lateReference = Self.date(2026, 10, 21, hour: 23, minute: 59)
        let earlyAnchor = Self.date(2026, 10, 21, hour: 0, minute: 1)
        let state2 = DaymarkStatus.state(anchor: earlyAnchor, repeat: .none,
                                         reference: lateReference, calendar: cal)
        XCTAssertEqual(state2.phase, .today)
    }

    func testStateReturnsOccurrence() {
        let cal = Self.calendar
        let anchor = Self.date(2026, 10, 25, hour: 18)
        let state = DaymarkStatus.state(anchor: anchor, repeat: .none,
                                        reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(state.occurrence, anchor)
    }
}

// MARK: - 票 04:nextOccurrence 重复滚动

extension DateMathTests {
    func testNextOccurrenceNoneReturnsAnchor() {
        let cal = Self.calendar
        let anchor = Self.date(2020, 1, 1)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .none,
                                               reference: Self.date(2026, 10, 21), calendar: cal), anchor)
    }

    // 每周:+ 7 天
    func testNextOccurrenceWeekly() {
        let cal = Self.calendar
        // 参考日恰好是发生日当天 → 今天
        let today = Self.date(2026, 10, 21, hour: 18)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: today, repeat: .weekly,
                                               reference: Self.date(2026, 10, 21), calendar: cal), today)
        // 已过一周 → 下周三
        let lastWeek = Self.date(2026, 10, 14, hour: 18)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: lastWeek, repeat: .weekly,
                                               reference: Self.date(2026, 10, 21), calendar: cal),
                       Self.date(2026, 10, 21, hour: 18))
        // 昨天周三 → 下周三
        let yesterday = Self.date(2026, 10, 20, hour: 9)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: yesterday, repeat: .weekly,
                                               reference: Self.date(2026, 10, 21), calendar: cal),
                       Self.date(2026, 10, 27, hour: 9))
    }

    // 每月:月末夹钳,且不漂移(始终从原锚日推 k 个月)
    func testNextOccurrenceMonthlyEndOfMonth() {
        let cal = Self.calendar
        let anchor = Self.date(2025, 1, 31, hour: 10)
        // 平年二月夹钳到 2/28
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .monthly,
                                               reference: Self.date(2025, 2, 20), calendar: cal),
                       Self.date(2025, 2, 28, hour: 10))
        // 夹钳日当天 → 今天
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .monthly,
                                               reference: Self.date(2025, 2, 28), calendar: cal),
                       Self.date(2025, 2, 28, hour: 10))
        // 不漂移:下下次是 3/31,不是从 2/28 再加一个月的 3/28
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .monthly,
                                               reference: Self.date(2025, 3, 1), calendar: cal),
                       Self.date(2025, 3, 31, hour: 10))
        // 闰二月夹钳到 2/29
        let leapAnchor = Self.date(2024, 1, 31, hour: 8)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: leapAnchor, repeat: .monthly,
                                               reference: Self.date(2024, 2, 20), calendar: cal),
                       Self.date(2024, 2, 29, hour: 8))
    }

    // 每年:2/29 生日在平年钉死为 3/1;始终从原锚日推 k 年
    func testNextOccurrenceYearlyLeapDay() {
        let cal = Self.calendar
        let anchor = Self.date(2024, 2, 29, hour: 9)
        // 2025 平年 → 3/1
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .yearly,
                                               reference: Self.date(2024, 12, 31), calendar: cal),
                       Self.date(2025, 3, 1, hour: 9))
        // 3/1 当天 → 今天
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .yearly,
                                               reference: Self.date(2025, 3, 1), calendar: cal),
                       Self.date(2025, 3, 1, hour: 9))
        // 2026 平年 → 3/1(不因上一年夹钳而漂移到 3/2+)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .yearly,
                                               reference: Self.date(2025, 3, 2), calendar: cal),
                       Self.date(2026, 3, 1, hour: 9))
        // 2028 闰年回到真 2/29
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .yearly,
                                               reference: Self.date(2027, 6, 1), calendar: cal),
                       Self.date(2028, 2, 29, hour: 9))
    }

    // 每年:跨年滚动
    func testNextOccurrenceYearlyAcrossYear() {
        let cal = Self.calendar
        let anchor = Self.date(2025, 12, 31, hour: 23)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .yearly,
                                               reference: Self.date(2026, 6, 1), calendar: cal),
                       Self.date(2026, 12, 31, hour: 23))
    }

    // 回归(UI 快照实测发现):未来锚日 + 重复 → 不多滚一周期
    func testNextOccurrenceFutureAnchorStaysPut() {
        let cal = Self.calendar
        let anchor = Self.date(2026, 12, 24, hour: 9)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .yearly,
                                               reference: Self.date(2026, 10, 22), calendar: cal), anchor)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .weekly,
                                               reference: Self.date(2026, 10, 22), calendar: cal), anchor)
        XCTAssertEqual(DateMath.nextOccurrence(anchor: anchor, repeat: .monthly,
                                               reference: Self.date(2026, 10, 22), calendar: cal), anchor)
        let state = DaymarkStatus.state(anchor: anchor, repeat: .yearly,
                                        reference: Self.date(2026, 10, 22), calendar: cal)
        XCTAssertEqual(state.phase, .upcoming(daysLeft: 63))
    }

    // 集成:已过的重复 Daymark 显示「距下次还有 N 天」
    func testStateRepeatingPastShowsUpcoming() {
        let cal = Self.calendar
        let state = DaymarkStatus.state(anchor: Self.date(2026, 1, 1), repeat: .yearly,
                                        reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(state.phase, .upcoming(daysLeft: 72))
        XCTAssertEqual(state.occurrence, Self.date(2027, 1, 1))
        // 重复 Daymark 当天也判「就是今天」
        let todayState = DaymarkStatus.state(anchor: Self.date(2025, 10, 21), repeat: .yearly,
                                             reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(todayState.phase, .today)
    }
}

// MARK: - 票 07:日期区间与具体时刻

extension DateMathTests {
    // 区间状态:未开始/进行中/已结束
    func testRangeNotStarted() {
        let cal = Self.calendar
        let phase = DaymarkStatus.rangePhase(start: Self.date(2026, 11, 1), end: Self.date(2026, 11, 5),
                                             reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(phase, .notStarted(daysUntilStart: 11))
    }

    func testRangeInProgressDayAndTotal() {
        let cal = Self.calendar
        // 跨月区间 10/28–11/02,参考 10/30 → 第 3 天/共 6 天
        let phase = DaymarkStatus.rangePhase(start: Self.date(2026, 10, 28), end: Self.date(2026, 11, 2),
                                             reference: Self.date(2026, 10, 30), calendar: cal)
        XCTAssertEqual(phase, .inProgress(dayNumber: 3, totalDays: 6))
    }

    func testRangeStartsTodayIsDayOne() {
        let cal = Self.calendar
        // 当天开始 → 第 1 天
        let phase = DaymarkStatus.rangePhase(start: Self.date(2026, 10, 21), end: Self.date(2026, 10, 25),
                                             reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(phase, .inProgress(dayNumber: 1, totalDays: 5))
        // 当天结束 → 第 5 天
        let lastDay = DaymarkStatus.rangePhase(start: Self.date(2026, 10, 21), end: Self.date(2026, 10, 25),
                                               reference: Self.date(2026, 10, 25), calendar: cal)
        XCTAssertEqual(lastDay, .inProgress(dayNumber: 5, totalDays: 5))
    }

    func testRangeEnded() {
        let cal = Self.calendar
        let phase = DaymarkStatus.rangePhase(start: Self.date(2026, 10, 1), end: Self.date(2026, 10, 5),
                                             reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(phase, .ended(daysSinceEnd: 16))
    }

    func testSingleDayRangeToday() {
        let cal = Self.calendar
        // 单日区间当天:进行中第 1 天/共 1 天
        let phase = DaymarkStatus.rangePhase(start: Self.date(2026, 10, 21), end: Self.date(2026, 10, 21),
                                             reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(phase, .inProgress(dayNumber: 1, totalDays: 1))
    }

    // 区间 + 重复:仅按开始日滚动,区间长度不变
    func testRepeatingRangeShiftsIntact() {
        let cal = Self.calendar
        // 每年区间 2024/3/1–3/5,参考 2026/10/21 → 下次 2027/3/1–3/5
        let state = DaymarkStatus.state(anchor: Self.date(2024, 3, 1), end: Self.date(2024, 3, 5),
                                        repeat: .yearly, reference: Self.date(2026, 10, 21), calendar: cal)
        XCTAssertEqual(state.phase, .range(.notStarted(daysUntilStart: 131)))

        // 长度不变:滚动后的结束日 = 2027/3/5
        if case .range = state.phase {} else { XCTFail("应为 range phase") }
        let end = cal.date(byAdding: .day, value: 4, to: state.occurrence)
        XCTAssertEqual(end, Self.date(2027, 3, 5))
    }

    func testRangeInProgressState() {
        let cal = Self.calendar
        let state = DaymarkStatus.state(anchor: Self.date(2026, 10, 28), end: Self.date(2026, 11, 2),
                                        repeat: .none, reference: Self.date(2026, 10, 30), calendar: cal)
        XCTAssertEqual(state.phase, .range(.inProgress(dayNumber: 3, totalDays: 6)))
    }
}

// MARK: - 票 07 回归:跨时区/夏令时边界(spec:由测试钉死)

extension DateMathTests {
    /// 纽约 2026-03-08 02:00 进入 DST;自然日差仍按当地日历天算
    func testDaysBetweenAcrossDSTSpringForward() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        // 3/7(EST)→ 3/9(EDT)仍为 2 天,不因少一小时变 1.958 天
        XCTAssertEqual(DateMath.daysBetween(Self.date(2026, 3, 7), Self.date(2026, 3, 9), in: cal), 2)
        // 秋季回拨:11/1 有 25 小时,仍是 1 天
        XCTAssertEqual(DateMath.daysBetween(Self.date(2026, 10, 31), Self.date(2026, 11, 1), in: cal), 1)
    }

    /// 每周滚动跨 DST 仍保当地 09:00 与星期几
    func testNextOccurrenceWeeklyAcrossDST() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let anchor = Self.date(2026, 3, 1, hour: 9) // 周日(EST)
        let next = DateMath.nextOccurrence(anchor: anchor, repeat: .weekly,
                                           reference: Self.date(2026, 3, 2), calendar: cal)
        XCTAssertEqual(next, Self.date(2026, 3, 8, hour: 9)) // 下周日(EDT),当地时刻不变
        XCTAssertEqual(cal.component(.weekday, from: next), cal.component(.weekday, from: anchor))
    }

    /// 「最近将到」排序:今天 < 未来近 < 未来远 < 过去近 < 过去远
    func testUpcomingSortOrder() {
        let cal = Self.calendar
        let reference = Self.date(2026, 10, 21)
        let today = Daymark(name: "今天", date: Self.date(2026, 10, 21))
        let near = Daymark(name: "近未来", date: Self.date(2026, 10, 23))
        let far = Daymark(name: "远未来", date: Self.date(2026, 12, 1))
        let recentPast = Daymark(name: "近过去", date: Self.date(2026, 10, 19))
        let distantPast = Daymark(name: "远过去", date: Self.date(2026, 1, 1))

        let sorted = DaymarkSort.upcoming([distantPast, today, far, recentPast, near],
                                          reference: reference, calendar: cal)
        XCTAssertEqual(sorted.map(\.name), ["今天", "近未来", "远未来", "近过去", "远过去"])
    }
}
