import XCTest
@testable import CountdownKit

final class OnboardingTests: XCTestCase {

    let cal = DayCalendar.fixed()
    lazy var model = OnboardingModel(cal: cal)
    lazy var today = cal.day(2026, 12, 2)

    // MARK: - 第 1 屏

    func testInitialStateDefaultsToGaokao() {
        let s = model.initial(today: today)
        XCTAssertEqual(s.step, .type)
        XCTAssertEqual(s.examType, .gaokao)
        XCTAssertEqual(s.targetDate, cal.day(2027, 6, 7))
        XCTAssertEqual(s.startDate, cal.day(2024, 9, 1))
    }

    /// **选中即前进**，不设「继续」按钮 —— 少一次点击。
    func testSelectingTypeAdvancesImmediately() {
        let s = model.selectType(.kaoyan, today: today)
        XCTAssertEqual(s.step, .target)
    }

    /// 一步定型：选类型同时决定后面两屏的默认值。
    func testSelectingTypeRecomputesBothDates() {
        // 今天是 2026-12-02，当年考研日 2026-12-12 尚未过，所以不顺延次年。
        let s = model.selectType(.kaoyan, today: today)
        XCTAssertEqual(s.targetDate, cal.day(2026, 12, 12))
        XCTAssertEqual(s.startDate, cal.day(2026, 3, 1))
    }

    /// 默认起始日期晚于今天时回落为今天（5.1 边界情况）。
    func testDefaultStartFallsBackToToday() {
        // 1 月装机的考研用户：目标 2027-12-11，默认起始 2027-03-01 还没到
        let early = cal.day(2027, 1, 10)
        let s = model.selectType(.kaoyan, today: early)
        XCTAssertEqual(s.targetDate, cal.day(2027, 12, 11))
        XCTAssertEqual(s.startDate, early)
    }

    /// 自定义考试没有默认目标日期，用选择器初值兜底，不留空。
    func testCustomTypeGetsPickerSeed() {
        let s = model.selectType(.custom, today: today)
        XCTAssertEqual(s.targetDate, cal.day(2027, 1, 2))
        XCTAssertEqual(s.startDate, today)
    }

    // MARK: - 第 2 屏

    func testTargetInPastBlocksContinue() {
        var s = model.selectType(.gaokao, today: today)
        s = model.setTarget(cal.day(2026, 6, 7), in: s)
        XCTAssertEqual(model.targetIssue(in: s, today: today), .inPast(suggestedYear: 2027))
        XCTAssertFalse(model.canLeaveTargetStep(s, today: today))
        XCTAssertEqual(model.next(s, today: today).step, .target) // 原地不动
    }

    func testRollToNextYearFixesIt() {
        var s = model.selectType(.gaokao, today: today)
        s = model.setTarget(cal.day(2026, 6, 7), in: s)
        s = model.rollTargetToNextYear(in: s)
        XCTAssertEqual(s.targetDate, cal.day(2027, 6, 7))
        XCTAssertTrue(model.canLeaveTargetStep(s, today: today))
    }

    /// 改考试日期**不联动改起点** —— 用户改考期不代表他想改起点。
    func testChangingTargetDoesNotSilentlyMoveStart() {
        let s = model.selectType(.gaokao, today: today)
        let original = s.startDate
        let changed = model.setTarget(cal.day(2028, 6, 7), in: s)
        XCTAssertEqual(changed.startDate, original)
    }

    // MARK: - 第 3 屏

    /// 起始 ≥ 目标 → 阻断，「好了」置灰。
    func testStartAfterTargetBlocksFinish() {
        var s = model.selectType(.gaokao, today: today)
        s.step = .start
        s = model.setStart(cal.day(2028, 1, 1), source: .manual, in: s)
        XCTAssertEqual(model.startIssue(in: s, today: today), .notBeforeTarget)
        XCTAssertFalse(model.canFinish(s, today: today))
        XCTAssertEqual(model.next(s, today: today).step, .start)
    }

    /// 起始 > 今天 → 提醒但**允许继续**。
    /// 不强制用开学日 —— 复读生、在职考生的起点不一样。
    func testStartInFutureWarnsButAllows() {
        var s = model.selectType(.gaokao, today: today)
        s.step = .start
        s = model.setStart(cal.day(2027, 1, 1), source: .manual, in: s)
        XCTAssertEqual(model.startIssue(in: s, today: today), .inFuture)
        XCTAssertTrue(model.canFinish(s, today: today))
        XCTAssertEqual(model.next(s, today: today).step, .result)
    }

    func testQuickStartsFollowExamType() {
        let gaokao = model.selectType(.gaokao, today: today)
        XCTAssertEqual(model.quickStarts(in: gaokao, today: today).map(\.title),
                       ["高一开学", "高三开学", "今天"])
        let kaoyan = model.selectType(.kaoyan, today: today)
        XCTAssertEqual(model.quickStarts(in: kaoyan, today: today).map(\.title),
                       ["决定要考的那天", "今天"])
    }

    func testQuickStartRecordsSource() {
        var s = model.selectType(.gaokao, today: today)
        let quick = model.quickStarts(in: s, today: today)[1]
        s = model.setStart(quick.date, source: .quick, in: s)
        XCTAssertEqual(s.startDate, cal.day(2026, 9, 1))
        XCTAssertEqual(s.startSource, .quick)
    }

    // MARK: - 导航

    func testBackButtonVisibility() {
        XCTAssertFalse(OnboardingState.Step.type.showsBackButton)
        XCTAssertTrue(OnboardingState.Step.target.showsBackButton)
        XCTAssertTrue(OnboardingState.Step.start.showsBackButton)
        XCTAssertFalse(OnboardingState.Step.result.showsBackButton)
    }

    /// 第 4 屏隐藏顶部导航 —— 不可跳过，全产品唯一一次允许强制观看。
    func testResultScreenHidesNavigation() {
        XCTAssertFalse(OnboardingState.Step.result.showsNavigation)
        for step in [OnboardingState.Step.type, .target, .start] {
            XCTAssertTrue(step.showsNavigation)
        }
    }

    func testBackNeverLeavesResultScreen() {
        var s = model.initial(today: today)
        s.step = .result
        XCTAssertEqual(model.back(s).step, .result)
    }

    func testStepIndicator() {
        var s = model.initial(today: today)
        XCTAssertEqual(s.litStepCount, 1)
        s.step = .start
        XCTAssertEqual(s.litStepCount, 3)
    }

    // MARK: - 跳过

    /// 跳过 = 按当前默认值走完全部三屏，**仍进入第 4 屏**。
    /// 必须让用户看到那个数字。
    func testSkipFromFirstStepLandsOnResult() {
        let s = model.skip(model.initial(today: today), today: today)
        XCTAssertEqual(s.step, .result)
        XCTAssertEqual(s.examType, .gaokao)
    }

    func testSkipFromAnyStepLandsOnResult() {
        for step in [OnboardingState.Step.type, .target, .start] {
            var s = model.initial(today: today)
            s.step = step
            XCTAssertEqual(model.skip(s, today: today).step, .result, "\(step)")
        }
    }

    /// 跳过不得把坏数据带进首页：默认值不合法时停在出问题的那一屏。
    func testSkipStopsAtInvalidStep() {
        var s = model.initial(today: today)
        s = model.setTarget(cal.day(2020, 6, 7), in: s)
        XCTAssertEqual(model.skip(s, today: today).step, .target)

        var t = model.initial(today: today)
        t = model.setStart(cal.day(2028, 1, 1), source: .manual, in: t)
        XCTAssertEqual(model.skip(t, today: today).step, .start)
    }

    /// 每种考试类型跳过后都能直达第 4 屏 —— 对应验收标准
    /// 「跳过任何可选项后仍能进入首页」。
    func testSkipWorksForEveryExamType() {
        for type in ExamType.allCases {
            let s = model.skip(model.selectType(type, today: today), today: today)
            XCTAssertEqual(s.step, .result, "\(type)")
            let r = model.result(s, today: today)
            XCTAssertGreaterThan(r.totalDays, 0, "\(type)")
            XCTAssertGreaterThanOrEqual(r.daysPassed, 0, "\(type)")
        }
    }

    // MARK: - 第 4 屏

    func testResultNumbers() {
        var s = model.initial(today: today)
        s = model.setStart(cal.day(2025, 3, 22), source: .manual, in: s)
        let r = model.result(s, today: today)
        XCTAssertEqual(r.daysPassed, 620)
        XCTAssertEqual(r.daysRemaining, 187)
        XCTAssertEqual(r.totalDays, 807)
    }
}
