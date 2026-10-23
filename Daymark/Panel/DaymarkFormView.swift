import SwiftUI
import os.log

/// 创建/编辑复用的同一表单(Moment 式平铺行):
/// 头部 ← | 标题居中 | ✓ 保存;大 Emoji + 😊 选择按钮;名称小标签 + 大字输入;
/// 平铺行(日期/区间/时刻/重复/提醒/外观),细分割线。
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
    @State private var iconImageData: Data?
    @State private var cropSourceImage: NSImage?
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
            _iconImageData = State(initialValue: item.iconImageData)
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

    /// 可选提前提醒天数
    static let remindDayOptions = [1, 2, 3, 7, 14, 30]
    private static let iconLog = Logger(subsystem: "app.louvane.Daymark", category: "icon")

    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(showsIndicators: false) {
                content
            }
        }
        .animation(.easeOut(duration: 0.18), value: showsEmojiPicker)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .windowToolbar)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .navigationTitle("")
    }

    /// 表单内容(抽离以便快照测试直接渲染)。
    /// Emoji 选择器紧贴 Emoji 行下方展开——放表单尾部会滚出可视区,看起来像点击无效。
    @ViewBuilder
    var content: some View {
        VStack(spacing: 0) {
            emojiRow
            if showsEmojiPicker {
                VStack(spacing: 8) {
                    EmojiPickerView(selection: $emoji, onDone: { withAnimation(.easeOut(duration: 0.15)) { showsEmojiPicker = false } })
                }
                .padding(12)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .scale(0.96, anchor: .top)))
            }
            Divider().padding(.leading, 14)
            colorRow
            Divider().padding(.leading, 14)
            nameSection
            Divider().padding(.leading, 14)
            formRows
        }
        .padding(.vertical, 6)
    }

    /// 头部:← | 标题居中 | ✓ 保存
    var header: some View {
        ZStack {
            Text(LocalizedStringKey(mode == .create ? "form.title.create" : "form.title.edit"))
                .font(.headline)
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(HoverIconButtonStyle())
                .help(Text("common.back"))
                Spacer()
                Button(action: save) {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(cleanedName.isEmpty ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(HoverIconButtonStyle())
                .disabled(cleanedName.isEmpty)
                .help(Text("form.action.save"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 图标行:Emoji/图片二选一——大图即选择器开关;右侧图片导入/移除按钮
    private var emojiRow: some View {
        HStack {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    showsEmojiPicker.toggle()
                    iconImageData = nil // 回到 Emoji 模式(选 Emoji 即弃用图片)
                }
            } label: {
                iconPreview
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(HoverIconButtonStyle())
            .help(Text("form.emoji.pick"))
            Spacer()
            // 状态指示:选择器展开时显示收起箭头
            if showsEmojiPicker {
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // 导入图片 / 移除图片
            Button {
                if iconImageData != nil {
                    iconImageData = nil
                } else {
                    IconImage.pickFromPanel { data in
                        Self.iconLog.info("表单收到图片数据 \(data.count) bytes,进入裁剪")
                        withAnimation(.easeOut(duration: 0.15)) {
                            cropSourceImage = NSImage(data: data)
                            showsEmojiPicker = false
                        }
                    }
                }
            } label: {
                Image(systemName: iconImageData != nil ? "photo.badge.xmark" : "photo")
                    .font(.system(size: 14))
            }
            .buttonStyle(HoverIconButtonStyle())
            .help(Text(iconImageData != nil ? "form.icon.remove" : "form.icon.import"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 大图标预览:有图显示圆角图,否则显示 Emoji
    @ViewBuilder
    private var iconPreview: some View {
        if let data = iconImageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Text(emoji)
                .font(.system(size: 40))
        }
    }

    /// 颜色行:预设色板右对齐,选中圆点外圈描边
    private var colorRow: some View {
        formRow(labelKey: "form.field.color") {
            HStack(spacing: 6) {
                ForEach(0..<DaymarkColorPalette.count, id: \.self) { index in
                    Circle()
                        .fill(DaymarkColorPalette.color(at: index))
                        .frame(width: 14, height: 14)
                        .overlay {
                            if index == DaymarkColorPalette.normalizedIndex(colorIndex) {
                                Circle().strokeBorder(.primary, lineWidth: 1.5).padding(-2)
                            }
                        }
                        .onTapGesture { colorIndex = index }
                }
            }
        }
    }

    /// 名称:小标签 + 大字无边框输入
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("form.field.name")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("form.field.name.placeholder", text: $name)
                .textFieldStyle(.plain)
                .font(.title3.bold())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 平铺表单行
    private var formRows: some View {
        VStack(spacing: 0) {
            formRow(labelKey: "form.field.date") {
                DatePicker("", selection: $date,
                           displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                    .labelsHidden()
            }
            Divider().padding(.leading, 14)
            formRow(labelKey: "form.field.hasTime") {
                Toggle("", isOn: $hasTime)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            Divider().padding(.leading, 14)
            if isRange {
                formRow(labelKey: "form.field.end") {
                    DatePicker("", selection: $endDate, in: date...,
                               displayedComponents: [.date])
                        .labelsHidden()
                }
                Divider().padding(.leading, 14)
            }
            formRow(labelKey: "form.field.range") {
                Toggle("", isOn: $isRange)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            Divider().padding(.leading, 14)
            formRow(labelKey: "form.field.repeat") {
                FormDropdown(titleKey: "form.field.repeat",
                             options: RepeatCycle.allCases.map {
                                 (value: $0, label: Text(LocalizedStringKey($0.labelKey)))
                             },
                             selection: $repeatCycle)
            }
            Divider().padding(.leading, 14)
            formRow(labelKey: "form.field.remind") {
                Picker("", selection: $remindDays) {
                    Text("remind.none").tag(0)
                    ForEach(Self.remindDayOptions, id: \.self) { days in
                        Text("remind.daysBefore \(days)").tag(days)
                    }
                }
                .labelsHidden()
                .frame(width: 118)
            }
        }
    }

    /// 标签左、控件右的平铺行
    private func formRow(labelKey: LocalizedStringKey,
                         control: @escaping () -> some View) -> some View {
        HStack {
            Text(labelKey)
            Spacer()
            control()
        }
        .font(.callout)
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
                              emoji: emoji, iconImageData: iconImageData,
                              colorIndex: colorIndex,
                              endDate: validatedEnd, hasTime: hasTime,
                              repeatCycle: repeatCycle, remindDays: remindDays))
        case .edit(let item):
            item.name = cleanedName
            item.startDate = date
            item.emoji = emoji
            item.iconImageData = iconImageData
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
