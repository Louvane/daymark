import SwiftUI

// 面板:点击菜单栏图标弹出的主操作入口(票 01 为占位,票 02 起替换为列表)
struct PanelView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("panel.placeholder.title")
                .font(.headline)
            Text("panel.placeholder.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // 票 02 起启用创建入口
            Button {
            } label: {
                Image(systemName: "plus")
            }
            .disabled(true)
        }
        .padding(16)
        .frame(width: 320, height: 200)
    }
}
