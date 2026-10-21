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

    /// 编辑模式从既有 Daymark 预填,创建模式用默认值
    init(mode: Mode, onBack: @escaping () -> Void) {
        self.mode = mode
        self.onBack = onBack
        if case .edit(let item) = mode {
            _name = State(initialValue: item.name)
            _date = State(initialValue: item.startDate)
            _repeatCycle = State(initialValue: item.repeatCycle)
            _remindDays = State(initialValue: item.remindDays)
            _emoji = State(initialValue: item.emoji)
            _colorIndex = State(initialValue: item.colorIndex)
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
                DatePicker("form.field.date", selection: $date, displayedComponents: [.date])
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

    private func save() {
        switch mode {
        case .create:
            store.add(Daymark(name: cleanedName, date: date,
                              emoji: emoji, colorIndex: colorIndex,
                              repeatCycle: repeatCycle, remindDays: remindDays))
        case .edit(let item):
            item.name = cleanedName
            item.startDate = date
            item.emoji = emoji
            item.colorIndex = colorIndex
            item.repeatCycle = repeatCycle
            item.remindDays = remindDays
            store.update(item)
        }
        onBack()
    }
}
