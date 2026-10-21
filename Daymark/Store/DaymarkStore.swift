import Foundation
import SwiftData

/// 仓储(领域接缝 2 的宿主):CRUD + 后续提醒重排钩子。UI 层只与它对话。
@MainActor
@Observable
final class DaymarkStore {
    let container: ModelContainer
    private let context: ModelContext

    /// 应用运行时:默认持久化位置
    init() throws {
        let container = try ModelContainer(for: Daymark.self)
        self.container = container
        self.context = container.mainContext
        context.autosaveEnabled = false
    }

    /// 测试/预览:in-memory
    init(inMemory: Bool) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: Daymark.self, configurations: config)
        self.container = container
        self.context = ModelContext(container)
        context.autosaveEnabled = false
    }

    /// 测试:指定磁盘位置(模拟「重启应用数据仍在」)
    init(at url: URL) throws {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(for: Daymark.self, configurations: config)
        self.container = container
        self.context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func add(_ daymark: Daymark) {
        context.insert(daymark)
        save()
    }

    /// 编辑已跟踪对象后调用;同时刷新 updatedAt
    func update(_ daymark: Daymark) {
        daymark.updatedAt = .now
        save()
    }

    func delete(_ daymark: Daymark) {
        context.delete(daymark)
        save()
    }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }

    /// 全量拉取(排序由 Domain 层负责,仓储不做业务排序)
    func fetchAll() throws -> [Daymark] {
        let descriptor = FetchDescriptor<Daymark>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor)
    }
}
