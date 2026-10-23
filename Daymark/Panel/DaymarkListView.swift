import SwiftUI
import SwiftData

/// 列表:最近优先/手动两种排序;行内 Emoji + 名称/元信息 + 右侧大数字(Moment 式)。
/// 点行进详情,右键详情/编辑/删除;手动模式可拖拽。
struct DaymarkListView: View {
    @Environment(DaymarkStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Query private var daymarks: [Daymark]

    let onAdd: () -> Void
    let onOpen: (UUID) -> Void
    let onEdit: (UUID) -> Void
    let onDeleteRequest: (Daymark) -> Void

    /// 右键删除的待确认条目
    @State private var pendingDelete: Daymark?
    /// 自绘排序下拉(NSMenu 桥接在非激活面板里点击无效,故用 SwiftUI 自绘)
    @State private var showsSortMenu = false
    /// 手动排序拖拽:实时让位(live reorder)。非激活面板里系统 List 拖放无效,自实现手势。
    @State private var dragItemID: UUID?
    @State private var dragInitialIndex = 0
    @State private var dragCurrentIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var dragOrder: [Daymark] = []
    private let manualRowHeight: CGFloat = 50

    private var isDragging: Bool { dragItemID != nil }
    /// 拖拽行的视觉位移:手指位移扣除已让位的行数 × 行高,保证行始终跟手
    private var dragVisualOffset: CGFloat {
        dragTranslation - CGFloat(dragCurrentIndex - dragInitialIndex) * manualRowHeight
    }

    private var sortMode: DaymarkSortMode {
        settings.sortMode
    }

    private var sorted: [Daymark] {
        switch sortMode {
        case .upcoming:
            return DaymarkSort.upcoming(daymarks, reference: .now, calendar: DateMath.userCalendar())
        case .manual:
            return DaymarkSort.manual(daymarks)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if sorted.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .overlay {
            if showsSortMenu {
                // 显式 topTrailing ZStack:否则内层 ViewBuilder 默认居中,下拉会跑到面板中间
                ZStack(alignment: .topTrailing) {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.12)) { showsSortMenu = false }
                        }
                    sortDropdown
                        .padding(.trailing, 14)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// 排序下拉(锚定排序图标下方,当前项带 ✓)
    private var sortDropdown: some View {
        VStack(spacing: 2) {
            sortOption(.upcoming, Text("list.sort.upcoming"))
            sortOption(.manual, Text("list.sort.manual"))
        }
        .padding(6)
        .frame(width: 160) // 紧凑内容宽,与原生菜单一致(通栏是错的)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.4)))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func sortOption(_ mode: DaymarkSortMode, _ label: Text) -> some View {
        Button {
            settings.sortMode = mode
            withAnimation(.easeOut(duration: 0.15)) { showsSortMenu = false }
        } label: {
            HStack {
                label
                Spacer()
                if sortMode == mode {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            sortMode == mode ? Color.primary.opacity(0.06) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    /// 面板头部:齿轮左 · 品牌字标居中 · 排序/+ 右(Moment 式三段)
    private var header: some View {
        ZStack {
            HStack {
                Button {
                    SettingsOpener.open()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(HoverIconButtonStyle())
                .help(Text("list.settings.help"))
                Spacer()
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showsSortMenu.toggle() }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .buttonStyle(HoverIconButtonStyle())
                    .help(Text("list.sort.mode"))
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.body.bold())
                    }
                    .buttonStyle(HoverIconButtonStyle())
                    .help(Text("list.add.help"))
                }
            }
            Text("DAYMARK")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("list.empty.title")
                .font(.headline)
            Text("list.empty.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    /// 两种模式同一容器;拖拽期间渲染 dragOrder,其他行实时让位
    @ViewBuilder
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let order = isDragging ? dragOrder : sorted
                ForEach(order, id: \.id) { item in
                    let lifting = dragItemID == item.id
                    row(item)
                        // 浮起卡片:出现/退出禁用动画(否则结束时白→透明被播成"闪白")
                        .background {
                            ZStack {
                                if lifting {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
                                        .transition(.identity)
                                        .transaction { $0.animation = nil }
                                }
                            }
                        }
                        .scaleEffect(lifting ? 1.03 : 1)
                        .offset(y: lifting ? dragVisualOffset : 0)
                        .zIndex(lifting ? 1 : 0)
                        .gesture(sortMode == .manual && !isDragging ? dragGesture(item) : nil)
                    Divider()
                        .opacity(lifting ? 0 : 1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            // 让位动画绑定 dragOrder(拖拽中变化的数据源);落定回绑 sorted
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: dragOrder.map(\.id))
            .animation(.easeOut(duration: 0.15), value: sorted.map(\.id))
        }
    }

    /// 拖动 ≥8pt 抬起;位移每跨过一行高,其余行实时让位;松手落定并持久化
    private func dragGesture(_ item: Daymark) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                if dragItemID == nil {
                    dragItemID = item.id
                    dragInitialIndex = sorted.firstIndex { $0.id == item.id } ?? 0
                    dragCurrentIndex = dragInitialIndex
                    dragOrder = sorted
                } else if dragItemID == item.id {
                    dragTranslation = value.translation.height
                    let count = dragOrder.count
                    let target = min(max(dragInitialIndex + Int((dragTranslation / manualRowHeight).rounded()),
                                         0), count - 1)
                    if target != dragCurrentIndex {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            dragOrder.move(fromOffsets: IndexSet(integer: dragCurrentIndex),
                                           toOffset: target > dragCurrentIndex ? target + 1 : target)
                            dragCurrentIndex = target
                        }
                    }
                }
            }
            .onEnded { _ in
                defer {
                    dragItemID = nil
                    dragInitialIndex = 0
                    dragCurrentIndex = 0
                    dragTranslation = 0
                    dragOrder = []
                }
                guard dragItemID != nil,
                      dragOrder.map(\.id) != sorted.map(\.id) else { return }
                DaymarkSort.applyManualOrder(dragOrder) { store.save() }
            }
    }

    private func row(_ item: Daymark) -> some View {
        DaymarkListRow(
            snapshot: .init(from: item),
            confirmingDelete: pendingDelete?.id == item.id,
            onOpen: { onOpen(item.id) },
            onEdit: { onEdit(item.id) },
            onDeleteRequest: { pendingDelete = item },
            onCancelDelete: { pendingDelete = nil },
            onConfirmDelete: {
                if let victim = pendingDelete {
                    store.delete(victim)
                }
                pendingDelete = nil
            }
        )
    }

}

/// 列表行(Moment 式):Emoji 左 · 名称/元信息中 · 大数字+单位右。
/// 渲染只用值快照,删除后模型失效也不会导致重渲染崩溃。
struct DaymarkListRow: View {
    @State private var hovering = false

    struct Snapshot {
        let name: String
        let emoji: String
        let iconImageData: Data?
        let colorIndex: Int
        let startDate: Date
        let endDate: Date?
        let repeatCycle: RepeatCycle

        init(from item: Daymark) {
            name = item.name
            emoji = item.emoji
            iconImageData = item.iconImageData
            colorIndex = item.colorIndex
            startDate = item.startDate
            endDate = item.endDate
            repeatCycle = item.repeatCycle
        }
    }

    let snapshot: Snapshot
    /// 右键删除后的内联确认态(面板内禁用系统弹层:会让 MenuBarExtra 失焦自动关闭)
    let confirmingDelete: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDeleteRequest: () -> Void
    let onCancelDelete: () -> Void
    let onConfirmDelete: () -> Void

    init(snapshot: Snapshot, confirmingDelete: Bool,
         onOpen: @escaping () -> Void, onEdit: @escaping () -> Void,
         onDeleteRequest: @escaping () -> Void, onCancelDelete: @escaping () -> Void,
         onConfirmDelete: @escaping () -> Void) {
        self.snapshot = snapshot
        self.confirmingDelete = confirmingDelete
        self.onOpen = onOpen
        self.onEdit = onEdit
        self.onDeleteRequest = onDeleteRequest
        self.onCancelDelete = onCancelDelete
        self.onConfirmDelete = onConfirmDelete
    }

    private var state: DaymarkDisplayState {
        DaymarkStatus.state(anchor: snapshot.startDate, end: snapshot.endDate,
                            repeat: snapshot.repeatCycle,
                            reference: .now, calendar: DateMath.userCalendar())
    }

    var body: some View {
        Group {
        if confirmingDelete {
            confirmBar
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    iconView
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        metaText
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    badge
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(hovering ? Color.primary.opacity(0.05) : Color.clear)
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(action: onOpen) { Text("detail.title") }
                Button(action: onEdit) { Text("detail.action.edit") }
                Divider()
                Button(role: .destructive, action: onDeleteRequest) { Text("detail.action.delete") }
            }
        }
        }
        .animation(.easeOut(duration: 0.15), value: confirmingDelete)
    }

    /// 内联确认条:整行粉底(对齐排版稿 .row.confirm)
    private var confirmBar: some View {
        HStack(spacing: 10) {
            Text("detail.delete.confirm.title")
                .font(.callout.bold())
                .foregroundStyle(.red)
                .lineLimit(1)
            Spacer()
            Button("common.cancel", action: onCancelDelete)
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button("detail.action.delete", action: onConfirmDelete)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.red.opacity(0.08))
    }

    /// 图标:有图显示圆角缩略,否则 Emoji
    @ViewBuilder
    private var iconView: some View {
        if let data = snapshot.iconImageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            Text(snapshot.emoji)
                .font(.system(size: 19))
        }
    }

    /// 右侧大数字 + 单位,数字用所选颜色(票 06 的颜色标识)
    private var badge: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(badgeNumber)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(DaymarkColorPalette.color(at: snapshot.colorIndex))
            Text(badgeUnit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 元信息:重复(如有)· 发生日 · 状态词
    private var metaText: Text {
        var parts: [String] = []
        if snapshot.repeatCycle != .none {
            parts.append(String(localized: String.LocalizationValue(snapshot.repeatCycle.labelKey)))
        }
        parts.append(snapshot.startDate.formatted(date: .long, time: .omitted))
        parts.append(statusWord)
        return Text(parts.joined(separator: " · "))
    }

    private var statusWord: String {
        let key: String.LocalizationValue
        switch state.phase {
        case .today: return String(localized: "countdown.today")
        case .upcoming: key = "meta.upcoming"
        case .elapsed: key = "meta.elapsed"
        case .range(.notStarted): key = "meta.notStarted"
        case .range(.inProgress): key = "meta.inProgress"
        case .range(.ended): key = "meta.ended"
        }
        return String(localized: key)
    }

    /// 右侧徽标的主数字与单位
    private var badgeNumber: String {
        switch state.phase {
        case .today: return "0"
        case .upcoming(let n): return "\(n)"
        case .elapsed(let n): return "\(n)"
        case .range(.notStarted(let n)): return "\(n)"
        case .range(.inProgress(let day, _)): return "\(day)"
        case .range(.ended(let n)): return "\(n)"
        }
    }

    private var badgeUnit: String {
        switch state.phase {
        case .today, .upcoming, .elapsed, .range(.notStarted), .range(.ended):
            return String(localized: "list.unit.days")
        case .range(.inProgress(_, let total)):
            return String(localized: "meta.rangeTotal \(total)")
        }
    }
}
