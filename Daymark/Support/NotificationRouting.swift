import AppKit
import UserNotifications

/// 全局路由状态:通知点击 → 面板定位详情
@MainActor
@Observable
final class AppRouter {
    /// 待定位的日标 id;面板消费后清空
    var pendingDetailID: UUID?
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
