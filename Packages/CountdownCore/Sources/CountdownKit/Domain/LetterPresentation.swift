import Foundation

/// 一封信在信箱里的四种状态（信件文案表 1.3）。
public enum LetterState: Equatable, Sendable {
    /// 可查看、可修改、可删除。
    case draft
    /// 已封存未到期。**不可查看、不可修改**，只能删除。
    case sealed(daysRemaining: Int)
    /// 已到开启日但还没拆。
    case openable
    case opened(at: Date)
}

/// 信件列表项的派生状态。
public struct LetterListItem: Equatable, Sendable {
    public let id: String
    public let state: LetterState
    public let writtenAt: Date
    public let openAt: Date
    public let trigger: LetterTrigger

    public init(id: String, state: LetterState, writtenAt: Date, openAt: Date, trigger: LetterTrigger) {
        self.id = id
        self.state = state
        self.writtenAt = writtenAt
        self.openAt = openAt
        self.trigger = trigger
    }
}

public enum LetterPresentation {

    /// 由存储字段推导列表状态。
    public static func state(
        isDraft: Bool,
        isOpened: Bool,
        openedAt: Date?,
        openAt: Date,
        today: Date,
        cal: DayCalendar = .current
    ) -> LetterState {
        if isDraft { return .draft }
        if isOpened { return .opened(at: openedAt ?? openAt) }
        let remaining = cal.days(from: today, to: openAt)
        return remaining <= 0 ? .openable : .sealed(daysRemaining: remaining)
    }

    // MARK: - 封存中的占位方块

    /// 封存中的信用**实心方块**遮盖，不用模糊或马赛克。
    ///
    /// 模糊暗示"看得到但看不清"，会诱发用户去试；实心方块是彻底的不可见，反而更安静。
    ///
    /// 方块数量按内容长度**粗略**换算 —— 刻意做成 5 档，
    /// 使得无法从方块数反推字数（否则遮盖就漏了信息）。
    public static func sealedPlaceholder(contentLength: Int) -> String {
        String(repeating: "■", count: blockCount(contentLength: contentLength))
    }

    static func blockCount(contentLength: Int) -> Int {
        switch contentLength {
        case ..<51:   return 6
        case ..<151:  return 9
        case ..<351:  return 12
        case ..<601:  return 15
        default:      return 18
        }
    }

    // MARK: - 落款

    /// 「—— 100 天前的你」。
    ///
    /// 天数是**写信到开启的实际间隔**，不是固定文案。
    /// 间隔 ≥ 365 天时改用「—— 一年多以前的你」——
    /// "四百多天前"读起来像账单，"一年多以前"才是人话。
    public static func signature(
        writtenAt: Date,
        openedAt: Date,
        cal: DayCalendar = .current
    ) -> String {
        let days = max(cal.days(from: writtenAt, to: openedAt), 0)
        return days >= 365 ? Strings.Letters.signatureOverAYear : Strings.Letters.signature(daysAgo: days)
    }

    // MARK: - 写信页字数提示

    /// 剩余字数提示。
    ///
    /// 剩余 > 100 字时**不显示** —— 计数器会让人分心，
    /// 而这一屏的全部目的是降低门槛、不制造表达压力。
    public static func remainingHint(contentLength: Int, limit: Int = Strings.Letters.maxLength) -> String? {
        let remaining = limit - contentLength
        if remaining > 100 { return nil }
        if remaining <= 0 { return Strings.Letters.lengthFull }
        return Strings.Letters.lengthRemaining(remaining)
    }

    // MARK: - 自定义开启日期校验（信件文案表 3.2）

    public enum CustomDateIssue: Equatable, Sendable {
        /// 已过去。**阻断** —— 一封立刻就能拆的信没有意义。
        case inPast
        /// 就是今天。提示但放行。
        case isToday
        /// 晚于考试日。**允许** —— 有人就是想写给考完的自己。只提示，不阻拦。
        case afterExam
    }

    public static func validateCustomDate(
        _ date: Date,
        today: Date,
        targetDate: Date,
        cal: DayCalendar = .current
    ) -> CustomDateIssue? {
        let d = cal.startOfDay(date)
        let now = cal.startOfDay(today)
        if d < now { return .inPast }
        if d == now { return .isToday }
        if d > cal.startOfDay(targetDate) { return .afterExam }
        return nil
    }

    public static func canUseCustomDate(
        _ date: Date,
        today: Date,
        targetDate: Date,
        cal: DayCalendar = .current
    ) -> Bool {
        validateCustomDate(date, today: today, targetDate: targetDate, cal: cal) != .inPast
    }

    // MARK: - 考试日期变动后的节点重算（信件文案表 3.3）

    public struct TriggerRecalculation: Equatable, Sendable {
        public let letterID: String
        public let newOpenAt: Date
    }

    /// 用户修改考试日期后，重算受影响信件的开启日。
    ///
    /// **只调整预设节点（d100 / d50 / night_before / result_day）的信，
    /// 自定义日期的信不动** —— 用户自己挑的那一天，凭什么替他改。
    ///
    /// - Returns: 需要更新的信件。数量用于 Toast「有 N 封信的开启日期跟着调整了」。
    public static func recalculateTriggers(
        letters: [LetterListItem],
        newTargetDate: Date,
        resultDay: Date? = nil,
        cal: DayCalendar = .current
    ) -> [TriggerRecalculation] {
        let engine = CountdownEngine(cal: cal)
        return letters.compactMap { letter in
            guard letter.trigger != .custom else { return nil }
            guard let newOpen = engine.letterOpenDate(
                trigger: letter.trigger, targetDate: newTargetDate, resultDay: resultDay
            ) else { return nil }
            guard newOpen != cal.startOfDay(letter.openAt) else { return nil }
            return TriggerRecalculation(letterID: letter.id, newOpenAt: newOpen)
        }
    }
}
