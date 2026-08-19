import Foundation

/// 首次启动引导（需求文档 5.1）的默认日期规则。
public struct DefaultDates: Sendable {

    public let cal: DayCalendar

    public init(cal: DayCalendar = .current) { self.cal = cal }

    // MARK: - 默认目标日期

    /// 按考试类型带出默认目标日期。
    ///
    /// **规则：当年优先，已过期则顺延次年。**
    ///
    /// 需求文档 5.1 表格写的是「次年 6 月 7 日」，onboarding 原型代码走的是「当年优先」。
    /// 已确认以**原型逻辑**为准 —— 3 月安装的高三生应当直接看到今年 6 月 7 日。
    ///
    /// 顺延判据用 `<= today` 而非原型的 `< today`：原型 `defTarget` 用 `<`、
    /// 校验 `paintTarget` 用 `<=`，两者在「默认值恰好等于今天」时会打架
    /// （默认值被保留，但「继续」按钮同时被置灰）。这里统一到校验规则一侧。
    public func targetDate(for type: ExamType, today: Date) -> Date? {
        let thisYear = cal.year(of: today)

        func rolledForward(_ make: (Int) -> Date) -> Date {
            let candidate = make(thisYear)
            return candidate <= cal.startOfDay(today) ? make(thisYear + 1) : candidate
        }

        switch type {
        case .gaokao:
            // 全国统考首日 6 月 7 日
            return rolledForward { cal.day($0, 6, 7) }
        case .zhongkao:
            // 各省不同，无省份数据时用 6 月 15 日
            return rolledForward { cal.day($0, 6, 15) }
        case .kaoyan:
            // 12 月倒数第 3 个周六
            return rolledForward { cal.nthFromLastWeekday(7, n: 3, inYear: $0, month: 12) }
        case .kaogong:
            // 国考：11 月最后一个周日
            return rolledForward { cal.lastWeekday(1, inYear: $0, month: 11) }
        case .custom:
            // 5.1 表格：自定义无默认目标日期。
            // 原型给的「今天起一个月后」仅为选择器初值，不是产品意义上的默认值。
            return nil
        }
    }

    /// 自定义考试的日期选择器初值（不是默认目标日期，仅用于让选择器有个落点）。
    public func customPickerSeed(today: Date) -> Date {
        let t = cal.startOfDay(today)
        var comps = DateComponents()
        comps.month = 1
        return cal.startOfDay(cal.calendar.date(byAdding: comps, to: t) ?? t)
    }

    // MARK: - 默认起始日期

    /// 按考试类型与目标日期带出默认起始日期。
    ///
    /// 需求文档 5.1：
    /// - 高考 / 中考 → 目标年份 − 3 年的 9 月 1 日（高一 / 初一入学）
    /// - 考研 / 考公 → 目标年份的 3 月 1 日
    /// - 自定义 → 今天
    ///
    /// 边界：**默认起始日期晚于今天则回落为今天。**
    public func startDate(for type: ExamType, targetDate: Date, today: Date) -> Date {
        let targetYear = cal.year(of: targetDate)
        let raw: Date
        switch type {
        case .gaokao, .zhongkao:
            raw = cal.day(targetYear - 3, 9, 1)
        case .kaoyan, .kaogong:
            raw = cal.day(targetYear, 3, 1)
        case .custom:
            raw = cal.startOfDay(today)
        }
        return min(raw, cal.startOfDay(today))
    }

    // MARK: - 快捷起始日期（引导第 3 屏）

    public struct QuickStart: Equatable, Sendable {
        public let title: String
        public let date: Date
    }

    /// 引导第 3 屏的快捷选项。文案逐字取自 onboarding 原型。
    ///
    /// 注意：快捷选项**不做 `min(今天)` 回落** —— 那是默认值的规则。
    /// 用户主动点「高一开学」时应当拿到真实的开学日，即使它晚于今天（第 3 屏会提示但放行）。
    public func quickStarts(for type: ExamType, targetDate: Date, today: Date) -> [QuickStart] {
        let targetYear = cal.year(of: targetDate)
        let todayStart = cal.startOfDay(today)
        switch type {
        case .gaokao:
            return [
                .init(title: "高一开学", date: cal.day(targetYear - 3, 9, 1)),
                .init(title: "高三开学", date: cal.day(targetYear - 1, 9, 1)),
                .init(title: "今天", date: todayStart),
            ]
        case .zhongkao:
            return [
                .init(title: "初一开学", date: cal.day(targetYear - 3, 9, 1)),
                .init(title: "初三开学", date: cal.day(targetYear - 1, 9, 1)),
                .init(title: "今天", date: todayStart),
            ]
        case .kaoyan, .kaogong, .custom:
            return [
                .init(title: "决定要考的那天", date: cal.day(targetYear, 3, 1)),
                .init(title: "今天", date: todayStart),
            ]
        }
    }

    // MARK: - 校验（引导第 2 / 3 屏）

    public enum TargetIssue: Equatable, Sendable {
        /// 日期 ≤ 今天。可一键改成下一年。
        case inPast(suggestedYear: Int)
    }

    public enum StartIssue: Equatable, Sendable {
        /// 起始 ≥ 目标。阻断，「好了」置灰。
        case notBeforeTarget
        /// 起始 > 今天。提醒但**允许继续**。
        case inFuture
    }

    public func validateTarget(_ target: Date, today: Date) -> TargetIssue? {
        guard cal.startOfDay(target) <= cal.startOfDay(today) else { return nil }
        return .inPast(suggestedYear: cal.year(of: target) + 1)
    }

    public func validateStart(_ start: Date, target: Date, today: Date) -> StartIssue? {
        let s = cal.startOfDay(start)
        if s >= cal.startOfDay(target) { return .notBeforeTarget }
        if s > cal.startOfDay(today) { return .inFuture }
        return nil
    }

    /// 「改成 N 年」的一键修复：保留月日，年份 +1。
    public func rollTargetToNextYear(_ target: Date) -> Date {
        cal.day(cal.year(of: target) + 1, cal.month(of: target), cal.dayOfMonth(of: target))
    }
}
