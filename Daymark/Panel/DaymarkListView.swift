import SwiftUI
import SwiftData

/// 列表:最近优先/手动两种排序;行内 Emoji + 名称/元信息 + 右侧大数字(Moment 式)。
/// 点行进详情,右键详情/编辑/删除;手动模式可拖拽。
struct DaymarkListView: View {
    @Environment(DaymarkStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.openSettings) private var openSettings
    @Query private var daymarks: [Daymark]

    let onAdd: () -> Void
    let onOpen: (UUID) -> Void
    let onEdit: (UUID) -> Void
    let onDeleteRequest: (Daymark) -> Void

    /// 右键删除的待确认条目
    @State private var pendingDelete: Daymark?

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
    }

    /// 面板头部:齿轮左 · 品牌字标居中 · 排序/+ 右(Moment 式三段)
    private var header: some View {
        ZStack {
            HStack {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help(Text("list.settings.help"))
                Spacer()
                HStack(spacing: 10) {
                    Menu {
                        Picker("list.sort.mode", selection: sortModeBinding) {
                            Text("list.sort.upcoming").tag(DaymarkSortMode.upcoming)
                            Text("list.sort.manual").tag(DaymarkSortMode.manual)
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.body.bold())
                    }
                    .buttonStyle(.plain)
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

    /// 排序偏好绑定(AppSettings 统一持久化通道)
    private var sortModeBinding: Binding<DaymarkSortMode> {
        Binding(get: { settings.sortMode }, set: { settings.sortMode = $0 })
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

    /// 手动模式用原生 List 拿拖拽;最近优先用轻量 ScrollView + 细分隔线
    @ViewBuilder
    private var list: some View {
        if sortMode == .manual {
            List {
                ForEach(sorted, id: \.id) { item in
                    row(item)
                }
                .onMove(perform: moveItems)
                .listRowSeparator(.visible)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sorted, id: \.id) { item in
                        row(item)
                        Divider().padding(.leading, 46)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
    }

    private func row(_ item: Daymark) -> some View {
        DaymarkListRow(
            snapshot: .init(from: item),
            onOpen: { onOpen(item.id) },
            onEdit: { onEdit(item.id) },
            onDeleteRequest: { pendingDelete = item }
        )
        .confirmationDialog(
            Text("detail.delete.confirm.title"),
            isPresented: Binding(
                get: { pendingDelete?.id == item.id },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { target in
            Button("detail.action.delete", role: .destructive) {
                onDeleteRequest(target)
            }
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("detail.delete.confirm.subtitle")
        }
    }

    /// 拖拽排序:按新顺序重写 sortWeight 并持久化
    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = sorted
        items.move(fromOffsets: source, toOffset: destination)
        DaymarkSort.applyManualOrder(items) { store.save() }
    }
}

/// 列表行(Moment 式):Emoji 左 · 名称/元信息中 · 大数字+单位右。
/// 渲染只用值快照,删除后模型失效也不会导致重渲染崩溃。
struct DaymarkListRow: View {
    struct Snapshot {
        let name: String
        let emoji: String
        let colorIndex: Int
        let startDate: Date
        let endDate: Date?
        let repeatCycle: RepeatCycle

        init(from item: Daymark) {
            name = item.name
            emoji = item.emoji
            colorIndex = item.colorIndex
            startDate = item.startDate
            endDate = item.endDate
            repeatCycle = item.repeatCycle
        }
    }

    let snapshot: Snapshot
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDeleteRequest: () -> Void

    init(snapshot: Snapshot, onOpen: @escaping () -> Void,
         onEdit: @escaping () -> Void, onDeleteRequest: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onOpen = onOpen
        self.onEdit = onEdit
        self.onDeleteRequest = onDeleteRequest
    }

    private var state: DaymarkDisplayState {
        DaymarkStatus.state(anchor: snapshot.startDate, end: snapshot.endDate,
                            repeat: snapshot.repeatCycle,
                            reference: .now, calendar: DateMath.userCalendar())
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Text(snapshot.emoji)
                    .font(.title3)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.name)
                        .font(.body.bold())
                        .lineLimit(1)
                    metaText
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                badge
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onOpen) { Text("detail.title") }
            Button(action: onEdit) { Text("detail.action.edit") }
            Divider()
            Button(role: .destructive, action: onDeleteRequest) { Text("detail.action.delete") }
        }
    }

    /// 右侧大数字 + 单位,数字用所选颜色(票 06 的颜色标识)
    private var badge: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(badgeNumber)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(DaymarkColorPalette.color(at: snapshot.colorIndex))
            Text(badgeUnit)
                .font(.caption2)
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
