import SwiftUI

// 应用入口:纯菜单栏形态(LSUIElement),MenuBarExtra window 样式面板
@main
struct DaymarkApp: App {
    @State private var store: DaymarkStore

    init() {
        do {
            _store = State(initialValue: try DaymarkStore())
        } catch {
            // 容器初始化失败属于不可恢复错误:无存储则应用无意义
            fatalError("无法初始化 SwiftData 容器:\(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environment(store)
                .modelContainer(store.container)
        } label: {
            // 菜单栏图标:日历角标时钟,模板渲染自适应深浅色
            Image(systemName: "calendar.badge.clock")
        }
        .menuBarExtraStyle(.window)
    }
}
