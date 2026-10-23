import AppKit
import os.log
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

/// 菜单栏状态项 + 自绘面板:NSStatusItem + NSPanel(非激活式)。
/// 面板水平居中于状态项图标(图标恒在面板中轴线上方),顶部箭头指向图标。
@MainActor
final class StatusItemPanelController: NSObject, NSWindowDelegate {
    static let shared = StatusItemPanelController()

    private var statusItem: NSStatusItem?
    /// borderless 面板默认 canBecomeKey = false → 永远不会 resign → 无法「点外部关闭」;
    /// 必须子类化重写(经典 NSPanel 坑)
    private let panel = PanelWindow(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 452),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private var isSetUp = false
    /// 面板打开期间的全局点击监听:点面板外任意处收起
    /// (非激活面板的 resignKey 在切空间/点桌面等场景不可靠,故用全局监听兜底)
    private var outsideClickMonitor: Any?

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

    private static let log = Logger(subsystem: "app.louvane.Daymark", category: "panel")

    @objc private func togglePanel() {
        Self.log.info("togglePanel: visible=\(self.panel.isVisible)")
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let button = statusItem?.button, let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            Self.log.error("showPanel: guard 失败 button=\(self.statusItem?.button != nil)")
            return
        }
        positionPanel(under: button, in: buttonWindow, on: screen)
        panel.makeKeyAndOrderFront(nil)
        statusItem?.button?.highlight(true)
    }

    func closePanel() {
        panel.orderOut(nil)
        statusItem?.button?.highlight(false)
    }

    /// 图标中轴线正对面板中线:以辅助功能框为准(与渲染出的高亮胶囊一致;
    /// button.frame 与其存在内边距偏差,实测约 7px),紧贴菜单栏下方
    private func positionPanel(under button: NSStatusBarButton,
                               in buttonWindow: NSWindow, on screen: NSScreen) {
        let axFrame = button.accessibilityFrame()
        let iconMidX = axFrame.midX
        let menuBarBottomY = axFrame.minY
        let size = panel.frame.size
        let x = max(screen.frame.minX + 4,
                    min(iconMidX - size.width / 2, screen.frame.maxX - size.width - 4))
        let y = menuBarBottomY - 2 - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func windowDidResignKey(_ notification: Notification) {
        Self.log.info("面板失去 key(点击其他应用/桌面)")
        // 失焦自动关闭,与 MenuBarExtra 行为一致
        closePanel()
    }
}

/// 可成为 key 窗口的无边框面板
final class PanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
}
