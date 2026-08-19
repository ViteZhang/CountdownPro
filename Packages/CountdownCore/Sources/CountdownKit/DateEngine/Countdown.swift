import Foundation

/// 需求文档 4.5「计算字段（不存储，实时计算）」的全部结果。
///
/// 这是一个**值快照**，由 `CountdownEngine.countdown(...)` 现算出来，不落库。
/// 硬约束：不存储任何可推导的值 —— 累计天数、进度、成长阶段都实时计算。
public struct Countdown: Equatable, Sendable {

    /// target_date − today。考试当天为 0，考后为负。
    public let daysRemaining: Int

    /// today − start_date，**clamp 到 ≥ 0**。
    ///
    /// 引导第 3 屏允许用户把起始日期设在未来（提示「已走过会是 0 天」但放行），
    /// 所以这里必须兜底，否则首页会出现负数。
    public let daysPassed: Int

    /// target_date − start_date。总跨度。
    public let totalDays: Int

    /// days_passed / total_days，**clamp 到 0...1**。
    ///
    /// 用于进度环填充与成长阶段映射。
    /// 设计决策 D-01：**填充比例 = 已走过比例，不是打卡完成率。**
    public let progress: Double

    /// 未 clamp 的原始比例。考后 > 1.0。5.2 用它判断是否切考后态。
    public let rawProgress: Double

    public let isExamDay: Bool
    public let isAfterExam: Bool

    public let growthStage: GrowthStage

    /// 今天是否命中节点（5.8.1 / 5.11）。
    public var milestone: Milestone { Milestone(daysRemaining: daysRemaining) }
}

public struct CountdownEngine: Sendable {

    public let cal: DayCalendar

    public init(cal: DayCalendar = .current) {
        self.cal = cal
    }

    /// 计算某个考试在 `today` 这一天的全部派生数值。
    ///
    /// - Note: `startDate ≥ targetDate` 是引导流程拦下的非法态（5.1 边界情况），
    ///   但数据可能来自旧版本或同步，所以这里不 crash：totalDays ≤ 0 时 progress 记 0。
    public func countdown(startDate: Date, targetDate: Date, today: Date) -> Countdown {
        let start = cal.startOfDay(startDate)
        let target = cal.startOfDay(targetDate)
        let now = cal.startOfDay(today)

        let remaining = cal.days(from: now, to: target)
        let passed = max(cal.days(from: start, to: now), 0)
        let total = cal.days(from: start, to: target)

        let raw: Double = total > 0 ? Double(passed) / Double(total) : 0
        let clamped = min(max(raw, 0), 1)

        let examDay = remaining == 0
        let afterExam = remaining < 0

        return Countdown(
            daysRemaining: remaining,
            daysPassed: passed,
            totalDays: total,
            progress: clamped,
            rawProgress: raw,
            isExamDay: examDay,
            isAfterExam: afterExam,
            growthStage: .stage(progress: clamped, isExamDay: examDay)
        )
    }

    // MARK: - 补签窗口（需求文档 5.3 / 设计决策 D-04）

    /// 补签窗口天数。**14 天**：无限补签会让「累计 128 天」失去意义；
    /// 住校生月假周期最长约两周，14 天能覆盖绝大多数真实场景。
    /// 见设计决策 D-04 —— 改这个值前请先读那一条。
    public static let backfillWindowDays = 14

    /// 是否可补签。窗口为 `[today − 14, today)`：今天走正常打卡，不算补签。
    public func canBackfill(date: Date, today: Date) -> Bool {
        let d = cal.startOfDay(date)
        let now = cal.startOfDay(today)
        guard d < now else { return false }
        return cal.days(from: d, to: now) <= Self.backfillWindowDays
    }

    /// 补签窗口的最早一天（含）。
    public func earliestBackfillDate(today: Date) -> Date {
        cal.adding(days: -Self.backfillWindowDays, to: today)
    }

    // MARK: - 信件开启日（需求文档 5.6）

    /// 预设节点对应的开启日期。
    ///
    /// - Parameter resultDay: 出分日。依赖考后日程表（5.12），调用方未提供时返回 nil，
    ///   此时写信页不得展示「出分日」这个选项。
    public func letterOpenDate(
        trigger: LetterTrigger,
        targetDate: Date,
        resultDay: Date? = nil,
        customDate: Date? = nil
    ) -> Date? {
        let target = cal.startOfDay(targetDate)
        switch trigger {
        case .d100:       return cal.adding(days: -100, to: target)
        case .d50:        return cal.adding(days: -50, to: target)
        case .nightBefore: return cal.adding(days: -1, to: target)
        case .resultDay:  return resultDay.map(cal.startOfDay)
        case .custom:     return customDate.map(cal.startOfDay)
        }
    }

    /// 写信时该节点是否可选。已过期的节点直接不展示（5.6 未定义，此处为实现约定）。
    public func isTriggerSelectable(
        _ trigger: LetterTrigger,
        targetDate: Date,
        today: Date,
        resultDay: Date? = nil
    ) -> Bool {
        guard let open = letterOpenDate(trigger: trigger, targetDate: targetDate, resultDay: resultDay) else {
            return false
        }
        return open > cal.startOfDay(today)
    }

    /// 首页提示条：距最近一封信开启 ≤ 30 天时才显示（5.6）。
    public static let letterHintWindowDays = 30
}
