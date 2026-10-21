import Foundation

/// daymark://create 预填载荷(缺参字段为 nil,安全降级)
struct DaymarkURLPayload: Equatable, Hashable, Sendable {
    var name: String?
    var date: Date?
    var repeatCycle: RepeatCycle?
}

/// daymark:// 链接解析(纯函数):daymark://create?name=…&date=…&repeat=…
/// 参数非法时对应字段为 nil(空表单安全降级),整体非法返回 nil(忽略链接)
enum DaymarkURLParser {
    /// 名称长度上限(防恶意超长输入)
    static let nameLengthLimit = 200
    private static let isoDateFormat = "yyyy-MM-dd"

    static func parse(_ url: URL, calendar: Calendar) -> DaymarkURLPayload? {
        guard url.scheme?.lowercased() == "daymark",
              url.host?.lowercased() == "create" else { return nil }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            queryItems.first { $0.name.lowercased() == name }?.value
        }

        var payload = DaymarkURLPayload()

        // 名称:去空白、非空、限长
        if let rawName = value("name")?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawName.isEmpty {
            payload.name = String(rawName.prefix(nameLengthLimit))
        }

        // 日期:固定 ISO yyyy-MM-dd,按目标日历构造当天(避免时区偏移日界)
        if let rawDate = value("date") {
            payload.date = parseDate(rawDate, calendar: calendar)
        }

        // 重复周期:枚举白名单
        if let rawRepeat = value("repeat"), let cycle = RepeatCycle(rawValue: rawRepeat.lowercased()) {
            payload.repeatCycle = cycle
        }

        return payload
    }

    private static func parseDate(_ string: String, calendar: Calendar) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 9
        return calendar.date(from: comps)
    }
}
