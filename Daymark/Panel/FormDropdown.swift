import SwiftUI

/// 自绘下拉:替代 NSPopUpButton 桥接(其固有宽度不受 frame 约束,导致行间
/// 宽度不一/右缘不齐)。宽度统一,右对齐,展开浮层与排序菜单同风格。
struct FormDropdown<Value: Hashable>: View {
    let titleKey: LocalizedStringKey
    let options: [(value: Value, label: Text)]
    @Binding var selection: Value
    var width: CGFloat = 118

    @State private var expanded = false

    var body: some View {
        buttonView
            .overlay(alignment: .top) {
                if expanded {
                    ZStack(alignment: .topTrailing) {
                        Color.clear
                            .contentShape(Rectangle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onTapGesture { withAnimation(.easeOut(duration: 0.12)) { expanded = false } }
                        menuView
                            .offset(y: 28)
                    }
                }
            }
    }

    private var buttonView: some View {
        Button {
            withAnimation(.easeOut(duration: 0.12)) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                selectedOptionLabel.font(.callout)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .frame(width: width, height: 26, alignment: .trailing)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.primary.opacity(expanded ? 0.09 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedOptionLabel: some View {
        if let hit = options.first(where: { $0.value == selection }) {
            hit.label
        } else {
            Text(titleKey)
        }
    }

    private var menuView: some View {
        VStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                Button {
                    selection = option.value
                    withAnimation(.easeOut(duration: 0.12)) { expanded = false }
                } label: {
                    HStack {
                        option.label
                        Spacer()
                        if option.value == selection {
                            Image(systemName: "checkmark").font(.caption)
                        }
                    }
                    .font(.callout)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(width: width + 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    option.value == selection
                        ? Color.primary.opacity(0.06)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color(nsColor: .separatorColor).opacity(0.4)))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
