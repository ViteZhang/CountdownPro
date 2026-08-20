import Foundation

/// 记录页日历的一个月（需求文档 5.5）。
///
/// 纯数据，视图只负责画格子。
public struct CalendarMonth: Equatable, Sendable {

    public struct Day: Equatable, Sendable, Identifiable {
        public let date: Date
        public let dayOfMonth: Int
        /// 已打卡（实心）
        public let isCheckedIn: Bool
        /// 补签（浅色实心）。**计入累计天数**，只是标记不同。
        public let isBackfill: Bool
        /// 有心里话（右上角点）
        public let hasNote: Bool
        public let isToday: Bool
        /// 是否落在 14 天补签窗口内 —— 决定这一格能不能点。
        public let canBackfill: Bool

        public var id: Date { date }
    }

    public let year: Int
    public let month: Int
    /// 1 号之前要留几个空格（周日为一周之始）。
    public let leadingBlanks: Int
    public let days: [Day]

    public static func build(
        year: Int,
        month: Int,
        today: Date,
        checkInDates: Set<Date>,
        backfillDates: Set<Date>,
        noteDates: Set<Date>,
        cal: DayCalendar = .current
    ) -> CalendarMonth {
        let engine = CountdownEngine(cal: cal)
        let first = cal.day(year, month, 1)
        let length = cal.daysInMonth(first)

        let days = (1...length).map { d -> Day in
            let date = cal.day(year, month, d)
            return Day(
                date: date,
                dayOfMonth: d,
                isCheckedIn: checkInDates.contains(date),
                isBackfill: backfillDates.contains(date),
                hasNote: noteDates.contains(date),
                isToday: cal.isSameDay(date, today),
                canBackfill: engine.canBackfill(date: date, today: today)
            )
        }

        return CalendarMonth(
            year: year,
            month: month,
            leadingBlanks: cal.weekday(of: first) - 1,
            days: days
        )
    }

    public static let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]
}
