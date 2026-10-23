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
                            onBack: pop,
                            onEdit: { path.append(.edit(id)) },
                            onDelete: {
                                // 先出栈,等动画结束再删:详情页重渲染期间模型必须仍有效
                                path.removeAll()
                                let victim = item
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 400_000_000)
                                    store.delete(victim)
                                }
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
        .padding(.top, 12) // 顶部留给指向图标的面板箭头
        .frame(width: 320, height: 560)
        .background(PanelShape().fill(.ultraThinMaterial))
        .overlay(PanelShape().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5))
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
            onOpen: { path.append(.detail($0)) },
            onEdit: { path.append(.edit($0)) },
            onDeleteRequest: { victim in
                store.delete(victim)
            }
        )
    }

    private func item(with id: UUID) -> Daymark? {
        try? store.fetchAll().first { $0.id == id }
    }

    private func pop() {
        if path.isEmpty == false { path.removeLast() }
    }
}


/// 面板底形:圆角矩形 + 顶部居中箭头(指向菜单栏图标)
struct PanelShape: Shape {
    func path(in rect: CGRect) -> Path {
        let caretHeight: CGFloat = 12
        let caretWidth: CGFloat = 20
        var path = Path()
        let bodyRect = CGRect(x: rect.minX, y: rect.minY + caretHeight,
                              width: rect.width, height: rect.height - caretHeight)
        path.addRoundedRect(in: bodyRect,
                            cornerSize: CGSize(width: 12, height: 12),
                            style: .continuous)
        path.move(to: CGPoint(x: rect.midX - caretWidth / 2, y: rect.minY + caretHeight))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + caretWidth / 2, y: rect.minY + caretHeight))
        path.closeSubpath()
        return path
    }
}
