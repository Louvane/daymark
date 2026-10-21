import XCTest
@testable import Daymark

/// 票 05:提醒规划(纯函数)+ 全量重排(假调度器)
@MainActor
final class ReminderTests: XCTestCase {
    // MARK: - 工具

    private func facts(name: String = "生日",
                       anchor: Date,
                       hasTime: Bool = false,
                       repeatCycle: RepeatCycle = .none,
                       remindDays: Int) -> DaymarkReminderFacts {
        DaymarkReminderFacts(id: UUID(), name: name, anchor: anchor,
                             hasTime: hasTime, repeatCycle: repeatCycle, remindDays: remindDays)
    }

    private let calendar = DateMathTests.calendar
    private var reference: Date { Self.date(2026, 10, 21, hour: 12) }
    private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 9, minute: Int = 0) -> Date {
        DateMathTests.date(y, m, d, hour: hour, minute: minute)
    }

    // MARK: - 规划:基础

    func testPlanningSkipsWhenReminderDisabled() {
        let requests = ReminderPlanning.requests(
            from: [facts(anchor: Self.date(2026, 10, 25), remindDays: 0)],
            reference: reference, calendar: calendar
        )
        XCTAssertTrue(requests.isEmpty)
    }

    func testPlanningFireDateIsOccurrenceMinusDaysAtDefaultTime() {
        // 无时刻日标:发生 10/25,提前 2 天 → 10/23 09:00(默认时刻)
        let requests = ReminderPlanning.requests(
            from: [facts(anchor: Self.date(2026, 10, 25), remindDays: 2)],
            reference: reference, calendar: calendar
        )
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.fireDate, Self.date(2026, 10, 23, hour: 9))
    }

    func testPlanningSkipsWhenFireDateAlreadyPast() {
        // 提前 7 天的触发点(10/18)已过 → 不排
        let requests = ReminderPlanning.requests(
            from: [facts(anchor: Self.date(2026, 10, 25), remindDays: 7)],
            reference: reference, calendar: calendar
        )
        XCTAssertTrue(requests.isEmpty)
    }

    func testPlanningIdentifierIsStableAndPerOccurrence() {
        let f = facts(anchor: Self.date(2026, 10, 25), remindDays: 1)
        let first = ReminderPlanning.requests(from: [f], reference: reference, calendar: calendar)
        let second = ReminderPlanning.requests(from: [f], reference: reference, calendar: calendar)
        XCTAssertEqual(first.first?.identifier, second.first?.identifier)
        XCTAssertTrue(first.first?.identifier.hasPrefix(f.id.uuidString) == true) // 前缀=日标 id
    }

    // MARK: - 规划:重复与时刻

    func testPlanningWithSpecificTimeFallsAtOccurrenceTime() {
        // hasTime:发生 11/1 14:30,提前 2 天 → 10/30 14:30(落在该时刻而非默认 09:00)
        let requests = ReminderPlanning.requests(
            from: [facts(anchor: Self.date(2026, 11, 1, hour: 14, minute: 30),
                         hasTime: true, remindDays: 2)],
            reference: reference, calendar: calendar
        )
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.fireDate,
                       Self.date(2026, 10, 30, hour: 14, minute: 30))
    }

    func testRepeatingSchedulesOnlyNextOccurrence() {
        // 每年生日 1/1,提前 3 天 → 只为 2027-01-01 排一条,触发 2026-12-29
        let requests = ReminderPlanning.requests(
            from: [facts(anchor: Self.date(2020, 1, 1), repeatCycle: .yearly, remindDays: 3)],
            reference: reference, calendar: calendar
        )
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.fireDate, Self.date(2026, 12, 29, hour: 9))
        XCTAssertEqual(DateMathTests.calendar.startOfDay(for: requests.first!.occurrence),
                       Self.date(2027, 1, 1, hour: 0))
    }

    // MARK: - 全量重排(假调度器)

    private func makeStore(scheduler: FakeReminderScheduler) throws -> DaymarkStore {
        try DaymarkStore(inMemory: true, scheduler: scheduler)
    }

    func testRescheduleIsIdempotent() async throws {
        let fake = FakeReminderScheduler()
        let store = try makeStore(scheduler: fake)
        store.add(Daymark(name: "A", date: Self.date(2026, 11, 1), remindDays: 1))
        store.add(Daymark(name: "B", date: Self.date(2026, 11, 2), remindDays: 2))

        await store.flushResync()
        let firstPass = fake.pendingRequests.map(\.identifier)
        XCTAssertEqual(fake.removeAllCount, 1)

        await store.flushResync()
        XCTAssertEqual(fake.removeAllCount, 2) // 先清后加
        XCTAssertEqual(fake.pendingRequests.map(\.identifier), firstPass) // 幂等:最终状态一致
    }

    func testDeleteRevokesScheduledReminder() async throws {
        let fake = FakeReminderScheduler()
        let store = try makeStore(scheduler: fake)
        let item = Daymark(name: "将删除", date: Self.date(2026, 11, 1), remindDays: 1)
        store.add(item)
        await store.flushResync()
        XCTAssertEqual(fake.pendingRequests.count, 1)

        store.delete(item)
        await store.flushResync()
        XCTAssertTrue(fake.pendingRequests.isEmpty) // 删除后已排提醒被撤销
    }

    func testEditingReminderDaysUpdatesSchedule() async throws {
        let fake = FakeReminderScheduler()
        let store = try makeStore(scheduler: fake)
        let item = Daymark(name: "可调", date: Self.date(2026, 11, 1), remindDays: 1)
        store.add(item)
        await store.flushResync()

        item.remindDays = 7
        store.update(item)
        await store.flushResync()

        // 11/1 - 7 天 = 10/25(未来),替换原 10/31
        let fireDates = fake.pendingRequests.map(\.fireDate)
        XCTAssertEqual(fireDates, [Self.date(2026, 10, 25, hour: 9)])
    }
}

// MARK: - 假调度器

@MainActor
final class FakeReminderScheduler: ReminderScheduling {
    private(set) var pendingRequests: [ReminderRequest] = []
    private(set) var removeAllCount = 0
    private(set) var authorizationRequests = 0

    func requestAuthorizationIfNeeded() async {
        authorizationRequests += 1
    }

    func removeAllPending() async {
        removeAllCount += 1
        pendingRequests = []
    }

    func add(_ request: ReminderRequest) async {
        pendingRequests.append(request)
    }
}
