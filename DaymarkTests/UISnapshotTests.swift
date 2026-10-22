import XCTest
import SwiftUI
import AppKit
@testable import Daymark

/// UI 快照:用 ImageRenderer 把真实视图离屏渲染成 PNG(无需屏幕录制权限),
/// 供人工比对排版稿(.scratch/daymark-v1/ui-mockups.html)。
/// 产物目录:/tmp/daymark-ui/
@MainActor
final class UISnapshotTests: XCTestCase {
    private let outDir = URL(fileURLWithPath: "/tmp/daymark-ui", isDirectory: true)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    private func render(_ view: some View, name: String, width: CGFloat = 320, height: CGFloat = 440) throws {
        let renderer = ImageRenderer(content: view
            .frame(width: width, height: height)
            .environment(\.colorScheme, .light)
            .background(Color(nsColor: .windowBackgroundColor)))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("渲染失败: \(name)")
            return
        }
        try png.write(to: outDir.appending(path: name + ".png"))
    }

    private func makeStore(items: [(String, String, Int, Date, Date?, RepeatCycle, Bool, Int)]) throws -> DaymarkStore {
        let store = try DaymarkStore(inMemory: true)
        for (name, emoji, color, start, end, cycle, hasTime, remind) in items {
            store.add(Daymark(name: name, date: start, emoji: emoji, colorIndex: color,
                              endDate: end, hasTime: hasTime, repeatCycle: cycle, remindDays: remind))
        }
        return store
    }

    func testRenderAllScreens() throws {
        let cal = DateMath.userCalendar()
        let now = Date.now

        func day(_ offset: Int) -> Date {
            cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now))!
        }

        // 覆盖全部相位:今天 / 未来 / 区间进行中 / 每年已过去(滚动)
        let store = try makeStore(items: [
            ("项目上线", "🎯", 9, day(0), nil, .none, false, 0),
            ("生日", "🎂", 0, day(63), nil, .yearly, false, 1),
            ("日本旅行", "✈️", 1, day(10), day(14), .none, false, 0),
            ("成立纪念日", "🎉", 6, day(-2196), nil, .yearly, false, 0),
        ])
        let settings = AppSettings(defaults: UserDefaults(suiteName: "uisnapshot")!)

        let items = try store.fetchAll()

        // ① 列表行(ImageRenderer 不渲染 LazyVStack/ScrollView,直接摆行)
        // 1a:右键删除确认态叠在第一行
        let rows = VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                if pair.offset == 1 {
                    DaymarkListRow(snapshot: .init(from: pair.element), confirmingDelete: true,
                                   onOpen: {}, onEdit: {}, onDeleteRequest: {},
                                   onCancelDelete: {}, onConfirmDelete: {})
                } else {
                    DaymarkListRow(snapshot: .init(from: pair.element), confirmingDelete: false,
                                   onOpen: {}, onEdit: {}, onDeleteRequest: {},
                                   onCancelDelete: {}, onConfirmDelete: {})
                }
                Divider().padding(.leading, 46)
            }
        }
        .padding(.horizontal, 12)
        try render(rows, name: "1-list")

        // ② 详情(header + content,无 ScrollView)
        let first = try store.fetchAll().first { $0.name == "生日" }!
        let detail = DaymarkDetailView(item: first, onBack: {}, onEdit: {}, onDelete: {})
        try render(VStack(spacing: 0) { detail.header; Divider(); detail.content },
                   name: "2-detail")

        // ③ 表单 · 新建
        let createForm = DaymarkFormView(mode: .create, onBack: {})
        try render(VStack(spacing: 0) { createForm.header; Divider(); createForm.content },
                   name: "3-form-create")

        // ④ 表单 · 编辑(区间开)
        let trip = try store.fetchAll().first { $0.name == "日本旅行" }!
        let editForm = DaymarkFormView(mode: .edit(trip), onBack: {})
        try render(VStack(spacing: 0) { editForm.header; Divider(); editForm.content },
                   name: "4-form-edit")

        // 清理临时 suite
        UserDefaults(suiteName: "uisnapshot")?.removePersistentDomain(forName: "uisnapshot")
    }
}
