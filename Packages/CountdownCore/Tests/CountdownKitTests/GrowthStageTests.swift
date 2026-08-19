import XCTest
@testable import CountdownKit

final class GrowthStageTests: XCTestCase {

    /// 5.4 表格未定义边界值归属，实现约定为**左闭右开**。这组断言把约定钉死。
    func testStageBoundariesAreLeftClosedRightOpen() {
        let cases: [(Double, GrowthStage)] = [
            (0.00, .seed), (0.149, .seed),
            (0.15, .sprout), (0.299, .sprout),
            (0.30, .branching), (0.499, .branching),
            (0.50, .leafing), (0.699, .leafing),
            (0.70, .lush), (0.899, .lush),
            (0.90, .budding), (0.999, .budding),
        ]
        for (p, expected) in cases {
            XCTAssertEqual(GrowthStage.stage(progress: p, isExamDay: false), expected, "progress=\(p)")
        }
    }

    /// 5.4：`= 100%（考试当天）` 才开花。走满但还没到考试日不算。
    func testBloomingOnlyAtHundredPercent() {
        XCTAssertEqual(GrowthStage.stage(progress: 1.0, isExamDay: false), .blooming)
        XCTAssertEqual(GrowthStage.stage(progress: 0.5, isExamDay: true), .blooming)
        XCTAssertEqual(GrowthStage.stage(progress: 0.999, isExamDay: false), .budding)
    }

    /// 设计决策 D-05：树只与时间有关，与表现无关。
    /// 验收标准（5.4）：连续 30 天不打卡，树的阶段仍随日期正常推进。
    func testStageAdvancesWithoutAnyCheckIns() {
        let cal = DayCalendar.fixed()
        let engine = CountdownEngine(cal: cal)
        let start = cal.day(2026, 1, 1)
        let target = cal.day(2026, 4, 11) // 总 100 天

        let day40 = engine.countdown(startDate: start, targetDate: target, today: cal.day(2026, 2, 10))
        let day70 = engine.countdown(startDate: start, targetDate: target, today: cal.day(2026, 3, 12))

        XCTAssertEqual(day40.growthStage, .branching)
        XCTAssertEqual(day70.growthStage, .lush)
        // 期间零打卡 —— countdown 的签名里根本没有打卡数这个入参，这就是防线。
    }

    func testDisplayNamesHaveNoStageIndex() {
        XCTAssertEqual(GrowthStage.branching.displayName, "抽枝")
        XCTAssertEqual(GrowthStage.lush.displayName, "繁茂")
        for stage in GrowthStage.allCases {
            XCTAssertFalse(stage.displayName.contains("第"), "副文案不带序号：\(stage)")
            XCTAssertFalse(stage.displayName.contains("阶段"), "副文案不带序号：\(stage)")
        }
    }
}
