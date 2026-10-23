import AppKit
import SwiftUI
import UserNotifications

// 应用入口:LSUIElement 菜单栏应用。
// 面板由 StatusItemPanelController(NSStatusItem + NSPanel)承载,
// 设置窗口由 SettingsWindowController 托管(均见 Support/)。
@main
struct DaymarkApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var store: DaymarkStore
    @State private var settings: AppSettings

    init() {
        let context = AppContext.shared
        _settings = State(initialValue: context.settings)
        _store = State(initialValue: context.store)
        // 应用启动全量重排提醒(票 05:启动与数据变更时全量重排)
        Task { await context.store.rescheduleReminders() }
        // 打开应用时校正开机启动状态(以系统实际注册为准)
        Task { @MainActor in
            context.settings.syncLaunchAtLogin(actual: SMAppLoginItemService().isRegistered)
        }
    }

    var body: some Scene {
        // 场景清单为空:窗口全部由 AppKit 侧控制器托管
        Settings { } 
    }
}

// MARK: - 应用代理:装配面板 + 通知点击路由

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let router = AppRouter()
    private var tapHandler: NotificationTapHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 状态项 + 面板(图标居中于面板中轴,顶部箭头指向图标)
        StatusItemPanelController.shared.setup(context: AppContext.shared)

        let handler = NotificationTapHandler { [weak router] id in
            Task { @MainActor in
                router?.pendingDetailID = id
                // 面板若未打开,先唤起面板再落详情
                StatusItemPanelController.shared.showPanel()
                // MenuBarExtra/NSPanel 均无法编程抢行;打开面板即见对应详情
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        tapHandler = handler
        UNUserNotificationCenter.current().delegate = handler
    }
}
