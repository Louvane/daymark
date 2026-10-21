import Foundation

/// Daymark 的展示态:由(锚定日、重复周期、参考日)推导,UI 只做文案映射
struct DaymarkDisplayState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// 就是今天(当天=剩 0 天)
        case today
        /// 还剩 N 天
        case upcoming(daysLeft: Int)
        /// 已过去 N 天
        case elapsed(daysElapsed: Int)
    }

    /// 当前面向的发生日(重复 Daymark 为下一次发生,非重复为锚定日)
    let occurrence: Date
    let phase: Phase
}

enum DaymarkStatus {
    /// 单日 Daymark 的状态判定。重复滚动(票 04)由 nextOccurrence 提供,当前先直取锚定日。
    static func state(anchor: Date, repeat: RepeatCycle,
                      reference: Date, calendar: Calendar) -> DaymarkDisplayState {
        let occurrence = anchor
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
}

enum DaymarkSort {
    /// 「最近将到」排序:今天/未来按发生日升序,已过去按发生日降序(最近过去的在前)垫底
    static func upcoming(_ items: [Daymark], reference: Date, calendar: Calendar) -> [Daymark] {
        items.sorted { lhs, rhs in
            let l = DaymarkStatus.state(anchor: lhs.startDate, repeat: lhs.repeatCycle,
                                        reference: reference, calendar: calendar)
            let r = DaymarkStatus.state(anchor: rhs.startDate, repeat: rhs.repeatCycle,
                                        reference: reference, calendar: calendar)
            let lRank = rank(of: l)
            let rRank = rank(of: r)
            if lRank != rRank { return lRank < rRank }
            if lRank == 2 { return l.occurrence > r.occurrence } // 已过去:最近的在前
            return l.occurrence < r.occurrence
        }
    }

    private static func rank(of state: DaymarkDisplayState) -> Int {
        switch state.phase {
        case .today: return 0
        case .upcoming: return 1
        case .elapsed: return 2
        }
    }
}
