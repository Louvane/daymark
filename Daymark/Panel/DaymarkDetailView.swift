import SwiftUI

/// 详情页(Moment 式 hero):居中菱形 Emoji 框 → 名称 → 日期·天数 → 超大数字块 → 字段卡。
/// 渲染只用值快照:确认删除后模型即刻失效,出栈动画期间的任何重渲染
/// 都不再触碰 SwiftData 对象(否则闪退,本地实测复现)。
struct DaymarkDetailView: View {
    struct Snapshot {
        let name: String
        let emoji: String
        let iconImageData: Data?
        let colorIndex: Int
        let startDate: Date
        let endDate: Date?
        let hasTime: Bool
        let repeatCycle: RepeatCycle
        let remindDays: Int

        init(from item: Daymark) {
            name = item.name
            emoji = item.emoji
            iconImageData = item.iconImageData
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
            ScrollView(showsIndicators: false) {
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .windowToolbar)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("") // 压掉 macOS 自动挂的窗口工具栏编辑按钮
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
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 24) // 底部呼吸空间:字段卡不再贴面板边缘
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

    /// Hero 图标:有图显示圆照,否则 Emoji
    @ViewBuilder
    private var heroIcon: some View {
        if let data = snapshot.iconImageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(Circle())
        } else {
            Text(snapshot.emoji)
                .font(.system(size: 40))
        }
    }

    /// Hero:双层菱形装饰(内层实底方承载图标,外层旋转 45° 菱形描边)→ 名称 → 日期 · 天数
    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                // 外层:旋转 45° 菱形描边
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                    .frame(width: 118, height: 118)
                    .rotationEffect(.degrees(45))
                // 内层:实底圆角方(承载图标/照片)
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
                    .frame(width: 92, height: 92)
                heroIcon
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
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1))
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
