import SwiftUI

/// 预设色板:colorIndex 存模型,渲染时映射(SwiftUI Color 不可直接持久化)
enum DaymarkColorPalette {
    static let colors: [Color] = [
        .blue, .red, .orange, .yellow, .green,
        .teal, .purple, .pink, .indigo, .gray,
    ]

    static var count: Int { colors.count }

    /// 越界索引安全归一(历史数据/外部输入防御)
    static func normalizedIndex(_ index: Int) -> Int {
        guard count > 0 else { return 0 }
        let mapped = index % count
        return mapped < 0 ? mapped + count : mapped
    }

    static func color(at index: Int) -> Color {
        colors[normalizedIndex(index)]
    }
}
