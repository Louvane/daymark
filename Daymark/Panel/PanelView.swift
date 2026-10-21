import SwiftUI

/// 面板内导航路由(票 03 扩展详情/编辑)
enum PanelRoute: Hashable {
    case create
}

/// 面板:点击菜单栏图标弹出的主操作入口。所有导航在面板内 push/pop,不另开窗口。
struct PanelView: View {
    @State private var path: [PanelRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            DaymarkListView(onAdd: { path.append(.create) })
                .navigationDestination(for: PanelRoute.self) { route in
                    switch route {
                    case .create:
                        DaymarkFormView(mode: .create, onBack: { path.removeLast() })
                    }
                }
        }
        .frame(width: 320, height: 440)
    }
}
