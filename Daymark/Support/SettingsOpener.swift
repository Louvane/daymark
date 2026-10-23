import AppKit

/// 打开设置窗口(面板齿轮入口)
@MainActor
enum SettingsOpener {
    static func open() {
        // 面板是 statusBar 高层级,必须先收起,否则设置窗被压在下面
        StatusItemPanelController.shared.closePanel()
        NSApp.activate(ignoringOtherApps: true)
        SettingsWindowController.shared.show()
    }
}
