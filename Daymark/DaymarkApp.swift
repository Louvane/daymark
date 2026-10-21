import SwiftUI
import UserNotifications

// 应用入口:纯菜单栏形态(LSUIElement),MenuBarExtra window 样式面板
@main
struct DaymarkApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store: DaymarkStore

    init() {
        do {
            let created = try DaymarkStore()
            _store = State(initialValue: created)
            // 应用启动全量重排提醒(票 05:启动与数据变更时全量重排)
            Task { await created.rescheduleReminders() }
        } catch {
            // 容器初始化失败属于不可恢复错误:无存储则应用无意义
            fatalError("无法初始化 SwiftData 容器:\(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(store)
                .environment(appDelegate.router)
                .modelContainer(store.container)
        } label: {
            // 菜单栏图标:日历角标时钟,模板渲染自适应深浅色
            Image(systemName: "calendar.badge.clock")
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - 应用代理:通知点击路由

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let router = AppRouter()
    private var tapHandler: NotificationTapHandler?

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
