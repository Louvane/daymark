import Foundation
import ServiceManagement

/// 提醒时刻值对象(时:分)
struct DaymarkReminderTime: Equatable, Sendable {
    var hour: Int
    var minute: Int

    /// 分钟数(0..1439),UserDefaults 存储形态
    var minutesSinceMidnight: Int {
        get { hour * 60 + minute }
        set {
            let clamped = min(max(newValue, 0), 24 * 60 - 1)
            hour = clamped / 60
            minute = clamped % 60
        }
    }

    static let `default` = DaymarkReminderTime(hour: 9, minute: 0)
}

/// 应用设置:UserDefaults 背书,注入 UI 与调度链路
@MainActor
@Observable
final class AppSettings {
    static let reminderMinutesKey = "settings.defaultReminderMinutes"
    static let launchAtLoginKey = "settings.launchAtLogin"
    static let sortModeKey = "settings.listSortMode"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 全局默认提醒时刻(无具体时刻的日标用它)
    var reminderTime: DaymarkReminderTime {
        get {
            let minutes = defaults.object(forKey: Self.reminderMinutesKey) as? Int
                ?? DaymarkReminderTime.default.minutesSinceMidnight
            var time = DaymarkReminderTime.default
            time.minutesSinceMidnight = minutes
            return time
        }
        set {
            defaults.set(newValue.minutesSinceMidnight, forKey: Self.reminderMinutesKey)
        }
    }

    /// 开机自启动(UI 期望值;实际注册状态由 LoginItemService 提供并可校正)
    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Self.launchAtLoginKey) }
        set { defaults.set(newValue, forKey: Self.launchAtLoginKey) }
    }

    /// 打开应用时校正:以系统实际注册状态为准
    func syncLaunchAtLogin(actual isRegistered: Bool) {
        launchAtLogin = isRegistered
    }

    /// 列表排序偏好(最近优先/手动)
    var sortMode: DaymarkSortMode {
        get { DaymarkSortMode(rawValue: defaults.string(forKey: Self.sortModeKey) ?? "") ?? .upcoming }
        set { defaults.set(newValue.rawValue, forKey: Self.sortModeKey) }
    }
}

/// 开机启动服务接缝:隔离 SMAppService,避免测试期真注册
protocol LoginItemServicing: Sendable {
    var isRegistered: Bool { get }
    func register() async throws
    func unregister() async throws
}

/// 真实实现:SMAppService.mainApp(macOS 13+ API)
struct SMAppLoginItemService: LoginItemServicing {
    var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func register() async throws {
        try SMAppService.mainApp.register()
    }

    func unregister() async throws {
        // 新 SDK 中 unregister 为 async API
        try await SMAppService.mainApp.unregister()
    }
}
