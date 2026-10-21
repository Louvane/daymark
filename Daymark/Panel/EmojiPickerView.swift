import SwiftUI

/// Emoji 选择器:常用区 + 分类浏览,点击即选并预览
struct EmojiPickerView: View {
    @Binding var selection: String
    let onDone: () -> Void

    private let catalog = EmojiCatalog.load()
    @State private var selectedCategoryID = "" // onAppear 取第一个分类,避免首开空白

    var body: some View {
        VStack(spacing: 8) {
            // 预览 + 完成
            HStack {
                Text(selection)
                    .font(.title2)
                Spacer()
                Button("emoji.picker.done") { onDone() }
                    .controlSize(.small)
            }

            // 常用区
            if !catalog.frequent.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        emojiButtons(catalog.frequent, selected: selection) { selection = $0 }
                    }
                }
            }

            // 分类切换
            Picker("emoji.category.title", selection: $selectedCategoryID) {
                ForEach(catalog.categories) { category in
                    Text(LocalizedStringKey(EmojiCatalog.labelKey(for: category)))
                        .tag(category.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)

            // 当前分类网格
            if let category = catalog.categories.first(where: { $0.id == selectedCategoryID }) {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                        emojiButtons(category.emojis, selected: selection) { selection = $0 }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 130)
            }
        }
        .onAppear {
            // 初始选中第一个分类,避免首开分类网格空白
            if selectedCategoryID.isEmpty, let first = catalog.categories.first {
                selectedCategoryID = first.id
            }
        }
    }

    private func emojiButtons(_ emojis: [String], selected: String,
                              onSelect: @escaping (String) -> Void) -> some View {
        ForEach(emojis, id: \.self) { emoji in
            Button {
                onSelect(emoji)
            } label: {
                Text(emoji)
                    .font(.title3)
                    .frame(width: 32, height: 30)
                    .background(
                        emoji == selected
                            ? Color.accentColor.opacity(0.25)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
