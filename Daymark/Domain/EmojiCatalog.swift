import Foundation

/// 内置 Emoji 目录:分类 JSON 随 bundle 分发,不依赖系统 Emoji 面板
struct EmojiCatalog: Codable, Equatable, Sendable {
    struct Category: Codable, Equatable, Sendable, Identifiable {
        let id: String
        let emojis: [String]
    }

    /// 常用区(表单顶部直达)
    let frequent: [String]
    let categories: [Category]

    /// 从 bundle 加载;缺失或损坏时回退到内置最小目录
    static func load(bundle: Bundle = .main) -> EmojiCatalog {
        guard let url = bundle.url(forResource: "EmojiCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(EmojiCatalog.self, from: data),
              !catalog.categories.isEmpty else {
            return fallback
        }
        return catalog
    }

    /// 分类展示文案 key
    var categoryLabelKey: (Category) -> String { Self.labelKey(for:) }

    static func labelKey(for category: Category) -> String {
        "emoji.category.\(category.id)"
    }

    /// 兜底目录(资源异常时面板仍可用)
    static let fallback = EmojiCatalog(
        frequent: ["📌", "⭐️", "🎉", "❤️", "📅", "✈️"],
        categories: [
            Category(id: "objects",
                     emojis: ["📌", "📅", "⏰", "💼", "📚", "✏️", "🔑", "💡"]),
            Category(id: "symbols",
                     emojis: ["⭐️", "✨", "🔥", "💯", "✅", "🌈", "☀️", "🌙"]),
        ]
    )
}
