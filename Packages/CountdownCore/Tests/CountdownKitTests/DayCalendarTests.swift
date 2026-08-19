import XCTest
@testable import CountdownKit

/// 日历天差是全产品的地基。这里错 1 天，用户看到的「已走过」就会倒退。
final class DayCalendarTests: XCTestCase {

    let cal = DayCalendar.fixed()

    func testDayDiffIsCalendarDaysNotSeconds() {
        XCTAssertEqual(cal.days(from: cal.day(2026, 12, 1), to: cal.day(2026, 12, 2)), 1)
        XCTAssertEqual(cal.days(from: cal.day(2026, 12, 2), to: cal.day(2026, 12, 1)), -1)
        XCTAssertEqual(cal.days(from: cal.day(2026, 12, 1), to: cal.day(2026, 12, 1)), 0)
    }

    func testDayDiffIgnoresTimeOfDay() {
        let morning = cal.calendar.date(byAdding: .hour, value: 1, to: cal.day(2026, 12, 1))!
        let lateNight = cal.calendar.date(byAdding: .hour, value: 23, to: cal.day(2026, 12, 2))!
        // 23:00 与次日 01:00 相差 2 小时，但**日历天差是 1 天**。
        XCTAssertEqual(cal.days(from: morning, to: lateNight), 1)
    }

    /// 夏令时。用 86400 秒除法在这里会得到 1.958 天 → 截断成 1，错一天。
    func testDayDiffAcrossDaylightSavingTransition() {
        let ny = DayCalendar.fixed(timeZoneIdentifier: "America/New_York")
        // 2026-03-08 美东进入夏令时，当天只有 23 小时。
        XCTAssertEqual(ny.days(from: ny.day(2026, 3, 7), to: ny.day(2026, 3, 9)), 2)
        // 2026-11-01 退出夏令时，当天有 25 小时。
        XCTAssertEqual(ny.days(from: ny.day(2026, 10, 31), to: ny.day(2026, 11, 2)), 2)
    }

    func testAddingDaysAcrossDaylightSavingLandsOnMidnight() {
        let ny = DayCalendar.fixed(timeZoneIdentifier: "America/New_York")
        let next = ny.adding(days: 1, to: ny.day(2026, 3, 7))
        XCTAssertEqual(next, ny.day(2026, 3, 8))
        XCTAssertEqual(ny.dayOfMonth(of: next), 8)
    }

    func testLeapYear() {
        XCTAssertEqual(cal.days(from: cal.day(2024, 2, 28), to: cal.day(2024, 3, 1)), 2) // 含 2/29
        XCTAssertEqual(cal.days(from: cal.day(2025, 2, 28), to: cal.day(2025, 3, 1)), 1)
        XCTAssertEqual(cal.daysInMonth(cal.day(2024, 2, 1)), 29)
        XCTAssertEqual(cal.daysInMonth(cal.day(2100, 2, 1)), 28) // 百年不闰
    }

    /// 引导第 2 屏：日切换时按月自动收敛（31 日 → 2 月变 28 日）。
    func testMonthEndClamping() {
        XCTAssertEqual(cal.dayOfMonth(of: cal.day(2025, 2, 31)), 28)
        XCTAssertEqual(cal.dayOfMonth(of: cal.day(2024, 2, 31)), 29)
        XCTAssertEqual(cal.dayOfMonth(of: cal.day(2026, 4, 31)), 30)
        XCTAssertEqual(cal.dayOfMonth(of: cal.day(2026, 4, 0)), 1)
    }

    func testCrossYear() {
        XCTAssertEqual(cal.days(from: cal.day(2026, 12, 31), to: cal.day(2027, 1, 1)), 1)
        XCTAssertEqual(cal.days(from: cal.day(2026, 1, 1), to: cal.day(2027, 1, 1)), 365)
        XCTAssertEqual(cal.days(from: cal.day(2024, 1, 1), to: cal.day(2025, 1, 1)), 366)
    }

    func testLastWeekday() {
        // 2026-12-26 是当月最后一个周六
        XCTAssertEqual(cal.lastWeekday(7, inYear: 2026, month: 12), cal.day(2026, 12, 26))
        // 2026-11-29 是当月最后一个周日
        XCTAssertEqual(cal.lastWeekday(1, inYear: 2026, month: 11), cal.day(2026, 11, 29))
    }

    func testNthFromLastWeekday() {
        XCTAssertEqual(cal.nthFromLastWeekday(7, n: 1, inYear: 2026, month: 12), cal.day(2026, 12, 26))
        XCTAssertEqual(cal.nthFromLastWeekday(7, n: 3, inYear: 2026, month: 12), cal.day(2026, 12, 12))
        XCTAssertEqual(cal.nthFromLastWeekday(7, n: 3, inYear: 2025, month: 12), cal.day(2025, 12, 13))
    }
}
