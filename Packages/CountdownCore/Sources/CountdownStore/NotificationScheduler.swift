import Foundation
import CountdownKit

#if canImport(UserNotifications)
import UserNotifications

/// 把 `NotificationPlanner` 算出的排程交给系统。
///
/// # 全量重排，不做增量
/// 每次调用先 `removeAllPendingNotificationRequests` 再整批重排。
/// 增量更新需要知道"上次排了什么"，那是个可推导的值 —— 存下来就会和真相分叉：
/// 用户改了考试日期，残留的旧请求会在错误的日子推送错误的天数，而且没有任何地方能发现。
/// 全量重排让系统里的待处理队列**永远等于**当前数据推导出的结果。
///
/// # 不抛错
/// 通知是锦上添花。权限被拒、系统队列满、排程失败，都不该让调用方有机会
/// 把它变成一个 UI 上的错误态 —— 用户没有因此损失任何数据。
public struct NotificationScheduler: Sendable {

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// 请求权限。**只在第一次打卡之后调用**（5.11），调用方用
    /// `NotificationPermissionPolicy.shouldRequest` 判断时机。
    ///
    /// 返回是否已授权。拒绝不是失败 —— 不弹二次说服，iOS 也不会再给第二次机会。
    @discardableResult
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// 全量重排。未授权时只清空，不排新的。
    public func reschedule(
        targetDate: Date,
        letters: [LetterNotificationInput],
        now: Date = .now,
        cal: DayCalendar = .current
    ) async {
        center.removeAllPendingNotificationRequests()

        guard await authorizationStatus() == .authorized else { return }

        let plan = NotificationPlanner.plan(
            targetDate: targetDate, letters: letters, now: now, cal: cal
        )

        for item in plan {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let comps = cal.calendar.dateComponents(
                [.year, .month, .day, .hour, .minute], from: item.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: item.id, content: content, trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// 关掉全部通知（设置页开关关闭时）。
    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
#endif
