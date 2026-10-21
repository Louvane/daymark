import SwiftUI

// 应用入口:纯菜单栏形态(LSUIElement),MenuBarExtra window 样式面板 + Settings 场景
@main
struct DaymarkApp: App {
    var body: some Scene {
        MenuBarExtra {
            PanelView()
        } label: {
            // 菜单栏图标:日历角标时钟,模板渲染自适应深浅色
            Image(systemName: "calendar.badge.clock")
        }
        .menuBarExtraStyle(.window)
    }
}
