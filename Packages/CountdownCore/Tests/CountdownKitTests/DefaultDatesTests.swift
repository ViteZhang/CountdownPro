import XCTest
@testable import CountdownKit

final class DefaultDatesTests: XCTestCase {

    let cal = DayCalendar.fixed()
    lazy var d = DefaultDates(cal: cal)

    // MARK: - 默认目标日期：当年优先，已过期顺延次年（已确认以原型逻辑为准）

    func testGaokaoPrefersCurrentYear() {
        // 3 月安装的高三生，应当直接看到**今年** 6 月 7 日
        XCTAssertEqual(d.targetDate(for: .gaokao, today: cal.day(2026, 3, 1)), cal.day(2026, 6, 7))
        XCTAssertEqual(d.targetDate(for: .gaokao, today: cal.day(2026, 1, 1)), cal.day(2026, 6, 7))
        XCTAssertEqual(d.targetDate(for: .gaokao, today: cal.day(2026, 6, 6)), cal.day(2026, 6, 7))
    }

    /// 默认值恰好等于今天时**顺延次年**。
    /// 原型 defTarget 用 `<`、校验 paintTarget 用 `<=`，两者在这一天会打架
    /// （默认值保留，但「继续」同时被置灰）。这里统一到校验规则一侧。
    func testGaokaoRollsForwardWhenDefaultEqualsToday() {
        XCTAssertEqual(d.targetDate(for: .gaokao, today: cal.day(2026, 6, 7)), cal.day(2027, 6, 7))
        XCTAssertNil(d.validateTarget(cal.day(2027, 6, 7), today: cal.day(2026, 6, 7)))
    }

    func testGaokaoRollsForwardAfterExam() {
        XCTAssertEqual(d.targetDate(for: .gaokao, today: cal.day(2026, 6, 8)), cal.day(2027, 6, 7))
        XCTAssertEqual(d.targetDate(for: .gaokao, today: cal.day(2026, 12, 2)), cal.day(2027, 6, 7))
    }

    func testZhongkaoDefault() {
        XCTAssertEqual(d.targetDate(for: .zhongkao, today: cal.day(2026, 3, 1)), cal.day(2026, 6, 15))
        XCTAssertEqual(d.targetDate(for: .zhongkao, today: cal.day(2026, 7, 1)), cal.day(2027, 6, 15))
    }

    /// 考研：12 月倒数第 3 个周六
    func testKaoyanDefault() {
        let t = d.targetDate(for: .kaoyan, today: cal.day(2026, 3, 1))
        XCTAssertEqual(t, cal.day(2026, 12, 12))
        XCTAssertEqual(cal.weekday(of: t!), 7) // 周六
        XCTAssertEqual(d.targetDate(for: .kaoyan, today: cal.day(2026, 12, 20)), cal.day(2027, 12, 11))
    }

    /// 考公（国考）：11 月最后一个周日
    func testKaogongDefault() {
        let t = d.targetDate(for: .kaogong, today: cal.day(2026, 3, 1))
        XCTAssertEqual(t, cal.day(2026, 11, 29))
        XCTAssertEqual(cal.weekday(of: t!), 1) // 周日
        XCTAssertEqual(d.targetDate(for: .kaogong, today: cal.day(2026, 12, 1)), cal.day(2027, 11, 28))
    }

    /// 需求文档 5.1 表格：自定义**无**默认目标日期。
    func testCustomHasNoDefaultTarget() {
        XCTAssertNil(d.targetDate(for: .custom, today: cal.day(2026, 3, 1)))
    }

    /// 顺延后的默认值必须自己能过校验 —— 否则用户一进第 2 屏就看到报错。
    func testEveryDefaultTargetPassesValidation() {
        for type in ExamType.allCases where type != .custom {
            for today in [cal.day(2026, 1, 1), cal.day(2026, 6, 7), cal.day(2026, 11, 29), cal.day(2026, 12, 12)] {
                let t = d.targetDate(for: type, today: today)
                XCTAssertNotNil(t, "\(type)")
                XCTAssertNil(d.validateTarget(t!, today: today), "\(type) @ \(today)")
            }
        }
    }

    // MARK: - 默认起始日期

    func testGaokaoStartIsThreeYearsBackSeptFirst() {
        XCTAssertEqual(
            d.startDate(for: .gaokao, targetDate: cal.day(2027, 6, 7), today: cal.day(2026, 12, 2)),
            cal.day(2024, 9, 1)
        )
    }

    func testKaoyanStartIsMarchFirstOfTargetYear() {
        XCTAssertEqual(
            d.startDate(for: .kaoyan, targetDate: cal.day(2026, 12, 12), today: cal.day(2026, 6, 1)),
            cal.day(2026, 3, 1)
        )
    }

    /// 5.1 边界：默认起始日期晚于今天则**回落为今天**。
    func testStartFallsBackToTodayWhenInFuture() {
        // 2026-01-10 安装考研 → 目标 2026-12-12，默认起始 2026-03-01 晚于今天
        XCTAssertEqual(
            d.startDate(for: .kaoyan, targetDate: cal.day(2026, 12, 12), today: cal.day(2026, 1, 10)),
            cal.day(2026, 1, 10)
        )
    }

    func testDefaultStartIsAlwaysBeforeDefaultTarget() {
        for type in ExamType.allCases where type != .custom {
            for today in [cal.day(2026, 1, 1), cal.day(2026, 5, 20), cal.day(2026, 12, 31)] {
                let target = d.targetDate(for: type, today: today)!
                let start = d.startDate(for: type, targetDate: target, today: today)
                XCTAssertNil(d.validateStart(start, target: target, today: today), "\(type) @ \(today)")
            }
        }
    }

    // MARK: - 快捷选项

    func testGaokaoQuickStarts() {
        let q = d.quickStarts(for: .gaokao, targetDate: cal.day(2027, 6, 7), today: cal.day(2026, 12, 2))
        XCTAssertEqual(q.map(\.title), ["高一开学", "高三开学", "今天"])
        XCTAssertEqual(q[0].date, cal.day(2024, 9, 1))
        XCTAssertEqual(q[1].date, cal.day(2026, 9, 1))
        XCTAssertEqual(q[2].date, cal.day(2026, 12, 2))
    }

    func testZhongkaoQuickStartTitles() {
        let q = d.quickStarts(for: .zhongkao, targetDate: cal.day(2027, 6, 15), today: cal.day(2026, 12, 2))
        XCTAssertEqual(q.map(\.title), ["初一开学", "初三开学", "今天"])
    }

    func testOtherQuickStartTitles() {
        for type in [ExamType.kaoyan, .kaogong, .custom] {
            let q = d.quickStarts(for: type, targetDate: cal.day(2027, 3, 15), today: cal.day(2026, 12, 2))
            XCTAssertEqual(q.map(\.title), ["决定要考的那天", "今天"])
        }
    }

    // MARK: - 校验

    func testValidateTarget() {
        let today = cal.day(2026, 12, 2)
        XCTAssertEqual(d.validateTarget(cal.day(2026, 6, 7), today: today), .inPast(suggestedYear: 2027))
        XCTAssertEqual(d.validateTarget(today, today: today), .inPast(suggestedYear: 2027))
        XCTAssertNil(d.validateTarget(cal.day(2026, 12, 3), today: today))
    }

    func testValidateStart() {
        let today = cal.day(2026, 12, 2)
        let target = cal.day(2027, 6, 7)
        XCTAssertEqual(d.validateStart(target, target: target, today: today), .notBeforeTarget)
        XCTAssertEqual(d.validateStart(cal.day(2027, 8, 1), target: target, today: today), .notBeforeTarget)
        XCTAssertEqual(d.validateStart(cal.day(2027, 1, 1), target: target, today: today), .inFuture)
        XCTAssertNil(d.validateStart(cal.day(2024, 9, 1), target: target, today: today))
    }

    func testRollTargetToNextYearKeepsMonthAndDay() {
        XCTAssertEqual(d.rollTargetToNextYear(cal.day(2026, 6, 7)), cal.day(2027, 6, 7))
        // 2/29 → 次年无该日，收敛到 2/28
        XCTAssertEqual(d.rollTargetToNextYear(cal.day(2024, 2, 29)), cal.day(2025, 2, 28))
    }
}
