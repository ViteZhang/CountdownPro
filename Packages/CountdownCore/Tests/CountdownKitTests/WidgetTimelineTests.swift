import XCTest
@testable import CountdownKit

/// 需求文档 5.10：小组件是本产品最重要的触达通道。
/// 验收标准：飞行模式下所有小组件正常显示；跨零点后 5 分钟内天数更新。
final class WidgetTimelineTests: XCTestCase {

    let cal = DayCalendar.fixed()

    private func snapshot(census: Int? = nil) -> WidgetSnapshot {
        WidgetSnapshot(
            examTitle: "高考",
            startDate: cal.day(2025, 3, 22),
            targetDate: cal.day(2027, 6, 7),
            censusCount: census
        )
    }

    func testGeneratesSevenEntries() {
        let entries = WidgetTimelineBuilder.entries(
            snapshot: snapshot(), from: cal.day(2026, 12, 2), cal: cal
        )
        XCTAssertEqual(entries.count, 7)
    }

    /// 每条 entry 落在各自那天的 00:00 —— 跨零点即刻切换，不靠后台刷新。
    func testEntriesLandOnConsecutiveMidnights() {
        let entries = WidgetTimelineBuilder.entries(
            snapshot: snapshot(), from: cal.day(2026, 12, 2), cal: cal
        )
        for (offset, entry) in entries.enumerated() {
            XCTAssertEqual(entry.date, cal.day(2026, 12, 2 + offset))
            XCTAssertEqual(entry.date, cal.startOfDay(entry.date))
        }
    }

    /// 天数逐日递减 —— 这是"预生成 7 天"能成立的全部依据。
    func testDaysRemainingDecrementsByOne() {
        let entries = WidgetTimelineBuilder.entries(
            snapshot: snapshot(), from: cal.day(2026, 12, 2), cal: cal
        )
        XCTAssertEqual(entries.map(\.countdown.daysRemaining), [187, 186, 185, 184, 183, 182, 181])
        XCTAssertEqual(entries.map(\.countdown.daysPassed), [620, 621, 622, 623, 624, 625, 626])
    }

    /// D-01：小组件上「已走过」同样必须在场，且填充比例就是它。
    func testProgressIsPassedRatioOnEveryEntry() {
        let entries = WidgetTimelineBuilder.entries(
            snapshot: snapshot(), from: cal.day(2026, 12, 2), cal: cal
        )
        for entry in entries {
            let c = entry.countdown
            XCTAssertEqual(c.progress, Double(c.daysPassed) / Double(c.totalDays), accuracy: 1e-9)
        }
    }

    /// 跨月、跨年不出错。
    func testTimelineCrossesYearBoundary() {
        let entries = WidgetTimelineBuilder.entries(
            snapshot: snapshot(), from: cal.day(2026, 12, 29), cal: cal
        )
        XCTAssertEqual(entries.last?.date, cal.day(2027, 1, 4))
        XCTAssertEqual(entries.map(\.countdown.daysRemaining).last, 154)
    }

    // MARK: - 同考人数的诚实性（D-09）

    /// 缓存里的数字是**今天**的人数。铺到未来 6 天就成了「用旧数字冒充今日人数」。
    func testCensusAppearsOnlyOnTodaysEntry() {
        let entries = WidgetTimelineBuilder.entries(
            snapshot: snapshot(census: 412_000), from: cal.day(2026, 12, 2), cal: cal
        )
        XCTAssertEqual(entries[0].censusDisplay, "41.2")
        for entry in entries.dropFirst() {
            XCTAssertNil(entry.censusDisplay, "未来的 entry 不得展示今天的人数")
        }
    }

    /// 无缓存（飞行模式 / 从没拉到过）→ 每一条都隐藏该模块，其余内容照常。
    func testNoCensusCacheHidesTheBlockEverywhere() {
        let entries = WidgetTimelineBuilder.entries(
            snapshot: snapshot(census: nil), from: cal.day(2026, 12, 2), cal: cal
        )
        XCTAssertTrue(entries.allSatisfy { $0.censusDisplay == nil })
        // 但倒计时本身完全正常 —— 这就是"仅同考人数模块降级"
        XCTAssertEqual(entries[0].countdown.daysRemaining, 187)
        XCTAssertEqual(entries[0].examTitle, "高考")
    }

    /// 低于 1 万整块隐藏，与"拉不到"表现完全一致。
    func testBelowThresholdHiddenSameAsMissing() {
        let low = WidgetTimelineBuilder.entries(
            snapshot: snapshot(census: 9_999), from: cal.day(2026, 12, 2), cal: cal
        )
        let none = WidgetTimelineBuilder.entries(
            snapshot: snapshot(census: nil), from: cal.day(2026, 12, 2), cal: cal
        )
        XCTAssertEqual(low.map(\.censusDisplay), none.map(\.censusDisplay))
    }

    // MARK: - 考试日与考后

    func testExamDayAndAfterWithinOneTimeline() {
        let s = WidgetSnapshot(
            examTitle: "高考",
            startDate: cal.day(2026, 1, 1),
            targetDate: cal.day(2026, 12, 4),
            censusCount: nil
        )
        let entries = WidgetTimelineBuilder.entries(snapshot: s, from: cal.day(2026, 12, 2), cal: cal)
        XCTAssertEqual(entries[2].countdown.daysRemaining, 0)
        XCTAssertTrue(entries[2].countdown.isExamDay)
        XCTAssertEqual(entries[2].countdown.growthStage, .blooming)
        XCTAssertTrue(entries[3].countdown.isAfterExam)
        // 考后环仍是满的，不回退
        XCTAssertEqual(entries[3].countdown.progress, 1.0)
    }

    func testReloadDateIsLastEntryDay() {
        XCTAssertEqual(
            WidgetTimelineBuilder.reloadDate(from: cal.day(2026, 12, 2), cal: cal),
            cal.day(2026, 12, 8)
        )
    }
}
