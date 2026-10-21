import SwiftUI

/// 面板内导航路由
enum PanelRoute: Hashable {
    case create(DaymarkURLPayload?)
    case detail(UUID)
    case edit(UUID)
}

/// 面板:点击菜单栏图标弹出的主操作入口。所有导航在面板内 push/pop,不另开窗口。
struct PanelView: View {
    @Environment(DaymarkStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var path: [PanelRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            listView
                .navigationDestination(for: PanelRoute.self) { route in
                switch route {
                case .create(let prefill):
                    DaymarkFormView(mode: .create, prefill: prefill, onBack: pop)
                case .detail(let id):
                    if let item = item(with: id) {
                        DaymarkDetailView(
                            item: item,
                            onEdit: { path.append(.edit(id)) },
                            onDelete: {
                                store.delete(item)
                                path.removeAll()
                            }
                        )
                    } else {
                        // 数据已被删除(路由残留):安全回落到列表
                        listView
                    }
                case .edit(let id):
                    if let item = item(with: id) {
                        DaymarkFormView(mode: .edit(item), onBack: pop)
                    } else {
                        listView
                    }
                }
            }
        }
        .frame(width: 320, height: 440)
        .onChange(of: router.pendingDetailID) { _, newID in
            // 通知点击 → 面板打开后直接落在对应详情
            guard let id = newID else { return }
            path = [.detail(id)]
            router.pendingDetailID = nil
        }
        .onChange(of: router.pendingCreatePayload) { _, payload in
            // 链接唤起 → 面板打开后落在预填创建表单
            guard payload != nil else { return }
            path = [.create(payload)]
            router.pendingCreatePayload = nil
        }
    }

    /// 列表视图统一构造(回落场景复用)
    private var listView: some View {
        DaymarkListView(
            onAdd: { path.append(.create(nil)) },
            onOpen: { path.append(.detail($0)) }
        )
    }

    private func item(with id: UUID) -> Daymark? {
        try? store.fetchAll().first { $0.id == id }
    }

    private func pop() {
        if path.isEmpty == false { path.removeLast() }
    }
}
