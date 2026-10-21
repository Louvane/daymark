import SwiftUI
import SwiftData

/// 排序方式
enum DaymarkSortMode: String {
    case upcoming
    case manual
}

/// 列表:最近优先/手动两种排序,每行颜色徽标 + Emoji + 名称 + 天数;点行进详情,手动模式可拖拽
struct DaymarkListView: View {
    @Environment(DaymarkStore.self) private var store
    @Query private var daymarks: [Daymark]
    @AppStorage("panel.sortMode") private var sortModeRaw = DaymarkSortMode.upcoming.rawValue

    let onAdd: () -> Void
    let onOpen: (UUID) -> Void

    private var sortMode: DaymarkSortMode {
        DaymarkSortMode(rawValue: sortModeRaw) ?? .upcoming
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

    private var header: some View {
        HStack {
            Text("panel.title")
                .font(.headline)
            Spacer()
            // 排序方式切换(最近优先 ↔ 手动)
            Menu {
                Picker("list.sort.mode", selection: $sortModeRaw) {
                    Text("list.sort.upcoming").tag(DaymarkSortMode.upcoming.rawValue)
                    Text("list.sort.manual").tag(DaymarkSortMode.manual.rawValue)
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(Text("list.add.help"))
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

    /// 手动模式用原生 List 拿拖拽;最近优先用轻量 ScrollView
    @ViewBuilder
    private var list: some View {
        if sortMode == .manual {
            List {
                ForEach(sorted, id: \.id) { item in
                    row(item)
                }
                .onMove(perform: moveItems)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(sorted, id: \.id) { item in
                        row(item)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
    }

    private func row(_ item: Daymark) -> some View {
        Button {
            onOpen(item.id)
        } label: {
            DaymarkRow(item: item)
        }
        .buttonStyle(.plain)
    }

    /// 拖拽排序:按新顺序重写 sortWeight 并持久化
    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = sorted
        items.move(fromOffsets: source, toOffset: destination)
        DaymarkSort.applyManualOrder(items) { store.save() }
    }
}

/// 列表行:颜色徽标 + Emoji、名称、天数状态
struct DaymarkRow: View {
    let item: Daymark

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(DaymarkColorPalette.color(at: item.colorIndex).opacity(0.22))
                Text(item.emoji)
                    .font(.title3)
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                countdownText
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private var countdownText: Text {
        let state = DaymarkStatus.state(anchor: item.startDate, end: item.endDate, repeat: item.repeatCycle,
                                        reference: .now, calendar: DateMath.userCalendar())
        return countdownLabel(state.phase)
    }
}
