import SwiftUI

/// 天数状态 → 本地化文案(列表行与详情共用)
func countdownLabel(_ phase: DaymarkDisplayState.Phase) -> Text {
    switch phase {
    case .today:
        return Text("countdown.today")
    case .upcoming(let days):
        return Text("countdown.daysLeft \(days)")
    case .elapsed(let days):
        return Text("countdown.daysPassed \(days)")
    case .range(.notStarted(let days)):
        return Text("range.notStarted \(days)")
    case .range(.inProgress(let day, let total)):
        return Text("range.inProgress \(day) \(total)")
    case .range(.ended(let days)):
        return Text("range.ended \(days)")
    }
}
