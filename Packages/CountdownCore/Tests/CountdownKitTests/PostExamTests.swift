import XCTest
@testable import CountdownKit

/// 考后接力（5.12 / 《V1 剩余页面》第六节）。
///
/// 这一组守的是三件事：环每段重新填、缺失的日程不编、以及**任何一句都不带情绪预设**。
final class PostExamTests: XCTestCase {

    private let cal = DayCalendar.fixed()
    private lazy var engine = PostExamEngine(cal: cal)

    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.day(y, m, day) }

    /// 高考：6/7 考，6/24 出分，9/1 开学（填报截止未知）。
    private var gaokao: PostExamSchedule {
        PostExamSchedule(resultDay: d(2026, 6, 24), applicationDeadline: nil,
                         schoolStart: d(2026, 9, 1))
    }

    // MARK: - 阶段

    func testBeforeExamThereIsNoPostExamState() {
        XCTAssertNil(engine.state(targetDate: d(2026, 6, 7), schedule: gaokao,
                                  today: d(2026, 6, 6)))
    }

    /// 考试当天满环、树开花，中心大字由视图渲染成「今天」而不是 0。
    func testExamDayIsItsOwnPhaseAtFullRing() {
        let s = engine.state(targetDate: d(2026, 6, 7), schedule: gaokao, today: d(2026, 6, 7))
        XCTAssertEqual(s?.phase, .examDay)
        XCTAssertEqual(s?.daysRemaining, 0)
        XCTAssertEqual(s?.progress ?? 0, 1, accuracy: 1e-9)
        // 考试当天不给切换提示 —— 那一天不需要我们说话。
        XCTAssertNil(s?.notice)
    }

    /// 环**每段重新从 0 填充**（6.1）。
    ///
    /// 这条容易被"优化"成从考试日到开学日的一整条进度 —— 那样等出分的两周里
    /// 环几乎不动，而那恰好是最需要看见"在走"的两周。
    func testEachPhaseRefillsTheRingFromZero() {
        // 6/7 考完，6/24 出分：区间 17 天。
        let firstDay = engine.state(targetDate: d(2026, 6, 7), schedule: gaokao,
                                    today: d(2026, 6, 8))
        XCTAssertEqual(firstDay?.phase, .awaitingResult)
        XCTAssertEqual(firstDay?.daysRemaining, 16)
        XCTAssertEqual(firstDay?.progress ?? 0, 1.0 / 17.0, accuracy: 1e-9)

        // 换到下一段（填报截止未知，所以直接进等开学），环重新从接近 0 开始。
        let nextPhase = engine.state(targetDate: d(2026, 6, 7), schedule: gaokao,
                                     today: d(2026, 6, 25))
        XCTAssertEqual(nextPhase?.phase, .awaitingSchool)
        XCTAssertLessThan(nextPhase?.progress ?? 1, 0.02,
                          "切段之后环必须几乎是空的，不能接着上一段的填充度")
    }

    /// 出分日**当天仍属「等出分」**且剩余 0 天 —— 对应「今天出分。」。
    /// 出分日不是等待的结束，是等待的最后一天。
    func testResultDayIsTheLastDayOfWaitingNotTheFirstDayAfter() {
        let s = engine.state(targetDate: d(2026, 6, 7), schedule: gaokao, today: d(2026, 6, 24))
        XCTAssertEqual(s?.phase, .awaitingResult)
        XCTAssertEqual(s?.daysRemaining, 0)
        XCTAssertEqual(s?.notice, .resultDay)
    }

    /// 日程缺一段就**整段跳过**，不编日期填补。
    ///
    /// 编一个"看起来合理"的填报截止日，用户会照着它去等，
    /// 然后在错误的那天打开 App 发现已经截止了。
    func testMissingSegmentsAreSkippedNotInvented() {
        let s = engine.state(targetDate: d(2026, 6, 7), schedule: gaokao, today: d(2026, 7, 1))
        XCTAssertEqual(s?.phase, .awaitingSchool,
                       "填报截止日未知时应直接进入等开学，而不是虚构一段填报期")
    }

    func testNothingKnownMeansNoRelayAtAll() {
        let s = engine.state(targetDate: d(2026, 6, 7), schedule: PostExamSchedule.unknown, today: d(2026, 6, 20))
        XCTAssertNil(s, "没有任何日程数据时不应该编出一个阶段")
    }

    func testAfterEverythingTheRelayEnds() {
        XCTAssertNil(engine.state(targetDate: d(2026, 6, 7), schedule: gaokao,
                                  today: d(2026, 9, 2)))
    }

    /// 日程本身不自洽（出分日早于考试日）时跳过那一段，不 crash、不出负数。
    func testInconsistentScheduleIsSkippedRatherThanCrashing() {
        let broken = PostExamSchedule(resultDay: d(2026, 6, 1), schoolStart: d(2026, 9, 1))
        let s = engine.state(targetDate: d(2026, 6, 7), schedule: broken, today: d(2026, 6, 10))
        XCTAssertEqual(s?.phase, .awaitingSchool)
        XCTAssertGreaterThan(s?.daysRemaining ?? -1, 0)
    }

    // MARK: - 切换提示

    /// 出分日那条提示需要和"考完次日"那条用**不同的 flag**，
    /// 否则出分日会被前一条顶掉，用户永远看不到「今天出分。」。
    func testResultDayNoticeHasItsOwnFlag() {
        let dayAfter = engine.state(targetDate: d(2026, 6, 7), schedule: gaokao,
                                    today: d(2026, 6, 8))
        let resultDay = engine.state(targetDate: d(2026, 6, 7), schedule: gaokao,
                                     today: d(2026, 6, 24))
        XCTAssertNotNil(dayAfter?.noticeFlagKey)
        XCTAssertNotNil(resultDay?.noticeFlagKey)
        XCTAssertNotEqual(dayAfter?.noticeFlagKey, resultDay?.noticeFlagKey)
    }

    /// 6.3 强约束：考后所有文案必须经得起"考砸的人看到"这一关。
    func testNoPostExamCopyPresumesAGoodResult() {
        let all = [
            PostExamNotice.examEnded(daysToResult: 15).text,
            PostExamNotice.resultDay.text,
            PostExamNotice.applicationOpened(daysLeft: 6).text,
            PostExamNotice.schoolCountdownStarted(days: 71).text,
            Strings.PostExam.examDayCaption(totalDays: 1010),
            Strings.PostExam.frozenTotal(315),
            Strings.PostExam.frozenCaption,
        ]
        for s in all {
            for banned in ["恭喜", "祝贺", "加油", "圆梦", "金榜", "旗开得胜", "！", "!"] {
                XCTAssertFalse(s.contains(banned), "「\(banned)」出现在：\(s)")
            }
        }
    }

    func testNoticeTextsMatchTheSpec() {
        XCTAssertEqual(PostExamNotice.examEnded(daysToResult: 15).text,
                       "考完了。\n下一件事是出分，还有 15 天。")
        XCTAssertEqual(PostExamNotice.resultDay.text, "今天出分。")
        XCTAssertEqual(PostExamNotice.applicationOpened(daysLeft: 6).text,
                       "可以填志愿了，6 天后截止。")
        XCTAssertEqual(PostExamNotice.schoolCountdownStarted(days: 71).text,
                       "还有 71 天开学。")
        XCTAssertEqual(Strings.PostExam.examDayCaption(totalDays: 1010), "你已经走过 1010 天")
    }

    // MARK: - 心理支持入口

    /// 出分日前 3 天至后 14 天，心理支持上移至设置页第一项。
    func testMentalHealthEntryRisesAroundResultDay() {
        let resultDay = d(2026, 6, 24)
        XCTAssertFalse(engine.mentalHealthGoesFirst(resultDay: resultDay, today: d(2026, 6, 20)))
        XCTAssertTrue(engine.mentalHealthGoesFirst(resultDay: resultDay, today: d(2026, 6, 21)))
        XCTAssertTrue(engine.mentalHealthGoesFirst(resultDay: resultDay, today: d(2026, 6, 24)))
        XCTAssertTrue(engine.mentalHealthGoesFirst(resultDay: resultDay, today: d(2026, 7, 8)))
        XCTAssertFalse(engine.mentalHealthGoesFirst(resultDay: resultDay, today: d(2026, 7, 9)))
    }

    /// 没有出分日数据时不上移 —— 不知道哪天出分，就没有"出分日前后"这回事。
    func testMentalHealthEntryStaysPutWithoutAResultDay() {
        XCTAssertFalse(engine.mentalHealthGoesFirst(resultDay: Date?.none, today: d(2026, 6, 24)))
    }

    // MARK: - 内置日程表

    /// **只有确实存在全国口径的项才给值。**
    ///
    /// 填报截止日逐省不同且逐年公布，给一个"平均值"会让某些省的用户
    /// 以为还有一周，实际昨天就截止了 —— 这个错误的代价是一整年。
    func testNationalApproximationOnlyFillsWhatIsActuallyNational() {
        let s = PostExamScheduleTable.schedule(
            examType: .gaokao, province: nil, targetDate: d(2026, 6, 7), cal: cal)
        XCTAssertEqual(s.resultDay, d(2026, 6, 24))
        XCTAssertEqual(s.schoolStart, d(2026, 9, 1))
        XCTAssertNil(s.applicationDeadline, "填报截止日没有全国口径，不许编")
    }

    /// 中考 / 考研 / 考公没有稳定的全国口径，一项都不给。
    func testOtherExamTypesGetNothingRatherThanAGuess() {
        for type in [ExamType.zhongkao, .kaoyan, .kaogong, .custom] {
            let s = PostExamScheduleTable.schedule(
                examType: type, province: nil, targetDate: d(2026, 6, 7), cal: cal)
            XCTAssertEqual(s, PostExamSchedule.unknown, "\(type) 不该有编出来的日程")
        }
    }
}
