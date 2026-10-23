import AppKit
import SwiftUI

/// 设置窗口:AppKit 自托管(AppDelegate 与 SwiftUI 之外可靠打开;
/// 私有选择器 showSettingsWindow: 在新系统已失效,故不再依赖)
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        let context = AppContext.shared
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                             styleMask: [.titled, .closable],
                             backing: .buffered,
                             defer: false)
            w.title = String(localized: "settings.window.title")
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        let root = SettingsView()
            .environment(context.store)
            .environment(context.settings)
        window?.contentView = NSHostingView(rootView: root)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
