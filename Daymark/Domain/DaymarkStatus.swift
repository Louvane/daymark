import Foundation

/// Daymark 的展示态:由(锚定日、可选结束日、重复周期、参考日)推导,UI 只做文案映射
struct DaymarkDisplayState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// 就是今天(当天=剩 0 天)
        case today
        /// 还剩 N 天
        case upcoming(daysLeft: Int)
        /// 已过去 N 天
        case elapsed(daysElapsed: Int)
        /// 日期区间(票 07)
        case range(DaymarkRangePhase)
    }

    /// 当前面向的发生日(重复 Daymark 为下一次发生,非重复为锚定日;区间为开始日)
    let occurrence: Date
    let phase: Phase
}

/// 区间相位
enum DaymarkRangePhase: Equatable, Sendable {
    case notStarted(daysUntilStart: Int)
    case inProgress(dayNumber: Int, totalDays: Int)
    case ended(daysSinceEnd: Int)
}

enum DaymarkStatus {
    /// 状态判定:有效区间走区间分支(票 07);单日先滚动到下一次发生(票 04)再分三态
    static func state(anchor: Date, end: Date? = nil, repeat: RepeatCycle,
                      reference: Date, calendar: Calendar) -> DaymarkDisplayState {
        if let end, DateMath.daysBetween(anchor, end, in: calendar) >= 0 {
            return rangeState(anchor: anchor, end: end, repeat: `repeat`,
                              reference: reference, calendar: calendar)
        }

        let occurrence = DateMath.nextOccurrence(anchor: anchor, repeat: `repeat`,
                                                 reference: reference, calendar: calendar)
        let phase: DaymarkDisplayState.Phase
        let diff = DateMath.daysBetween(reference, occurrence, in: calendar)
        if diff == 0 {
            phase = .today
        } else if diff > 0 {
            phase = .upcoming(daysLeft: diff)
        } else {
            phase = .elapsed(daysElapsed: -diff)
        }
        return DaymarkDisplayState(occurrence: occurrence, phase: phase)
    }

    /// 区间状态:重复仅按开始日滚动,区间长度不变(票 07 钉死的行为)
    static func rangeState(anchor: Date, end: Date, repeat: RepeatCycle,
                           reference: Date, calendar: Calendar) -> DaymarkDisplayState {
        let occurrenceStart = DateMath.nextOccurrence(anchor: anchor, repeat: `repeat`,
                                                      reference: reference, calendar: calendar)
        let occurrenceEnd: Date
        if `repeat` == .none {
            occurrenceEnd = end
        } else {
            let length = DateMath.daysBetween(anchor, end, in: calendar)
            occurrenceEnd = calendar.date(byAdding: .day, value: length, to: occurrenceStart) ?? end
        }
        let phase = rangePhase(start: occurrenceStart, end: occurrenceEnd,
                               reference: reference, calendar: calendar)
        return DaymarkDisplayState(occurrence: occurrenceStart, phase: .range(phase))
    }

    /// 区间三态:未开始/进行中(第 X 天/共 Y 天)/已结束
    static func rangePhase(start: Date, end: Date,
                           reference: Date, calendar: Calendar) -> DaymarkRangePhase {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let refDay = calendar.startOfDay(for: reference)
        if refDay < startDay {
            return .notStarted(daysUntilStart: DateMath.daysBetween(refDay, startDay, in: calendar))
        }
        if refDay > endDay {
            return .ended(daysSinceEnd: DateMath.daysBetween(endDay, refDay, in: calendar))
        }
        let dayNumber = DateMath.daysBetween(startDay, refDay, in: calendar) + 1
        let totalDays = DateMath.daysBetween(startDay, endDay, in: calendar) + 1
        return .inProgress(dayNumber: dayNumber, totalDays: totalDays)
    }
}

/// 排序方式(展示偏好,AppSettings 持久化)
enum DaymarkSortMode: String, Sendable {
    case upcoming
    case manual
}

enum DaymarkSort {
    /// 「最近将到」排序:今天/进行中按发生日升序,已过去按发生日降序(最近过去的在前)垫底。
    /// 先为每项算一次展示态再排序,避免比较器内 O(n log n) 次重复推导。
    static func upcoming(_ items: [Daymark], reference: Date, calendar: Calendar) -> [Daymark] {
        items
            .map { (item: $0, state: $0.displayState(reference: reference, calendar: calendar)) }
            .sorted { lhs, rhs in
                let (lRank, rRank) = (rank(of: lhs.state), rank(of: rhs.state))
                if lRank != rRank { return lRank < rRank }
                if lRank == 2 { return lhs.state.occurrence > rhs.state.occurrence } // 已过去:最近的在前
                return lhs.state.occurrence < rhs.state.occurrence
            }
            .map(\.item)
    }

    /// 手动排序:按 sortWeight 升序(同权重按创建顺序稳定)
    static func manual(_ items: [Daymark]) -> [Daymark] {
        items.sorted { lhs, rhs in
            if lhs.sortWeight != rhs.sortWeight {
                return lhs.sortWeight < rhs.sortWeight
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// 拖拽完成后按新顺序重排权重(0..n-1)
    static func applyManualOrder(_ moved: [Daymark], save: () -> Void) {
        for (index, item) in moved.enumerated() {
            item.sortWeight = Double(index)
        }
        save()
    }

    private static func rank(of state: DaymarkDisplayState) -> Int {
        switch state.phase {
        case .today, .range(.inProgress): return 0
        case .upcoming, .range(.notStarted): return 1
        case .elapsed, .range(.ended): return 2
        }
    }
}
