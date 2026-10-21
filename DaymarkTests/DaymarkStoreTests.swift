import XCTest
import SwiftData
@testable import Daymark

/// 票 02:DaymarkStore 用 in-memory 容器验证 CRUD 与持久化重开
@MainActor
final class DaymarkStoreTests: XCTestCase {
    func testAddFetchDelete() throws {
        let store = try DaymarkStore(inMemory: true)
        let item = Daymark(name: "生日", date: Self.calendar.date(from: DateComponents(year: 2026, month: 12, day: 24))!)

        store.add(item)
        XCTAssertEqual(try store.fetchAll().count, 1)

        store.delete(item)
        XCTAssertEqual(try store.fetchAll().count, 0)
    }

    func testUpdatePersists() throws {
        let store = try DaymarkStore(inMemory: true)
        let item = Daymark(name: "旧名", date: Date.now)
        store.add(item)

        item.name = "新名"
        item.emoji = "🎂"
        store.save()

        let reloaded = try store.fetchAll()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.name, "新名")
        XCTAssertEqual(reloaded.first?.emoji, "🎂")
    }

    func testDeleteRemovesOnlyTarget() throws {
        let store = try DaymarkStore(inMemory: true)
        let a = Daymark(name: "A", date: .now)
        let b = Daymark(name: "B", date: .now)
        store.add(a)
        store.add(b)

        store.delete(a)
        let remaining = try store.fetchAll()
        XCTAssertEqual(remaining.map(\.name), ["B"])
    }

    /// 票 02 验收:重启应用数据仍在 —— 用磁盘容器重开模拟重启
    func testPersistenceAcrossStoreReopen() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "DaymarkStoreTests-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            let store = try DaymarkStore(at: url)
            store.add(Daymark(name: "纪念日", date: .now))
            store.save()
        }
        do {
            let reopened = try DaymarkStore(at: url)
            XCTAssertEqual(try reopened.fetchAll().map(\.name), ["纪念日"])
        }
    }

    static let calendar = DateMathTests.calendar
}
