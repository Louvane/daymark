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
