import Foundation

/// 小组件渲染所需的全部输入。
///
/// 需求文档 5.10：**小组件完全离线可用，零服务器依赖。**
/// 所以这个结构里的每一项都必须能从 App Group 内的本地存储直接读出来。
public struct WidgetSnapshot: Equatable, Sendable {
    public let examTitle: String
    public let startDate: Date
    public let targetDate: Date

    /// 同考人数缓存。`nil` 表示无缓存 / 无网络 / 不足 1 万 —— 三者不作区分。
    /// 中号小组件据此**整行隐藏**，其余内容照常显示（5.10）。
    public let censusCount: Int?

    public init(examTitle: String, startDate: Date, targetDate: Date, censusCount: Int?) {
        self.examTitle = examTitle
        self.startDate = startDate
        self.targetDate = targetDate
        self.censusCount = censusCount
    }
}

/// 一个 Timeline entry 的渲染数据。全部是**算好的结果**，视图层不再做任何日期运算。
public struct WidgetEntryData: Equatable, Sendable {
    /// 该 entry 生效的时刻（当天 00:00）
    public let date: Date
    public let examTitle: String
    public let countdown: Countdown
    /// 已经过 `CensusFormatter` 的展示值。`nil` = **整块隐藏**。
    public let censusDisplay: String?

    public init(date: Date, examTitle: String, countdown: Countdown, censusDisplay: String?) {
        self.date = date
        self.examTitle = examTitle
        self.countdown = countdown
        self.censusDisplay = censusDisplay
    }
}

/// WidgetKit Timeline 的构造。
///
/// # 为什么可以预生成
/// 天数一天只变一次，所以未来 7 天的内容此刻就能全部算出来 ——
/// 这正是小组件能做到零网络、零后台唤醒的原因（需求文档 5.10）。
///
/// 这一层是纯函数，不 import WidgetKit，因此可以被测试。
public enum WidgetTimelineBuilder {

    /// 预生成的 entry 数量（需求文档 5.10：未来 7 天）。
    public static let entryCount = 7

    /// 生成 entry 序列。第 0 条是今天，其余为随后每一天的 00:00。
    ///
    /// # 同考人数只出现在今天那一条
    /// 这是刻意的。缓存里的数字是**今天**的人数，把它原样铺到未来 6 天，
    /// 小组件就会在明天用昨天的数据说「今天有 41.2 万人和你一起」——
    /// 那正是 D-09 禁止的「用旧数字冒充今日人数」。
    /// 所以未来的 entry 一律 `nil`，也就是整块隐藏，等 App 下次刷新时再带上真实值。
    public static func entries(
        snapshot: WidgetSnapshot,
        from today: Date,
        cal: DayCalendar = .current
    ) -> [WidgetEntryData] {
        let engine = CountdownEngine(cal: cal)
        let start = cal.startOfDay(today)

        return (0..<entryCount).map { offset in
            let day = cal.adding(days: offset, to: start)
            return WidgetEntryData(
                date: day,
                examTitle: snapshot.examTitle,
                countdown: engine.countdown(
                    startDate: snapshot.startDate,
                    targetDate: snapshot.targetDate,
                    today: day
                ),
                censusDisplay: offset == 0 ? CensusFormatter.display(count: snapshot.censusCount) : nil
            )
        }
    }

    /// Timeline 的刷新时刻：最后一条 entry 生效之后。
    ///
    /// 用 `.after(reloadDate)` 而不是 `.atEnd`，这样即使 App 长期没被打开，
    /// 系统也会在第 7 天来要新的 timeline，天数不会停在旧值上。
    public static func reloadDate(
        from today: Date,
        cal: DayCalendar = .current
    ) -> Date {
        cal.adding(days: entryCount - 1, to: today)
    }
}
