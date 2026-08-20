import XCTest
@testable import CountdownKit

final class NotificationPlanTests: XCTestCase {

    private let cal = DayCalendar.fixed()
    /// 2027 高考首日。
    private var target: Date { cal.day(2027, 6, 7) }

    private func letter(
        id: String = "L1",
        writtenAt: Date,
        openAt: Date,
        trigger: LetterTrigger = .custom,
        isOpened: Bool = false,
        isDraft: Bool = false
    ) -> LetterNotificationInput {
        LetterNotificationInput(id: id, writtenAt: writtenAt, openAt: openAt,
                                trigger: trigger, isOpened: isOpened, isDraft: isDraft)
    }

    // MARK: - 节点

    /// 还剩 100 天那条应落在 target − 100 天的 20:00。
    func testMilestoneFiresOnTheRightDayAtTheRightHour() {
        let plan = NotificationPlanner.plan(
            targetDate: target, letters: [], now: cal.day(2026, 1, 1), cal: cal
        )
        guard let d100 = plan.first(where: { $0.kind == .milestone(daysRemaining: 100) }) else {
            return XCTFail("缺少 100 天节点通知")
        }
        XCTAssertTrue(cal.isSameDay(d100.fireDate, cal.adding(days: -100, to: target)))
        XCTAssertEqual(cal.calendar.component(.hour, from: d100.fireDate),
                       NotificationPlanner.milestoneHour)
        // 那一天到考试确实还剩 100 天 —— 防止排程和倒计时用两套算法。
        XCTAssertEqual(cal.days(from: d100.fireDate, to: target), 100)
    }

    /// **99 递卡但不推送。** 两份清单不同是有意的，不是漏写。
    /// 每多打扰一次，就离「我们一年只会打扰你几次」远一点。
    func testNinetyNineGetsACardButNoNotification() {
        XCTAssertTrue(Milestone(daysRemaining: 99).triggersCard)
        XCTAssertFalse(Milestone(daysRemaining: 99).triggersNotification)

        let plan = NotificationPlanner.plan(
            targetDate: target, letters: [], now: cal.day(2026, 1, 1), cal: cal
        )
        XCTAssertFalse(plan.contains { $0.kind == .milestone(daysRemaining: 99) })
    }

    /// 权限请求里写着「我们一年只会打扰你几次」。这条测试是那句话的合同。
    /// 想加一个节点，先得先改这个上限，改的时候会看见这段注释。
    func testWholeCycleStaysWithinThePromisedFewInterruptions() {
        let plan = NotificationPlanner.plan(
            targetDate: target, letters: [], now: cal.day(2026, 1, 1), cal: cal
        )
        XCTAssertEqual(plan.count, NotificationPlanner.maxNonLetterNotificationsPerCycle)
        XCTAssertLessThanOrEqual(plan.count, 6)
    }

    /// 已经过去的节点不排。交给系统只会被立刻丢弃，还白占 64 条额度里的名额。
    func testPastMilestonesAreNotScheduled() {
        // 距考试只剩 20 天：100 / 50 / 30 都已过去。
        let now = cal.adding(days: -20, to: target)
        let plan = NotificationPlanner.plan(targetDate: target, letters: [], now: now, cal: cal)

        XCTAssertFalse(plan.contains { $0.kind == .milestone(daysRemaining: 100) })
        XCTAssertFalse(plan.contains { $0.kind == .milestone(daysRemaining: 50) })
        XCTAssertFalse(plan.contains { $0.kind == .milestone(daysRemaining: 30) })
        XCTAssertTrue(plan.contains { $0.kind == .milestone(daysRemaining: 10) })
        XCTAssertTrue(plan.contains { $0.kind == .milestone(daysRemaining: 1) })
        XCTAssertTrue(plan.allSatisfy { $0.fireDate > now })
    }

    func testPlanIsSortedByFireDate() {
        let plan = NotificationPlanner.plan(
            targetDate: target,
            letters: [letter(writtenAt: cal.day(2026, 3, 1), openAt: cal.day(2027, 2, 1))],
            now: cal.day(2026, 1, 1), cal: cal
        )
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
    }

    // MARK: - 信件

    /// 草稿不排通知 —— 它还没被托付出去，用户随时可能删掉或改写。
    func testDraftLettersAreNotScheduled() {
        let plan = NotificationPlanner.plan(
            targetDate: target,
            letters: [letter(writtenAt: cal.day(2026, 3, 1),
                             openAt: cal.day(2027, 2, 1), isDraft: true)],
            now: cal.day(2026, 1, 1), cal: cal
        )
        XCTAssertFalse(plan.contains { if case .letterDue = $0.kind { return true }; return false })
    }

    func testOpenedLettersAreNotScheduled() {
        let plan = NotificationPlanner.plan(
            targetDate: target,
            letters: [letter(writtenAt: cal.day(2026, 3, 1),
                             openAt: cal.day(2027, 2, 1), isOpened: true)],
            now: cal.day(2026, 1, 1), cal: cal
        )
        XCTAssertFalse(plan.contains { if case .letterDue = $0.kind { return true }; return false })
    }

    /// 正文只说"多久以前写的"，天数取自 写信日 → 开启日。
    func testLetterBodyCarriesOnlyTheElapsedDays() {
        let writtenAt = cal.day(2026, 3, 1)
        let openAt = cal.day(2027, 2, 1)
        let plan = NotificationPlanner.plan(
            targetDate: target, letters: [letter(writtenAt: writtenAt, openAt: openAt)],
            now: cal.day(2026, 1, 1), cal: cal
        )
        guard let due = plan.first(where: {
            if case .letterDue = $0.kind { return true }; return false
        }) else { return XCTFail("缺少信件到期通知") }

        let days = cal.days(from: writtenAt, to: openAt)
        XCTAssertEqual(due.kind, .letterDue(letterID: "L1", daysAgo: days))
        XCTAssertEqual(due.body, Strings.Letters.notificationBody(daysAgo: days))
        XCTAssertEqual(due.title, Strings.Letters.notificationTitle)
    }

    /// 考前一晚那封信用另一句文案（文案表 5.2），且时刻是 20:00 —— 不该在临睡前打扰。
    func testNightBeforeLetterUsesItsOwnCopyAndHour() {
        let openAt = cal.adding(days: -1, to: target)
        let plan = NotificationPlanner.plan(
            targetDate: target,
            letters: [letter(writtenAt: cal.day(2026, 3, 1), openAt: openAt, trigger: .nightBefore)],
            now: cal.day(2026, 1, 1), cal: cal
        )
        guard let night = plan.first(where: { $0.kind == .letterNightBefore(letterID: "L1") }) else {
            return XCTFail("缺少考前一晚通知")
        }
        XCTAssertEqual(night.body, Strings.Letters.notificationBodyNightBefore)
        XCTAssertEqual(cal.calendar.component(.hour, from: night.fireDate), 20)
    }

    /// **通知不得成为偷看封存信件的旁路（D-08）。**
    ///
    /// 结构上已经保证：`LetterNotificationInput` 没有正文字段，
    /// `ScheduledNotification` 也没有接受 body 的构造器。
    /// 这条测试守的是"以后有人给它加一个"——加了这里就会红。
    func testNotificationCannotCarryLetterContent() {
        let mirror = Mirror(reflecting: letter(writtenAt: .now, openAt: .now))
        let names = mirror.children.compactMap(\.label)
        XCTAssertFalse(names.contains("content"))
        XCTAssertFalse(names.contains("sealedContent"))
        XCTAssertFalse(names.contains("revealedContent"))
    }

    // MARK: - 系统上限

    /// iOS 只保留 64 条待处理通知，多出的会被静默丢弃。
    /// 截断必须发生在**排序之后**，被丢的才是最远的那些 —— 它们下次重排会补回来。
    func testPlanIsTruncatedToTheSystemLimitKeepingTheNearestOnes() {
        let many = (0..<120).map {
            letter(id: "L\($0)",
                   writtenAt: cal.day(2026, 1, 1),
                   openAt: cal.adding(days: $0 + 1, to: cal.day(2026, 1, 1)))
        }
        let plan = NotificationPlanner.plan(
            targetDate: target, letters: many, now: cal.day(2026, 1, 1), cal: cal
        )
        XCTAssertEqual(plan.count, NotificationPlanner.systemPendingLimit)

        let latestKept = plan.map(\.fireDate).max()!
        // 被留下的一定是最近的那批：不存在"被丢掉的比留下的更早"。
        XCTAssertTrue(plan.allSatisfy { $0.fireDate <= latestKept })
        XCTAssertTrue(cal.isSameDay(plan[0].fireDate, cal.day(2026, 1, 2)))
    }

    // MARK: - 权限时机

    /// **绝不在首次启动时请求。** iOS 的系统弹窗一生只出现一次，
    /// 在用户还没体会到通知有什么用的时候问，等于把这个机会浪费掉。
    func testPermissionIsNeverRequestedBeforeTheFirstCheckIn() {
        XCTAssertFalse(NotificationPermissionPolicy.shouldRequest(
            hasCheckedInAtLeastOnce: false, alreadyAsked: false))
        XCTAssertTrue(NotificationPermissionPolicy.shouldRequest(
            hasCheckedInAtLeastOnce: true, alreadyAsked: false))
        XCTAssertFalse(NotificationPermissionPolicy.shouldRequest(
            hasCheckedInAtLeastOnce: true, alreadyAsked: true))
    }
}
