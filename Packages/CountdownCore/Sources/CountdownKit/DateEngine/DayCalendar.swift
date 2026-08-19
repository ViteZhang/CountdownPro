import Foundation

/// 全产品所有「天」的运算入口。
///
/// 为什么单独封装：本产品的核心数字（已走过 / 还剩 / progress）全部是**日历天差**，
/// 不是时间差。任何 `(b - a) / 86400` 的写法都会在夏令时、闰秒、时区迁移时错 1 天，
/// 而错 1 天在这个产品里是致命的 —— 用户会看到「已走过」倒退。
///
/// 需求文档 5.3：跨零点以**设备本地时间 00:00** 为界。
public struct DayCalendar: Sendable {

    public let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// 跟随系统时区与日历设置。App 与 Widget 运行时使用这个。
    public static var current: DayCalendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .autoupdatingCurrent
        c.locale = Locale(identifier: "zh_CN")
        return DayCalendar(calendar: c)
    }

    /// 固定时区，供测试与快照使用。
    public static func fixed(timeZoneIdentifier: String = "Asia/Shanghai") -> DayCalendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
        c.locale = Locale(identifier: "zh_CN")
        return DayCalendar(calendar: c)
    }

    // MARK: - 构造

    /// 构造某一天的 00:00。月末溢出按日历收敛（如 2 月 31 日 → 2 月 28/29 日）。
    public func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let clampedMonth = min(max(month, 1), 12)
        var comps = DateComponents()
        comps.year = year
        comps.month = clampedMonth
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps) else {
            preconditionFailure("无法构造日期 \(year)-\(month)-\(day)")
        }
        let length = daysInMonth(firstOfMonth)
        comps.day = min(max(day, 1), length)
        guard let d = calendar.date(from: comps) else {
            preconditionFailure("无法构造日期 \(year)-\(month)-\(day)")
        }
        return startOfDay(d)
    }

    public func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: - 运算

    /// 日历天差。`a` 与 `b` 各自归一到当天 00:00 后再取差值。
    public func days(from a: Date, to b: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(a), to: startOfDay(b)).day ?? 0
    }

    /// 加减天数。走 `Calendar`，夏令时切换日仍然精确落在次日 00:00。
    public func adding(days: Int, to date: Date) -> Date {
        guard let d = calendar.date(byAdding: .day, value: days, to: startOfDay(date)) else {
            preconditionFailure("无法对 \(date) 加 \(days) 天")
        }
        return startOfDay(d)
    }

    public func adding(years: Int, to date: Date) -> Date {
        guard let d = calendar.date(byAdding: .year, value: years, to: startOfDay(date)) else {
            preconditionFailure("无法对 \(date) 加 \(years) 年")
        }
        return startOfDay(d)
    }

    public func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    // MARK: - 取值

    public func year(of date: Date) -> Int { calendar.component(.year, from: date) }
    public func month(of date: Date) -> Int { calendar.component(.month, from: date) }
    public func dayOfMonth(of date: Date) -> Int { calendar.component(.day, from: date) }

    /// 1 = 周日 … 7 = 周六（Gregorian 约定）。
    public func weekday(of date: Date) -> Int { calendar.component(.weekday, from: date) }

    public func daysInMonth(_ date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// 该月最后一个指定星期几。`weekday` 用 Gregorian 约定（1 = 周日）。
    public func lastWeekday(_ weekday: Int, inYear year: Int, month: Int) -> Date {
        let firstOfMonth = day(year, month, 1)
        var cursor = day(year, month, daysInMonth(firstOfMonth))
        while self.weekday(of: cursor) != weekday {
            cursor = adding(days: -1, to: cursor)
        }
        return cursor
    }

    /// 该月**倒数第 n 个**指定星期几（n 从 1 起）。
    public func nthFromLastWeekday(_ weekday: Int, n: Int, inYear year: Int, month: Int) -> Date {
        let last = lastWeekday(weekday, inYear: year, month: month)
        return adding(days: -7 * (max(n, 1) - 1), to: last)
    }
}
