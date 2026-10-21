import SwiftUI

/// 详情页:完整字段展示 + 编辑/删除入口(删除带确认)
struct DaymarkDetailView: View {
    let item: Daymark
    /// 删除完成后由面板收窄路径回列表
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showsDeleteConfirm = false

    private var state: DaymarkDisplayState {
        item.displayState()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 14) {
                    countdownCard
                    fieldsCard
                }
                .padding(14)
            }
        }
        .confirmationDialog(
            Text("detail.delete.confirm.title"),
            isPresented: $showsDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("detail.action.delete", role: .destructive) {
                onDelete()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("detail.delete.confirm.subtitle")
        }
    }

    private var header: some View {
        HStack {
            Text("detail.title")
                .font(.headline)
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help(Text("detail.action.edit"))
            Button {
                showsDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help(Text("detail.action.delete"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// 大字号天数状态卡
    private var countdownCard: some View {
        VStack(spacing: 6) {
            Text(item.emoji)
                .font(.system(size: 40))
            phaseText
                .font(.title2.bold())
            if item.hasTime {
                Text(item.startDate, format: .dateTime.year().month().day().weekday().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(item.startDate, format: .dateTime.year().month().day().weekday())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            DaymarkColorPalette.color(at: item.colorIndex).opacity(0.18),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private var phaseText: Text {
        countdownLabel(state.phase)
    }

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            fieldRow(labelKey: "detail.field.name", value: item.name)
            Divider().padding(.leading, 14)
            fieldRow(labelKey: "detail.field.date") {
                if item.hasTime {
                    Text(item.startDate, format: .dateTime.year().month().day().hour().minute())
                } else {
                    Text(item.startDate, format: .dateTime.year().month().day())
                }
            }
            if let end = item.endDate {
                Divider().padding(.leading, 14)
                fieldRow(labelKey: "detail.field.range") {
                    Text("\(item.startDate.formatted(date: .abbreviated, time: .omitted)) – \(end.formatted(date: .abbreviated, time: .omitted))")
                        .lineLimit(1)
                }
            }
            if item.repeatCycle != .none {
                Divider().padding(.leading, 14)
                fieldRow(labelKey: "form.field.repeat") {
                    Text(LocalizedStringKey(item.repeatCycle.labelKey))
                }
            }
            if item.remindDays > 0 {
                Divider().padding(.leading, 14)
                fieldRow(labelKey: "detail.field.remind") {
                    Text("remind.daysBefore \(item.remindDays)")
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
