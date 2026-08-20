import XCTest
@testable import CountdownKit

final class HomeSummaryTests: XCTestCase {

    let cal = DayCalendar.fixed()
    lazy var today = cal.day(2026, 12, 2)

    private func digest(_ id: String, written: Date, open: Date,
                        opened: Bool = false, draft: Bool = false) -> LetterDigest {
        LetterDigest(id: id, writtenAt: written, openAt: open, isOpened: opened, isDraft: draft)
    }

    // MARK: - 信件提示条（信件文案表第 8 节）

    func testNoHintWhenNothingPending() {
        XCTAssertNil(HomeSummaryBuilder.letterHint(letters: [], today: today, cal: cal))
        let allOpened = [digest("L1", written: cal.day(2026, 8, 24), open: cal.day(2026, 12, 1), opened: true)]
        XCTAssertNil(HomeSummaryBuilder.letterHint(letters: allOpened, today: today, cal: cal))
    }

    func testDueTodayHint() {
        let letters = [digest("L1", written: cal.day(2026, 8, 24), open: today)]
        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: letters, today: today, cal: cal), .dueToday)
    }

    /// 5.6 边界：开启日已过但用户没打开 App → 下次打开时补触发。
    func testOverdueCountsAsDueToday() {
        let letters = [digest("L1", written: cal.day(2026, 8, 24), open: cal.day(2026, 11, 20))]
        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: letters, today: today, cal: cal), .dueToday)
    }

    /// 优先级：**今天到期 > 草稿未完成 > 即将开启**。
    func testHintPriorityOrder() {
        let due = digest("due", written: cal.day(2026, 8, 24), open: today)
        let draft = digest("draft", written: cal.day(2026, 12, 1), open: today, draft: true)
        let soon = digest("soon", written: cal.day(2026, 11, 1), open: cal.day(2026, 12, 9))

        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: [due, draft, soon], today: today, cal: cal),
                       .dueToday)
        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: [draft, soon], today: today, cal: cal),
                       .draftInProgress)
        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: [soon], today: today, cal: cal),
                       .upcoming(writtenDaysAgo: 31, inDays: 7))
    }

    /// 草稿没有"到期"这回事 —— 它还没封存。
    func testDraftNeverCountsAsDue() {
        let draft = digest("draft", written: cal.day(2026, 11, 1), open: cal.day(2026, 11, 1), draft: true)
        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: [draft], today: today, cal: cal),
                       .draftInProgress)
    }

    /// 30 天窗口内才提示（5.6）。
    func testUpcomingWindow() {
        let exactly30 = [digest("L1", written: cal.day(2026, 8, 24), open: cal.day(2027, 1, 1))]
        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: exactly30, today: today, cal: cal),
                       .upcoming(writtenDaysAgo: 100, inDays: 30))

        let beyond = [digest("L1", written: cal.day(2026, 8, 24), open: cal.day(2027, 1, 2))]
        XCTAssertNil(HomeSummaryBuilder.letterHint(letters: beyond, today: today, cal: cal))
    }

    func testNearestUpcomingWins() {
        let letters = [
            digest("far", written: cal.day(2026, 10, 1), open: cal.day(2026, 12, 25)),
            digest("near", written: cal.day(2026, 11, 1), open: cal.day(2026, 12, 5)),
        ]
        XCTAssertEqual(HomeSummaryBuilder.letterHint(letters: letters, today: today, cal: cal),
                       .upcoming(writtenDaysAgo: 31, inDays: 3))
    }

    /// 提示条逻辑**不碰正文** —— LetterDigest 里根本没有那个字段（D-08）。
    func testHintNeverTouchesLetterBody() {
        let names = Mirror(reflecting: digest("L1", written: today, open: today))
            .children.compactMap(\.label)
        XCTAssertFalse(names.contains("content"))
        XCTAssertFalse(names.contains("sealedContent"))
    }

    // MARK: - 节点卡触发

    private func countdown(remaining: Int) -> Countdown {
        CountdownEngine(cal: cal).countdown(
            startDate: cal.day(2025, 3, 22),
            targetDate: cal.adding(days: remaining, to: today),
            today: today
        )
    }

    func testMilestoneTriggersOnNodeDay() {
        XCTAssertEqual(
            HomeSummaryBuilder.pendingMilestone(countdown: countdown(remaining: 100), shownMilestoneDays: [])?
                .daysRemaining,
            100
        )
        XCTAssertNil(HomeSummaryBuilder.pendingMilestone(countdown: countdown(remaining: 98), shownMilestoneDays: []))
    }

    /// 5.8.2：每个节点只触发一次，用户关闭后不再重复弹出。
    func testMilestoneDoesNotRepeatOnceShown() {
        XCTAssertNil(
            HomeSummaryBuilder.pendingMilestone(countdown: countdown(remaining: 100), shownMilestoneDays: [100])
        )
        // 但别的节点仍会触发
        XCTAssertNotNil(
            HomeSummaryBuilder.pendingMilestone(countdown: countdown(remaining: 50), shownMilestoneDays: [100])
        )
    }

    /// 99 天（进入两位数）发卡，但不发通知。
    func testNinetyNineTriggersCardOnly() {
        let c = countdown(remaining: 99)
        XCTAssertNotNil(HomeSummaryBuilder.pendingMilestone(countdown: c, shownMilestoneDays: []))
        XCTAssertFalse(c.milestone.triggersNotification)
    }

    // MARK: - 整体

    private func build(
        totalCheckIns: Int = 128,
        previous: Int = 128,
        census: Int? = 412_000,
        checkedIn: Bool = false
    ) -> HomeSummary {
        HomeSummaryBuilder.build(
            examTitle: "高考",
            startDate: cal.day(2025, 3, 22),
            targetDate: cal.day(2027, 6, 7),
            today: today,
            totalCheckIns: totalCheckIns,
            totalNotes: 36,
            hasCheckedInToday: checkedIn,
            letters: [],
            censusCount: census,
            shownMilestoneDays: [],
            previousTotalCheckIns: previous,
            cal: cal
        )
    }

    func testSummaryMatchesPrototypeNumbers() {
        let s = build()
        XCTAssertEqual(s.countdown.daysRemaining, 187)
        XCTAssertEqual(s.countdown.daysPassed, 620)
        XCTAssertEqual(s.totalCheckIns, 128)
        XCTAssertEqual(s.censusDisplay, "41.2")
    }

    /// 验收标准（5.3）：断更 30 天后重新打开，累计天数保持不变。
    /// 首页不该出现任何随"多久没来"变化的量。
    func testSummaryHasNoStreakOrAbsenceConcept() {
        let names = Mirror(reflecting: build()).children.compactMap(\.label)
        for forbidden in ["streak", "consecutive", "daysSinceLastCheckIn", "missedDays"] {
            XCTAssertFalse(names.contains(forbidden), "首页不得出现 \(forbidden)")
        }
    }

    func testCensusHiddenBelowThreshold() {
        XCTAssertNil(build(census: 9_999).censusDisplay)
        XCTAssertNil(build(census: nil).censusDisplay)
    }

    /// 皮肤解锁只在跨过阈值那一次提示。
    func testSkinUnlockFiresOnceAtThreshold() {
        XCTAssertEqual(build(totalCheckIns: 30, previous: 29).newlyUnlockedSkinCheckInDays, 30)
        XCTAssertNil(build(totalCheckIns: 31, previous: 30).newlyUnlockedSkinCheckInDays)
        XCTAssertNil(build(totalCheckIns: 29, previous: 28).newlyUnlockedSkinCheckInDays)
        XCTAssertEqual(build(totalCheckIns: 100, previous: 99).newlyUnlockedSkinCheckInDays, 100)
    }

    /// 补签一次跨过阈值也算解锁（补签计入累计天数）。
    func testBackfillCrossingThresholdAlsoUnlocks() {
        XCTAssertEqual(build(totalCheckIns: 32, previous: 28).newlyUnlockedSkinCheckInDays, 30)
    }
}
