import SwiftUI

/// 创建/编辑复用的同一表单组件(票 03 起编辑模式启用)
struct DaymarkFormView: View {
    enum Mode: Equatable {
        case create
        case edit(Daymark)
    }

    let mode: Mode
    let onBack: () -> Void

    @Environment(DaymarkStore.self) private var store
    @State private var name = ""
    @State private var date = Date.now
    @State private var repeatCycle: RepeatCycle = .none
    @State private var remindDays = 0
    @State private var emoji = "📌"
    @State private var colorIndex = 0
    @State private var showsEmojiPicker = false
    @State private var isRange = false
    @State private var endDate = Date.now.addingTimeInterval(86_400)
    @State private var hasTime = false

    /// 编辑模式从既有 Daymark 预填;创建模式可携带 daymark:// 预填载荷(票 09),其余用默认值
    init(mode: Mode, prefill: DaymarkURLPayload? = nil, onBack: @escaping () -> Void) {
        self.mode = mode
        self.onBack = onBack
        switch mode {
        case .edit(let item):
            _name = State(initialValue: item.name)
            _date = State(initialValue: item.startDate)
            _repeatCycle = State(initialValue: item.repeatCycle)
            _remindDays = State(initialValue: item.remindDays)
            _emoji = State(initialValue: item.emoji)
            _colorIndex = State(initialValue: item.colorIndex)
            _isRange = State(initialValue: item.endDate != nil)
            _endDate = State(initialValue: item.endDate ?? item.startDate)
            _hasTime = State(initialValue: item.hasTime)
        case .create:
            if let prefill {
                _name = State(initialValue: prefill.name ?? "")
                _date = State(initialValue: prefill.date ?? .now)
                _repeatCycle = State(initialValue: prefill.repeatCycle ?? .none)
            }
        }
    }

    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 可选提前提醒天数
    static let remindDayOptions = [1, 2, 3, 7, 14, 30]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                TextField("form.field.name", text: $name, prompt: Text("form.field.name.placeholder"))
                DatePicker("form.field.date", selection: $date,
                           displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                Toggle("form.field.hasTime", isOn: $hasTime)
                Toggle("form.field.range", isOn: $isRange)
                if isRange {
                    DatePicker("form.field.end", selection: $endDate,
                               in: date...,
                               displayedComponents: [.date])
                }
                Picker("form.field.repeat", selection: $repeatCycle) {
                    ForEach(RepeatCycle.allCases) { cycle in
                        Text(LocalizedStringKey(cycle.labelKey)).tag(cycle)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                // 外观:Emoji + 颜色(票 06)
                HStack {
                    Text("form.field.appearance")
                        .foregroundStyle(.secondary)
                    Spacer()
                    // 当前 Emoji 预览,点击展开选择器
                    Button {
                        showsEmojiPicker.toggle()
                    } label: {
                        Text(emoji)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    // 预设色板
                    HStack(spacing: 5) {
                        ForEach(0..<DaymarkColorPalette.count, id: \.self) { index in
                            Circle()
                                .fill(DaymarkColorPalette.color(at: index))
                                .frame(width: 16, height: 16)
                                .overlay {
                                    if index == DaymarkColorPalette.normalizedIndex(colorIndex) {
                                        Circle().strokeBorder(.primary, lineWidth: 1.5).padding(-2)
                                    }
                                }
                                .onTapGesture { colorIndex = index }
                        }
                    }
                }
                if showsEmojiPicker {
                    EmojiPickerView(selection: $emoji, onDone: { showsEmojiPicker = false })
                }
                Picker("form.field.remind", selection: $remindDays) {
                    Text("remind.none").tag(0)
                    ForEach(Self.remindDayOptions, id: \.self) { days in
                        Text("remind.daysBefore \(days)").tag(days)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .help(Text("common.back"))
            Text(LocalizedStringKey(mode == .create ? "form.title.create" : "form.title.edit"))
                .font(.headline)
            Spacer()
            Button("form.action.save") { save() }
                .buttonStyle(.borderedProminent)
                .disabled(cleanedName.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 结束日校验:开启区间时结束 ≥ 开始(选择器已限下限,保存前再夹钳一次)
    private var validatedEnd: Date? {
        guard isRange else { return nil }
        let calendar = DateMath.userCalendar()
        return calendar.startOfDay(for: endDate) < calendar.startOfDay(for: date) ? date : endDate
    }

    private func save() {
        switch mode {
        case .create:
            store.add(Daymark(name: cleanedName, date: date,
                              emoji: emoji, colorIndex: colorIndex,
                              endDate: validatedEnd, hasTime: hasTime,
                              repeatCycle: repeatCycle, remindDays: remindDays))
        case .edit(let item):
            item.name = cleanedName
            item.startDate = date
            item.emoji = emoji
            item.colorIndex = colorIndex
            item.endDate = validatedEnd
            item.hasTime = hasTime
            item.repeatCycle = repeatCycle
            item.remindDays = remindDays
            store.update(item)
        }
        onBack()
    }
}
