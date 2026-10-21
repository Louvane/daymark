import AppKit
import SwiftUI
import UserNotifications

/// 全局路由状态:通知点击 → 面板定位详情;链接唤起 → 预填创建
@MainActor
@Observable
final class AppRouter {
    /// 待定位的日标 id;面板消费后清空
    var pendingDetailID: UUID?
    /// daymark:// 唤起的预填载荷(面板打开时落到创建表单)
    var pendingCreatePayload: DaymarkURLPayload?
}

/// 通知点击处理:从 userInfo 取日标 id,交回主线程路由并激活应用
/// 委托方法运行在非主线程,闭包内部自行 hop 回主线程
final class NotificationTapHandler: NSObject, UNUserNotificationCenterDelegate {
    private let onOpenDetail: @Sendable (UUID) -> Void

    init(onOpenDetail: @escaping @Sendable (UUID) -> Void) {
        self.onOpenDetail = onOpenDetail
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let idString = response.notification.request.content.userInfo[UserNotificationScheduler.payloadIDKey] as? String,
              let id = UUID(uuidString: idString) else { return }
        onOpenDetail(id)
    }
}

/// daymark:// 链接唤起:解析 → 预填创建表单
/// MenuBarExtra 面板无法编程打开(系统限制),以独立小窗立即呈现表单(ADR-0001 局部 AppKit)
@MainActor
final class QuickCreateWindowController {
    static let shared = QuickCreateWindowController()

    private var window: NSWindow?
    private var store: DaymarkStore?

    func attach(store: DaymarkStore) {
        self.store = store
    }

    func show(prefill: DaymarkURLPayload?) {
        guard let store else { return }
        let window = ensureWindow()
        // 表单保存/返回即关窗;环境注入与面板同源
        let form = DaymarkFormView(mode: .create, prefill: prefill, onBack: { [weak window] in
            window?.close()
        })
        .environment(store)
        .modelContainer(store.container)
        window.contentView = NSHostingView(rootView: form)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "form.title.create")
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}
