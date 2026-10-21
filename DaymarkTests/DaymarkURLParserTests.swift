import XCTest
@testable import Daymark

/// 票 09:daymark://create 解析(纯函数)
final class DaymarkURLParserTests: XCTestCase {
    private let calendar = DateMathTests.calendar

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    func testParsesCompletePayload() {
        let payload = DaymarkURLParser.parse(
            url("daymark://create?name=%E7%94%9F%E6%97%A5&date=2026-12-24&repeat=yearly"),
            calendar: calendar
        )
        XCTAssertEqual(payload?.name, "生日")
        XCTAssertEqual(payload?.date, DateMathTests.date(2026, 12, 24))
        XCTAssertEqual(payload?.repeatCycle, .yearly)
    }

    func testMissingParamsYieldNilFields() {
        let payload = DaymarkURLParser.parse(url("daymark://create"), calendar: calendar)
        XCTAssertNotNil(payload) // 合法 create,安全降级为空表单
        XCTAssertNil(payload?.name)
        XCTAssertNil(payload?.date)
        XCTAssertNil(payload?.repeatCycle)
    }

    func testGarbageValuesAreRejected() {
        let payload = DaymarkURLParser.parse(
            url("daymark://create?name=&date=not-a-date&repeat=sometimes"),
            calendar: calendar
        )
        XCTAssertNil(payload?.name) // 空名不预填
        XCTAssertNil(payload?.date)
        XCTAssertNil(payload?.repeatCycle)
    }

    func testOversizedNameIsClamped() {
        let long = String(repeating: "A", count: 5_000)
        let payload = DaymarkURLParser.parse(
            url("daymark://create?name=\(long)&date=2026-12-24"),
            calendar: calendar
        )
        XCTAssertEqual(payload?.name?.count, DaymarkURLParser.nameLengthLimit)
    }

    func testNonCreateRoutesAndSchemesAreIgnored() {
        XCTAssertNil(DaymarkURLParser.parse(url("daymark://other?name=x"), calendar: calendar))
        XCTAssertNil(DaymarkURLParser.parse(url("https://example.com/create?name=x"), calendar: calendar))
    }

    func testDateIsCalendarDayRegardlessOfTimeZone() {
        // 解析出的 Date 在固定日历下落在 2026-02-29(闰日)
        let payload = DaymarkURLParser.parse(url("daymark://create?date=2024-02-29"), calendar: calendar)
        XCTAssertEqual(payload?.date, DateMathTests.date(2024, 2, 29))
    }
}
