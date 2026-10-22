import SwiftUI

/// 详情页(Moment 式 hero):居中菱形 Emoji 框 → 名称 → 日期·天数 → 超大数字块 → 字段卡。
/// 渲染只用值快照:确认删除后模型即刻失效,出栈动画期间的任何重渲染
/// 都不再触碰 SwiftData 对象(否则闪退,本地实测复现)。
struct DaymarkDetailView: View {
    struct Snapshot {
        let name: String
        let emoji: String
        let colorIndex: Int
        let startDate: Date
        let endDate: Date?
        let hasTime: Bool
        let repeatCycle: RepeatCycle
        let remindDays: Int

        init(from item: Daymark) {
            name = item.name
            emoji = item.emoji
            colorIndex = item.colorIndex
            startDate = item.startDate
            endDate = item.endDate
            hasTime = item.hasTime
            repeatCycle = item.repeatCycle
            remindDays = item.remindDays
        }

        var displayState: DaymarkDisplayState {
            DaymarkStatus.state(anchor: startDate, end: endDate, repeat: repeatCycle,
                                reference: .now, calendar: DateMath.userCalendar())
        }
    }

    let snapshot: Snapshot
    let onBack: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    init(item: Daymark, onBack: @escaping () -> Void,
         onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.snapshot = Snapshot(from: item)
        self.onBack = onBack
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    /// 两段式删除:点垃圾桶进入内联确认,再点删除才真删(面板内禁用系统弹层)
    @State private var confirmingDelete = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    /// 滚动内容(抽离以便快照测试直接渲染,绕过 ScrollView 的 ImageRenderer 限制)
    var content: some View {
        VStack(spacing: 16) {
            if confirmingDelete {
                confirmBar
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            hero
            numberBlock
            fieldsCard
        }
        .padding(16)
    }

    /// 内联确认条(替代系统 confirmationDialog)
    private var confirmBar: some View {
        HStack(spacing: 10) {
            Text("detail.delete.confirm.title")
                .font(.callout.bold())
                .foregroundStyle(.red)
            Spacer()
            Button("common.cancel") {
                confirmingDelete = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button("detail.action.delete") {
                onDelete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
        }
        .padding(10)
        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    /// 头部:← 返回 | 标题居中 | 编辑(文字)+ 删除(红)
    var header: some View {
        ZStack {
            Text("detail.title")
                .font(.headline)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help(Text("common.back"))
                Spacer()
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Text("detail.action.edit")
                            .font(.callout)
                    }
                    .buttonStyle(HoverIconButtonStyle())
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { confirmingDelete = true }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(HoverIconButtonStyle())
                    .help(Text("detail.action.delete"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// Hero:菱形装饰框包大 Emoji → 名称 → 日期 · 天数
    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                    .frame(width: 86, height: 86)
                    .rotationEffect(.degrees(45))
                Text(snapshot.emoji)
                    .font(.system(size: 44))
            }
            .padding(.vertical, 4)

            Text(snapshot.name)
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            metaLine
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 元信息:日期 · 已持续/剩余天数
    private var metaLine: Text {
        let days = DateMath.daysBetween(snapshot.startDate, .now, in: DateMath.userCalendar())
        let dateText = snapshot.startDate.formatted(date: .long, time: .omitted)
        if days >= 0 {
            return Text("\(dateText) · " + String(localized: "detail.meta.daysSince \(days)"))
        }
        return Text(dateText)
    }

    /// 超大数字块(Moment 式):灰底圆角矩形,主数字 + 单位
    private var numberBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(badgeNumber)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(badgeUnit)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var badgeNumber: String {
        switch snapshot.displayState.phase {
        case .today: return "0"
        case .upcoming(let n): return "\(n)"
        case .elapsed(let n): return "\(n)"
        case .range(.notStarted(let n)): return "\(n)"
        case .range(.inProgress(let day, _)): return "\(day)"
        case .range(.ended(let n)): return "\(n)"
        }
    }

    private var badgeUnit: String {
        switch snapshot.displayState.phase {
        case .today, .upcoming, .elapsed, .range(.notStarted), .range(.ended):
            return String(localized: "list.unit.days")
        case .range(.inProgress(_, let total)):
            return String(localized: "meta.rangeTotal \(total)")
        }
    }

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            fieldRow(labelKey: "detail.field.name", value: snapshot.name)
            Divider().padding(.leading, 14)
            fieldRow(labelKey: "detail.field.date") {
                if snapshot.hasTime {
                    Text(snapshot.startDate, format: .dateTime.year().month().day().hour().minute())
                } else {
                    Text(snapshot.startDate, format: .dateTime.year().month().day())
                }
            }
            if let end = snapshot.endDate {
                Divider().padding(.leading, 14)
                fieldRow(labelKey: "detail.field.range") {
                    Text("\(snapshot.startDate.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                        .lineLimit(1)
                }
            }
            if snapshot.repeatCycle != .none {
                Divider().padding(.leading, 14)
                fieldRow(labelKey: "form.field.repeat") {
                    Text(LocalizedStringKey(snapshot.repeatCycle.labelKey))
                }
            }
            if snapshot.remindDays > 0 {
                Divider().padding(.leading, 14)
                fieldRow(labelKey: "detail.field.remind") {
                    Text("remind.daysBefore \(snapshot.remindDays)")
                }
            }
        }
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func fieldRow(labelKey: LocalizedStringKey, value: String) -> some View {
        fieldRow(labelKey: labelKey) {
            Text(value).lineLimit(1)
        }
    }

    private func fieldRow(labelKey: LocalizedStringKey, value: @escaping () -> some View) -> some View {
        HStack {
            Text(labelKey)
                .foregroundStyle(.secondary)
            Spacer()
            value()
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
