import Foundation

/// 界面上的日期展示。格式逐字对齐原型。
public struct DateDisplay: Sendable {

    public let cal: DayCalendar

    public init(cal: DayCalendar = .current) { self.cal = cal }

    private static let weekdayNames = ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"]

    /// `2027年6月7日`
    public func long(_ date: Date) -> String {
        "\(cal.year(of: date))年\(cal.month(of: date))月\(cal.dayOfMonth(of: date))日"
    }

    /// `星期一`
    public func weekday(_ date: Date) -> String {
        Self.weekdayNames[cal.weekday(of: date) - 1]
    }

    /// `2027年6月7日 星期一`（首页顶部栏）
    public func longWithWeekday(_ date: Date) -> String {
        "\(long(date)) \(weekday(date))"
    }

    /// `12月1日`（心里话时间线）
    public func short(_ date: Date) -> String {
        "\(cal.month(of: date))月\(cal.dayOfMonth(of: date))日"
    }

    /// `2026.12.02`（分享卡）
    public func dotted(_ date: Date) -> String {
        String(format: "%04d.%02d.%02d", cal.year(of: date), cal.month(of: date), cal.dayOfMonth(of: date))
    }

    /// `2026年12月`（日历页标题）
    public func monthTitle(_ date: Date) -> String {
        "\(cal.year(of: date))年\(cal.month(of: date))月"
    }
}
