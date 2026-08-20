import Foundation

/// 打开 App 时最多弹一个全屏提示。
///
/// # 为什么需要一个统一的裁决者
/// 需求文档 5.8.2 让节点日弹分享卡，信件文案表 5.1 让到期日弹拆信提示。
/// 同一天两者都可能命中 —— 如果各弹各的，用户会连吃两个全屏。
///
/// **信件优先于分享卡**（信件文案表 5.1 明确）。理由也站得住：
/// 信是不可重建的，卡片随时可以手动生成。
public enum AppOpenPrompt: Equatable, Sendable, Identifiable {
    /// 有一封信到期了。
    case letterDue(letterID: String, writtenDaysAgo: Int)
    /// 节点卡。
    case milestoneCard(daysRemaining: Int)

    public var id: String {
        switch self {
        case .letterDue(let letterID, _):       return "letter-\(letterID)"
        case .milestoneCard(let daysRemaining): return "milestone-\(daysRemaining)"
        }
    }
}

public enum AppOpenPromptResolver {

    /// - Parameters:
    ///   - deferredLetterIDs: 今天已经点过「待会儿」的信。
    ///     「待会儿」当天不再弹，**次日再触发，直到被拆开** ——
    ///     所以这是按天判断的，不是一次性关闭。
    ///   - shownMilestoneDays: 已经弹过的节点。每个节点一生只弹一次。
    public static func resolve(
        countdown: Countdown,
        letters: [LetterDigest],
        deferredLetterIDs: Set<String>,
        shownMilestoneDays: Set<Int>,
        today: Date,
        cal: DayCalendar = .current
    ) -> AppOpenPrompt? {
        // 1. 信件到期（最高优先级）
        let due = letters
            .filter { !$0.isOpened && !$0.isDraft }
            .filter { cal.days(from: today, to: $0.openAt) <= 0 }
            .filter { !deferredLetterIDs.contains($0.id) }
            .min { $0.openAt < $1.openAt }

        if let due {
            return .letterDue(
                letterID: due.id,
                writtenDaysAgo: max(cal.days(from: due.writtenAt, to: today), 0)
            )
        }

        // 2. 节点卡
        if let milestone = HomeSummaryBuilder.pendingMilestone(
            countdown: countdown, shownMilestoneDays: shownMilestoneDays
        ) {
            return .milestoneCard(daysRemaining: milestone.daysRemaining)
        }

        return nil
    }
}
