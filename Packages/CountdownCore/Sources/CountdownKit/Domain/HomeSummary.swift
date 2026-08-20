import Foundation

/// 首页底部提示条（需求文档 5.6 / 信件文案表第 8 节）。
///
/// 三种情况**互斥**，优先级：今天到期 > 草稿未完成 > 即将开启。
/// 做成 enum 而不是带可选字段的 struct，是为了让"同时命中两种"在类型上不可能发生。
public enum LetterHint: Equatable, Sendable {
    /// 有信件今天（或更早）到期还没拆。
    case dueToday
    /// 有草稿没写完。
    case draftInProgress
    /// 最近一封信 ≤ 30 天后开启。
    case upcoming(writtenDaysAgo: Int, inDays: Int)
}

/// 选提示条那封信时需要的最小信息。**刻意不含正文** ——
/// 首页排版逻辑没有任何理由碰到密文（D-08）。
public struct LetterDigest: Equatable, Sendable {
    public let id: String
    public let writtenAt: Date
    public let openAt: Date
    public let isOpened: Bool
    /// 草稿。草稿可查看可修改，未封存，因此不参与"到期"判断。
    public let isDraft: Bool

    public init(id: String, writtenAt: Date, openAt: Date, isOpened: Bool, isDraft: Bool = false) {
        self.id = id
        self.writtenAt = writtenAt
        self.openAt = openAt
        self.isOpened = isOpened
        self.isDraft = isDraft
    }
}

/// 首页一次渲染所需的全部派生状态。
///
/// 全部现算，不落库（需求文档 4.5：**不存储任何可推导的值**）。
public struct HomeSummary: Equatable, Sendable {
    public let examTitle: String
    public let targetDate: Date
    public let countdown: Countdown

    /// 累计打卡天数。**只有累计，没有连续** —— 设计决策 D-03。
    /// 大量高中生在校禁用手机、住校生一周才碰一次手机，
    /// 连续打卡会精准惩罚最努力的用户。
    public let totalCheckIns: Int
    public let totalNotes: Int
    public let hasCheckedInToday: Bool

    public let letterHint: LetterHint?

    /// 已经过 `CensusFormatter`。`nil` = 整块隐藏（D-09）。
    public let censusDisplay: String?

    /// 今天要不要弹全屏节点卡（5.8.2）。已弹过的节点不再触发。
    public let pendingMilestone: Milestone?

    /// 今天刚解锁的皮肤（5.9）。给一次轻量提示，不做弹窗打断。
    public let newlyUnlockedSkinCheckInDays: Int?
}

public enum HomeSummaryBuilder {

    /// 首页提示条的展示窗口：距最近一封信开启 ≤ 30 天（5.6）。
    public static let letterHintWindowDays = CountdownEngine.letterHintWindowDays

    public static func build(
        examTitle: String,
        startDate: Date,
        targetDate: Date,
        today: Date,
        totalCheckIns: Int,
        totalNotes: Int,
        hasCheckedInToday: Bool,
        letters: [LetterDigest],
        censusCount: Int?,
        shownMilestoneDays: Set<Int>,
        previousTotalCheckIns: Int,
        cal: DayCalendar = .current
    ) -> HomeSummary {
        let engine = CountdownEngine(cal: cal)
        let countdown = engine.countdown(startDate: startDate, targetDate: targetDate, today: today)

        return HomeSummary(
            examTitle: examTitle,
            targetDate: targetDate,
            countdown: countdown,
            totalCheckIns: totalCheckIns,
            totalNotes: totalNotes,
            hasCheckedInToday: hasCheckedInToday,
            letterHint: letterHint(letters: letters, today: today, cal: cal),
            censusDisplay: CensusFormatter.display(count: censusCount),
            pendingMilestone: pendingMilestone(countdown: countdown, shownMilestoneDays: shownMilestoneDays),
            newlyUnlockedSkinCheckInDays: newlyUnlockedSkin(
                totalCheckIns: totalCheckIns, previous: previousTotalCheckIns
            )
        )
    }

    /// 选出提示条要展示的内容。
    ///
    /// 优先级（信件文案表第 8 节）：**今天到期 > 草稿未完成 > 即将开启**。
    ///
    /// 「到期」包含开启日已过但用户没打开 App 的情况 —— 下次打开时补触发（5.6 边界情况）。
    public static func letterHint(
        letters: [LetterDigest],
        today: Date,
        cal: DayCalendar = .current
    ) -> LetterHint? {
        let sealed = letters.filter { !$0.isOpened && !$0.isDraft }

        if sealed.contains(where: { cal.days(from: today, to: $0.openAt) <= 0 }) {
            return .dueToday
        }

        if letters.contains(where: \.isDraft) {
            return .draftInProgress
        }

        guard let next = sealed
            .filter({ cal.days(from: today, to: $0.openAt) <= letterHintWindowDays })
            .min(by: { $0.openAt < $1.openAt })
        else { return nil }

        return .upcoming(
            writtenDaysAgo: max(cal.days(from: next.writtenAt, to: today), 0),
            inDays: max(cal.days(from: today, to: next.openAt), 0)
        )
    }

    /// 今天是否要弹节点卡。
    ///
    /// 「用户不会主动想到分享，必须由产品在情绪峰值主动递卡」（5.8.2），
    /// 但**每个节点只触发一次，用户关闭后不再重复弹出**。
    public static func pendingMilestone(
        countdown: Countdown,
        shownMilestoneDays: Set<Int>
    ) -> Milestone? {
        let milestone = countdown.milestone
        guard milestone.triggersCard,
              !shownMilestoneDays.contains(milestone.daysRemaining)
        else { return nil }
        return milestone
    }

    /// 跨过解锁阈值的那一次返回阈值天数，其余返回 nil。
    private static func newlyUnlockedSkin(totalCheckIns: Int, previous: Int) -> Int? {
        for threshold in [30, 100, 200] where previous < threshold && totalCheckIns >= threshold {
            return threshold
        }
        return nil
    }
}
