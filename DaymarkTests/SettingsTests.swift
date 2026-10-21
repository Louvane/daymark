import XCTest
@testable import Daymark

/// 票 08:偏好设置 —— 默认提醒时刻持久化 + 重排用新时刻
@MainActor
final class SettingsTests: XCTestCase {
    private var suiteName: String { "SettingsTests-\(UUID().uuidString)" }
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testDefaultReminderTimeIsNineAM() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.reminderTime, DaymarkReminderTime(hour: 9, minute: 0))
    }

    func testReminderTimePersists() {
        let settings = AppSettings(defaults: defaults)
        settings.reminderTime = DaymarkReminderTime(hour: 10, minute: 30)

        // 重开(模拟重启)仍生效
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.reminderTime, DaymarkReminderTime(hour: 10, minute: 30))
    }

    func testRescheduleUsesNewDefaultTime() async throws {
        let settings = AppSettings(defaults: defaults)
        settings.reminderTime = DaymarkReminderTime(hour: 10, minute: 30)

        let fake = FakeReminderScheduler()
        let rescheduler = ReminderRescheduler(scheduler: fake, reminderTime: { settings.reminderTime })

        let facts = DaymarkReminderFacts(id: UUID(), name: "生日",
                                         anchor: DateMathTests.date(2026, 11, 1),
                                         hasTime: false, repeatCycle: .none, remindDays: 1)
        await rescheduler.rescheduleAll([facts],
                                        reference: DateMathTests.date(2026, 10, 21, hour: 12),
                                        calendar: DateMathTests.calendar)

        XCTAssertEqual(fake.pendingRequests.count, 1)
        // 无时刻日标:触发/发生都落新默认时刻 10:30
        XCTAssertEqual(fake.pendingRequests.first?.fireDate,
                       DateMathTests.date(2026, 10, 31, hour: 10, minute: 30))
    }

    func testSyncLaunchAtLoginReflectsActualStatus() {
        let settings = AppSettings(defaults: defaults)
        settings.launchAtLogin = true

        // 系统实际未注册 → 校正为 false(打开应用时同步)
        settings.syncLaunchAtLogin(actual: false)
        XCTAssertFalse(settings.launchAtLogin)

        settings.syncLaunchAtLogin(actual: true)
        XCTAssertTrue(settings.launchAtLogin)
    }
}
