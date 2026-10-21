import XCTest
@testable import Daymark

/// 票 06:外观自定义 —— Emoji 目录与手动排序
@MainActor
final class AppearanceTests: XCTestCase {
    // MARK: - Emoji 目录

    func testCatalogLoadsFromBundle() {
        let catalog = EmojiCatalog.load(bundle: .main)
        XCTAssertFalse(catalog.categories.isEmpty)
        XCTAssertFalse(catalog.frequent.isEmpty)
        XCTAssertTrue(catalog.categories.allSatisfy { !$0.emojis.isEmpty })
    }

    func testCatalogFallsBackWhenResourceMissing() {
        let emptyBundle = Bundle(for: Self.self)
        // 测试 bundle 无 EmojiCatalog.json → 回退目录
        let catalog = EmojiCatalog.load(bundle: emptyBundle)
        XCTAssertEqual(catalog, EmojiCatalog.fallback)
    }

    func testCatalogDecodesFromData() throws {
        let json = Data(#"""
        {
          "frequent": ["📌"],
          "categories": [{"id": "objects", "emojis": ["📌", "📅"]}]
        }
        """#.utf8)
        let catalog = try JSONDecoder().decode(EmojiCatalog.self, from: json)
        XCTAssertEqual(catalog.frequent, ["📌"])
        XCTAssertEqual(catalog.categories.first?.id, "objects")
        XCTAssertEqual(catalog.categories.first?.emojis, ["📌", "📅"])
    }

    // MARK: - 手动排序

    func testManualSortBySortWeight() {
        let first = Daymark(name: "一", date: .now, sortWeight: 0)
        let third = Daymark(name: "三", date: .now, sortWeight: 2)
        let second = Daymark(name: "二", date: .now, sortWeight: 1)

        let sorted = DaymarkSort.manual([third, first, second])
        XCTAssertEqual(sorted.map(\.name), ["一", "二", "三"])
    }

    func testApplyManualOrderRewritesWeights() {
        let a = Daymark(name: "A", date: .now, sortWeight: 0)
        let b = Daymark(name: "B", date: .now, sortWeight: 1)
        let c = Daymark(name: "C", date: .now, sortWeight: 2)

        // 拖 C 到最前
        DaymarkSort.applyManualOrder([c, a, b], save: {})
        XCTAssertEqual([a.sortWeight, b.sortWeight, c.sortWeight], [1, 2, 0])
    }

    // MARK: - 预设色板

    func testColorPaletteClampsIndex() {
        XCTAssertGreaterThanOrEqual(DaymarkColorPalette.count, 5)
        XCTAssertEqual(DaymarkColorPalette.normalizedIndex(-1), DaymarkColorPalette.normalizedIndex(DaymarkColorPalette.count - 1))
        XCTAssertEqual(DaymarkColorPalette.normalizedIndex(0), 0)
    }
}
