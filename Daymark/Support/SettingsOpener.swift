import AppKit

/// 打开设置窗口(面板齿轮入口)
@MainActor
enum SettingsOpener {
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        SettingsWindowController.shared.show()
    }
}
