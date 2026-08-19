import Foundation

/// 需求文档 5.8.1 节点卡触发点 / 5.11 节点通知。
///
/// 注意两处清单**不同**：卡片含 99（进入两位数），通知不含。这是有意的 —— 99 只递卡不打扰。
public struct Milestone: Hashable, Sendable {
    public let daysRemaining: Int

    public init(daysRemaining: Int) { self.daysRemaining = daysRemaining }

    /// 会触发全屏节点卡的剩余天数（5.8.1）。
    public static let cardTriggers: [Int] = [100, 99, 50, 30, 10, 1]

    /// 会触发通知的剩余天数（5.11）。
    public static let notificationTriggers: [Int] = [100, 50, 30, 10, 1]

    public var triggersCard: Bool { Milestone.cardTriggers.contains(daysRemaining) }
    public var triggersNotification: Bool { Milestone.notificationTriggers.contains(daysRemaining) }

    /// 每个节点一生只触发一次，用这个 key 在 AppFlags 里记录（5.8.2）。
    public var flagKey: String { "milestone_card_shown_d\(daysRemaining)" }
}
