import Foundation
import os.log
import UserNotifications

/// 提醒调度接缝(领域接缝 3):隔离 UNUserNotificationCenter,测试用假实现
protocol ReminderScheduling: Sendable {
    func requestAuthorizationIfNeeded() async
    func removeAllPending() async
    func add(_ request: ReminderRequest) async
}

/// 真实实现:macOS 本地通知。无捕获状态,UNUserNotificationCenter 线程安全。
struct UserNotificationScheduler: ReminderScheduling {
    /// 通知 userInfo 中携带日标 id 的 key(点通知定位详情)
    static let payloadIDKey = "daymarkID"

    private static let log = Logger(subsystem: "app.louvane.Daymark", category: "reminders")

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            Self.log.info("通知授权结果 granted=\(granted)")
        } catch {
            // 吞错误会导致「为什么不弹授权框」无从排查,必须落日志
            Self.log.error("通知授权请求失败: \(error, privacy: .public)")
        }
    }

    func removeAllPending() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func add(_ request: ReminderRequest) async {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = [Self.payloadIDKey: request.daymarkID.uuidString]

        // 与规划层同一日历构造(Gregorian+用户时区),DST 边界行为一致
        let components = DateMath.userCalendar().dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: request.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let notification = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(notification)
    }
}

/// 全量重排协调器:先清后加,天然幂等
@MainActor
final class ReminderRescheduler {
    private let scheduler: any ReminderScheduling
    /// 默认提醒时刻提供者(票 08:来自设置,可变)
    private let reminderTime: () -> DaymarkReminderTime

    init(scheduler: any ReminderScheduling,
         reminderTime: @escaping () -> DaymarkReminderTime = { .default }) {
        self.scheduler = scheduler
        self.reminderTime = reminderTime
    }

    func rescheduleAll(_ facts: [DaymarkReminderFacts],
                       reference: Date = .now,
                       calendar: Calendar = DateMath.userCalendar()) async {
        let requests = ReminderPlanning.requests(from: facts, reference: reference,
                                                 calendar: calendar, time: reminderTime())
        await scheduler.removeAllPending()
        guard !requests.isEmpty else { return }
        await scheduler.requestAuthorizationIfNeeded()
        for request in requests {
            await scheduler.add(request)
        }
    }
}
