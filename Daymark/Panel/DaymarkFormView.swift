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

    /// 编辑模式从既有 Daymark 预填,创建模式用默认值
    init(mode: Mode, onBack: @escaping () -> Void) {
        self.mode = mode
        self.onBack = onBack
        if case .edit(let item) = mode {
            _name = State(initialValue: item.name)
            _date = State(initialValue: item.startDate)
            _repeatCycle = State(initialValue: item.repeatCycle)
        }
    }

    private var cleanedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
            store.add(Daymark(name: cleanedName, date: date, repeatCycle: repeatCycle))
        case .edit(let item):
            item.name = cleanedName
            item.startDate = date
            item.repeatCycle = repeatCycle
            store.update(item)
        }
        onBack()
    }
}
