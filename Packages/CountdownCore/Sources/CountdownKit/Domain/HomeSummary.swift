import Foundation

/// 首页底部提示条要展示的那封信（需求文档 5.6）。
public struct LetterHint: Equatable, Sendable {
    /// 这封信写于多少天前。文案里是「100 天前写给自己的信」。
    public let writtenDaysAgo: Int
    /// 还有几天开启。`0` 表示今天就能开。
    public let daysUntilOpen: Int

    public init(writtenDaysAgo: Int, daysUntilOpen: Int) {
        self.writtenDaysAgo = writtenDaysAgo
        self.daysUntilOpen = daysUntilOpen
    }

    public var isOpenableNow: Bool { daysUntilOpen == 0 }
}

/// 选提示条那封信时需要的最小信息。**刻意不含正文** ——
/// 首页排版逻辑没有任何理由碰到密文（D-08）。
public struct LetterDigest: Equatable, Sendable {
    public let id: String
    public let writtenAt: Date
    public let openAt: Date
    public let isOpened: Bool

    public init(id: String, writtenAt: Date, openAt: Date, isOpened: Bool) {
        self.id = id
        self.writtenAt = writtenAt
        self.openAt = openAt
        self.isOpened = isOpened
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

    /// 选出提示条要展示的那封信。
    ///
    /// 优先级：
    /// 1. **已到开启日但还没拆的** —— 取最早到期的那封。
    ///    「开启日已过但用户未打开 App：下次打开时补触发」（5.6 边界情况）。
    /// 2. 30 天内即将开启的 —— 取最近的那封。
    /// 3. 都没有 → 不显示提示条。
    public static func letterHint(
        letters: [LetterDigest],
        today: Date,
        cal: DayCalendar = .current
    ) -> LetterHint? {
        let pending = letters.filter { !$0.isOpened }
        guard !pending.isEmpty else { return nil }

        func hint(_ letter: LetterDigest) -> LetterHint {
            LetterHint(
                writtenDaysAgo: max(cal.days(from: letter.writtenAt, to: today), 0),
                daysUntilOpen: max(cal.days(from: today, to: letter.openAt), 0)
            )
        }

        let openable = pending.filter { cal.days(from: today, to: $0.openAt) <= 0 }
        if let earliest = openable.min(by: { $0.openAt < $1.openAt }) {
            return hint(earliest)
        }

        let upcoming = pending
            .filter { cal.days(from: today, to: $0.openAt) <= letterHintWindowDays }
            .min(by: { $0.openAt < $1.openAt })
        return upcoming.map(hint)
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
