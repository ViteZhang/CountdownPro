import Foundation

/// 本地通知的排程（需求文档 5.11 / 信件文案表 5.2）。
///
/// # 为什么是纯函数
/// 排程完全由「考试日期 + 未开启的信」推导，不落库。
/// 与「不存储任何可推导的值」同一条原则：存了就会和真相不一致 ——
/// 用户改了考试日期，存下来的排程不会自己跟着变，于是在错误的日子推送错误的天数。
///
/// # 通知内容不经过调用方
/// `ScheduledNotification` **没有接受 title / body 的构造器**，两者都由 `kind` 推导。
/// 这不是为了少写参数，是为了让「把信的正文塞进推送」这件事在类型上做不到（D-08）。
/// 通知会出现在锁屏上，是这个 App 里唯一能绕开所有解密门禁的展示面。
public enum NotificationKind: Equatable, Sendable {
    /// 节点通知。**不含 99** —— 99 只递分享卡，不打扰（见 `Milestone`）。
    case milestone(daysRemaining: Int)
    /// 考试当天早上
    case examDayMorning
    /// 信件到期。只带 ID 与"多久以前写的"，**不带正文**。
    case letterDue(letterID: String, daysAgo: Int)
    /// 考前一晚那封信。文案表 5.2 单独给了一句，与普通到期不同。
    case letterNightBefore(letterID: String)
}

/// 一条待排的本地通知。
public struct ScheduledNotification: Equatable, Sendable, Identifiable {

    public let kind: NotificationKind
    /// 触发时刻，精确到分。
    public let fireDate: Date

    /// 只暴露这一个构造器：**正文无法由外部指定**。
    public init(kind: NotificationKind, fireDate: Date) {
        self.kind = kind
        self.fireDate = fireDate
    }

    /// 系统请求标识。同一条重排时覆盖而不是叠加。
    public var id: String {
        switch kind {
        case .milestone(let d):            return "milestone_d\(d)"
        case .examDayMorning:              return "exam_day_morning"
        case .letterDue(let id, _):        return "letter_due_\(id)"
        case .letterNightBefore(let id):   return "letter_night_before_\(id)"
        }
    }

    public var title: String {
        switch kind {
        case .milestone, .examDayMorning:
            return Strings.Notifications.title
        case .letterDue, .letterNightBefore:
            return Strings.Letters.notificationTitle
        }
    }

    public var body: String {
        switch kind {
        case .milestone(let d):          return Strings.Notifications.milestone(d)
        case .examDayMorning:            return Strings.Notifications.examDayMorning
        case .letterDue(_, let daysAgo): return Strings.Letters.notificationBody(daysAgo: daysAgo)
        case .letterNightBefore:         return Strings.Letters.notificationBodyNightBefore
        }
    }
}

/// 排程需要知道的信件信息。**没有正文字段** —— 排程器拿不到，也就传不出去。
public struct LetterNotificationInput: Equatable, Sendable {
    public let id: String
    public let writtenAt: Date
    public let openAt: Date
    public let trigger: LetterTrigger
    public let isOpened: Bool
    /// 草稿不排通知 —— 它还没被托付出去。
    public let isDraft: Bool

    public init(id: String, writtenAt: Date, openAt: Date, trigger: LetterTrigger,
                isOpened: Bool, isDraft: Bool) {
        self.id = id; self.writtenAt = writtenAt; self.openAt = openAt
        self.trigger = trigger; self.isOpened = isOpened; self.isDraft = isDraft
    }
}

public enum NotificationPlanner {

    /// 打扰时刻。
    ///
    /// 资料只给了一个确定值：考前一晚那条定在 20:00（信件文案表 5.2，明确写了"不要更晚"）。
    /// 其余两个是**待确认**，取值理由写在这里，改动前先跟产品对一次：
    /// - 节点通知同样放 20:00 —— 全 App 只有一个"打扰时间点"，用户能形成预期；
    ///   且节点是回望性的（"已经走过多少"），晚间比清晨更合适。
    /// - 考试当天早上取 07:00 —— 高考首场 09:00 开考，需要留出出门的时间。
    public static let milestoneHour = 20
    public static let letterHour = Strings.Letters.nightBeforeNotificationHour
    public static let examMorningHour = 7

    /// iOS 对单个 App 的待处理本地通知上限是 64 条，超出的会被系统静默丢弃。
    /// 排程按时间升序截断，保证被丢的一定是最远的那些 —— 它们还会在下次重排时补回来。
    public static let systemPendingLimit = 64

    /// 「我们一年只会打扰你几次」是写在权限请求里的承诺（5.11）。
    /// 这是那句话的上限：节点 5 条 + 考试当天 1 条。有测试钉着。
    public static let maxNonLetterNotificationsPerCycle = Milestone.notificationTriggers.count + 1

    /// 生成排程。
    ///
    /// 只返回**将来**的通知：已经过去的时刻交给系统只会被立刻丢弃，
    /// 还会白白占掉 64 条额度里的名额。
    public static func plan(
        targetDate: Date,
        letters: [LetterNotificationInput],
        now: Date,
        cal: DayCalendar = .current
    ) -> [ScheduledNotification] {

        var result: [ScheduledNotification] = []

        for days in Milestone.notificationTriggers {
            let day = cal.adding(days: -days, to: targetDate)
            guard let fire = cal.time(hour: milestoneHour, on: day) else { continue }
            result.append(ScheduledNotification(kind: .milestone(daysRemaining: days), fireDate: fire))
        }

        if let fire = cal.time(hour: examMorningHour, on: targetDate) {
            result.append(ScheduledNotification(kind: .examDayMorning, fireDate: fire))
        }

        for letter in letters {
            // 草稿没有托付出去，已开启的不必再提醒。
            guard !letter.isDraft, !letter.isOpened else { continue }
            guard let fire = cal.time(hour: letterHour, on: letter.openAt) else { continue }
            let kind: NotificationKind
            if letter.trigger == .nightBefore {
                kind = .letterNightBefore(letterID: letter.id)
            } else {
                kind = .letterDue(
                    letterID: letter.id,
                    daysAgo: max(0, cal.days(from: letter.writtenAt, to: letter.openAt))
                )
            }
            result.append(ScheduledNotification(kind: kind, fireDate: fire))
        }

        return result
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }
            .prefix(systemPendingLimit)
            .map { $0 }
    }
}

/// 通知权限的请求时机（5.11）。
///
/// **绝不在首次启动时请求。** 引导里问权限，用户还没体会到通知有什么用，
/// 拒绝率高，而 iOS 的系统弹窗一生只出现一次 —— 拒了就再也没有第二次机会。
/// 时机是**第一次打卡之后**：那一刻用户刚刚做了一件和这个 App 有关的事。
public enum NotificationPermissionPolicy {

    public static func shouldRequest(hasCheckedInAtLeastOnce: Bool, alreadyAsked: Bool) -> Bool {
        hasCheckedInAtLeastOnce && !alreadyAsked
    }
}
