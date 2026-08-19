import XCTest
@testable import CountdownKit

final class CountdownEngineTests: XCTestCase {

    let cal = DayCalendar.fixed()
    lazy var engine = CountdownEngine(cal: cal)

    /// 原型首页展示的那组数字：已走过 620 / 还剩 187 / 总 807 / 环填充 76.8%。
    ///
    /// 注意：原型的 start 是为了凑出这组数字反推的（2025-03-22），
    /// 与引导默认起始日（目标年份 −3 的 9/1）不一致 —— 那是 demo 数据，不是规则。
    /// 这里锁的是**恒等式**：已走过 + 还剩 = 总跨度，且环填充 = 已走过 / 总跨度。
    func testPrototypeHomeNumbers() {
        let start = cal.day(2025, 3, 22)
        let target = cal.day(2027, 6, 7)
        let today = cal.day(2026, 12, 2)
        let c = engine.countdown(startDate: start, targetDate: target, today: today)

        XCTAssertEqual(c.daysPassed, 620)
        XCTAssertEqual(c.daysRemaining, 187)
        XCTAssertEqual(c.totalDays, 807)
        XCTAssertEqual(c.daysPassed + c.daysRemaining, c.totalDays)
        XCTAssertEqual(c.progress, 620.0 / 807.0, accuracy: 1e-9)
        XCTAssertEqual((c.progress * 1000).rounded() / 10, 76.8, accuracy: 1e-9)
        XCTAssertEqual(c.growthStage, .lush)
    }

    /// 设计决策 D-01：progress 是「已走过比例」，不是打卡完成率。
    func testProgressIsPassedOverTotal() {
        let start = cal.day(2026, 1, 1)
        let target = cal.day(2026, 1, 11)   // 总 10 天
        let today = cal.day(2026, 1, 4)     // 已走过 3 天
        let c = engine.countdown(startDate: start, targetDate: target, today: today)
        XCTAssertEqual(c.progress, 0.3, accuracy: 1e-9)
        XCTAssertEqual(c.daysRemaining, 7)
    }

    /// 引导第 3 屏允许起始日期设在未来（提示「已走过会是 0 天」但放行）。
    /// 首页绝不能因此出现负数。
    func testStartInFutureClampsToZero() {
        let c = engine.countdown(
            startDate: cal.day(2027, 1, 1),
            targetDate: cal.day(2027, 6, 7),
            today: cal.day(2026, 12, 2)
        )
        XCTAssertEqual(c.daysPassed, 0)
        XCTAssertEqual(c.progress, 0)
        XCTAssertEqual(c.growthStage, .seed)
    }

    func testExamDay() {
        let c = engine.countdown(
            startDate: cal.day(2024, 9, 1),
            targetDate: cal.day(2027, 6, 7),
            today: cal.day(2027, 6, 7)
        )
        XCTAssertEqual(c.daysRemaining, 0)
        XCTAssertTrue(c.isExamDay)
        XCTAssertFalse(c.isAfterExam)
        XCTAssertEqual(c.progress, 1.0)
        XCTAssertEqual(c.growthStage, .blooming)
    }

    func testAfterExamProgressClampedButRawExceedsOne() {
        let c = engine.countdown(
            startDate: cal.day(2026, 1, 1),
            targetDate: cal.day(2026, 1, 11),
            today: cal.day(2026, 1, 21)
        )
        XCTAssertEqual(c.daysRemaining, -10)
        XCTAssertTrue(c.isAfterExam)
        XCTAssertEqual(c.progress, 1.0)             // 环满
        XCTAssertGreaterThan(c.rawProgress, 1.0)    // 但原始值 > 1，用于切考后态
    }

    /// 非法态（旧数据 / 同步冲突）不得 crash。
    func testDegenerateRangeDoesNotCrash() {
        let c = engine.countdown(
            startDate: cal.day(2027, 6, 7),
            targetDate: cal.day(2027, 6, 7),
            today: cal.day(2026, 12, 2)
        )
        XCTAssertEqual(c.totalDays, 0)
        XCTAssertEqual(c.progress, 0)
    }

    // MARK: - 补签窗口（D-04）

    func testBackfillWindow() {
        let today = cal.day(2026, 12, 2)
        XCTAssertTrue(engine.canBackfill(date: cal.day(2026, 12, 1), today: today))
        XCTAssertTrue(engine.canBackfill(date: cal.day(2026, 11, 18), today: today))  // 恰好 14 天
        XCTAssertFalse(engine.canBackfill(date: cal.day(2026, 11, 17), today: today)) // 第 15 天，超窗
        XCTAssertFalse(engine.canBackfill(date: today, today: today))                 // 今天走正常打卡
        XCTAssertFalse(engine.canBackfill(date: cal.day(2026, 12, 3), today: today))  // 未来不可补
    }

    func testEarliestBackfillDate() {
        XCTAssertEqual(
            engine.earliestBackfillDate(today: cal.day(2026, 12, 2)),
            cal.day(2026, 11, 18)
        )
    }

    // MARK: - 信件（5.6）

    func testLetterOpenDates() {
        let target = cal.day(2027, 6, 7)
        XCTAssertEqual(engine.letterOpenDate(trigger: .d100, targetDate: target), cal.day(2027, 2, 27))
        XCTAssertEqual(engine.letterOpenDate(trigger: .d50, targetDate: target), cal.day(2027, 4, 18))
        XCTAssertEqual(engine.letterOpenDate(trigger: .nightBefore, targetDate: target), cal.day(2027, 6, 6))
    }

    /// 「出分日」依赖考后日程表；无日程数据时必须返回 nil，写信页不得展示这个选项。
    func testResultDayRequiresScheduleData() {
        let target = cal.day(2027, 6, 7)
        XCTAssertNil(engine.letterOpenDate(trigger: .resultDay, targetDate: target))
        XCTAssertFalse(engine.isTriggerSelectable(.resultDay, targetDate: target, today: cal.day(2026, 12, 2)))
        XCTAssertTrue(engine.isTriggerSelectable(
            .resultDay, targetDate: target, today: cal.day(2026, 12, 2), resultDay: cal.day(2027, 6, 23)
        ))
    }

    func testExpiredTriggerIsNotSelectable() {
        let target = cal.day(2027, 6, 7)
        // 还剩 100 天那天是 2027-02-27，今天已是 2027-03-01 → 该节点不可选
        XCTAssertFalse(engine.isTriggerSelectable(.d100, targetDate: target, today: cal.day(2027, 3, 1)))
        XCTAssertTrue(engine.isTriggerSelectable(.d50, targetDate: target, today: cal.day(2027, 3, 1)))
    }
}
