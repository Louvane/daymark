import SwiftUI
import SwiftData

/// 列表:按「最近将到」排序,每行 Emoji + 名称 + 剩余/已过天数;点行进详情
struct DaymarkListView: View {
    @Environment(DaymarkStore.self) private var store
    @Query private var daymarks: [Daymark]

    let onAdd: () -> Void
    let onOpen: (UUID) -> Void

    private var sorted: [Daymark] {
        DaymarkSort.upcoming(daymarks, reference: .now, calendar: DateMath.userCalendar())
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(sorted, id: \.id) { item in
                    Button {
                        onOpen(item.id)
                    } label: {
                        DaymarkRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}

/// 列表行:Emoji、名称、天数状态
struct DaymarkRow: View {
    let item: Daymark

    var body: some View {
        HStack(spacing: 10) {
            Text(item.emoji)
                .font(.title3)
                .frame(width: 28)
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
        let state = DaymarkStatus.state(anchor: item.startDate, repeat: item.repeatCycle,
                                        reference: .now, calendar: DateMath.userCalendar())
        switch state.phase {
        case .today:
            return Text("countdown.today")
        case .upcoming(let days):
            return Text("countdown.daysLeft \(days)")
        case .elapsed(let days):
            return Text("countdown.daysPassed \(days)")
        }
    }
}
