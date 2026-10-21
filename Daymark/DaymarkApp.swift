import SwiftUI
import UserNotifications

// 应用入口:纯菜单栏形态(LSUIElement),MenuBarExtra window 样式面板 + Settings 场景
@main
struct DaymarkApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store: DaymarkStore
    @State private var settings: AppSettings

    init() {
        let appSettings = AppSettings()
        _settings = State(initialValue: appSettings)
        do {
            let created = try DaymarkStore(
                scheduler: UserNotificationScheduler(),
                reminderTime: { appSettings.reminderTime }
            )
            _store = State(initialValue: created)
            // 应用启动全量重排提醒(票 05:启动与数据变更时全量重排)
            Task { await created.rescheduleReminders() }
            // 快速创建窗与存储同源(daymark:// 唤起用)
            Task { @MainActor in
                QuickCreateWindowController.shared.attach(store: created)
            }
        } catch {
            // 容器初始化失败属于不可恢复错误:无存储则应用无意义
            fatalError("无法初始化 SwiftData 容器:\(error)")
        }
        // 打开应用时校正开机启动状态(以系统实际注册为准)
        Task { @MainActor in
            let service = SMAppLoginItemService()
            appSettings.syncLaunchAtLogin(actual: service.isRegistered)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(store)
                .environment(settings)
                .environment(appDelegate.router)
                .modelContainer(store.container)
        } label: {
            // 菜单栏图标:日历角标时钟,模板渲染自适应深浅色
            Image(systemName: "calendar.badge.clock")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(store)
                .environment(settings)
        }
    }
}

// MARK: - 应用代理:通知点击路由

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let router = AppRouter()
    private var tapHandler: NotificationTapHandler?

    // daymark://create?name=…&date=…&repeat=… 唤起:解析预填创建表单
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            // 非法参数在解析层安全降级为 nil 字段(空表单)
            let payload = DaymarkURLParser.parse(url, calendar: .current)
            router.pendingCreatePayload = payload
            QuickCreateWindowController.shared.show(prefill: payload)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let handler = NotificationTapHandler { [weak router] id in
            Task { @MainActor in
                router?.pendingDetailID = id
                // MenuBarExtra 面板无法编程打开;激活应用确保下次点开直接落在详情
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        tapHandler = handler
        UNUserNotificationCenter.current().delegate = handler
    }
}
