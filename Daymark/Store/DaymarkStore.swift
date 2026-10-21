import Foundation
import SwiftData

/// 仓储(领域接缝 2 的宿主):CRUD + 后续提醒重排钩子。UI 层只与它对话。
@MainActor
@Observable
final class DaymarkStore {
    let container: ModelContainer
    private let context: ModelContext
    /// 提醒重排协调器(nil = 不排提醒,纯测试场景)
    private var rescheduler: ReminderRescheduler?

    /// 应用运行时:默认持久化位置,附带真实通知调度
    init(scheduler: any ReminderScheduling = UserNotificationScheduler()) throws {
        let container = try ModelContainer(for: Daymark.self)
        self.container = container
        self.context = container.mainContext
        context.autosaveEnabled = false
        self.rescheduler = ReminderRescheduler(scheduler: scheduler)
    }

    /// 测试/预览:in-memory,可注入假调度器
    init(inMemory: Bool, scheduler: (any ReminderScheduling)? = nil) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: Daymark.self, configurations: config)
        self.container = container
        self.context = ModelContext(container)
        context.autosaveEnabled = false
        self.rescheduler = scheduler.map { ReminderRescheduler(scheduler: $0) }
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
        scheduleResync()
    }

    /// 编辑已跟踪对象后调用;同时刷新 updatedAt
    func update(_ daymark: Daymark) {
        daymark.updatedAt = .now
        save()
        scheduleResync()
    }

    func delete(_ daymark: Daymark) {
        context.delete(daymark)
        save()
        scheduleResync()
    }

    /// 数据变更后全量重排(先清后加,幂等);测试可直接 await 精确断言
    func rescheduleReminders() async {
        guard let rescheduler,
              let facts = try? fetchAll().map(\.reminderFacts) else { return }
        await rescheduler.rescheduleAll(facts)
    }

    /// 测试辅助:把变更触发的重排任务等完;无遗留任务则显式跑一轮
    func flushResync() async {
        if let task = resyncTask {
            resyncTask = nil
            await task.value
        } else {
            await rescheduleReminders()
        }
    }

    @ObservationIgnored private var resyncTask: Task<Void, Never>?

    private func scheduleResync() {
        guard rescheduler != nil else { return }
        resyncTask?.cancel()
        resyncTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            await self?.rescheduleReminders()
        }
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
