import AppKit
import SwiftUI

/// 应用级单例:App(AppKit 侧)与 SwiftUI 侧共享的存储/设置/路由
@MainActor
final class AppContext {
    static let shared = AppContext()

    let settings = AppSettings()
    let router = AppRouter()

    lazy var store: DaymarkStore = {
        do {
            return try DaymarkStore(scheduler: UserNotificationScheduler(),
                                    reminderTime: { [settings] in settings.reminderTime })
        } catch {
            // 容器初始化失败属于不可恢复错误:无存储则应用无意义
            fatalError("无法初始化 SwiftData 容器:\(error)")
        }
    }()
}

/// 打开 SwiftUI Settings 场景(面板齿轮入口)
@MainActor
enum SettingsOpener {
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        // SwiftUI Settings 场景没有公开打开 API,系统响应此动作(macOS 13+ 通用做法)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        // 窗口异步创建,稍后再抢一次焦点,保证压在其他应用之上
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

/// 菜单栏状态项 + 自绘面板:NSStatusItem + NSPanel(非激活式)。
/// 面板水平居中于状态项图标(图标恒在面板中轴线上方),顶部箭头指向图标。
@MainActor
final class StatusItemPanelController: NSObject, NSWindowDelegate {
    static let shared = StatusItemPanelController()

    private var statusItem: NSStatusItem?
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 452),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private var isSetUp = false

    /// 启动时装配状态项与面板(幂等)
    func setup(context: AppContext) {
        guard !isSetUp else { return }
        isSetUp = true

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "calendar.badge.clock",
                                   accessibilityDescription: "Daymark")
            button.action = #selector(togglePanel)
            button.target = self
        }
        statusItem = item

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let root = PanelView()
            .environment(context.store)
            .environment(context.settings)
            .environment(context.router)
            .modelContainer(context.store.container)
        panel.contentView = NSHostingView(rootView: root)
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let button = statusItem?.button, let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else { return }
        positionPanel(under: button, in: buttonWindow, on: screen)
        panel.makeKeyAndOrderFront(nil)
        statusItem?.button?.highlight(true)
    }

    func closePanel() {
        panel.orderOut(nil)
        statusItem?.button?.highlight(false)
    }

    /// 图标中轴线正对面板中线:面板中心 x = 图标中心 x(夹钳到屏幕内),紧贴菜单栏下方
    private func positionPanel(under button: NSStatusBarButton,
                               in buttonWindow: NSWindow, on screen: NSScreen) {
        let iconMidX = buttonWindow.frame.minX + button.frame.midX
        let menuBarBottomY = buttonWindow.frame.minY
        let size = panel.frame.size
        let x = max(screen.frame.minX + 4,
                    min(iconMidX - size.width / 2, screen.frame.maxX - size.width - 4))
        let y = menuBarBottomY - 4 - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidResignKey(_ notification: Notification) {
        // 失焦自动关闭,与 MenuBarExtra 行为一致
        closePanel()
    }
}
