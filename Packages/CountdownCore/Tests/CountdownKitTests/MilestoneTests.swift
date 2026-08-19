import XCTest
@testable import CountdownKit

final class MilestoneTests: XCTestCase {

    /// 5.8.1 卡片节点含 99（进入两位数），5.11 通知节点不含 —— 99 只递卡不打扰。
    func testCardAndNotificationTriggersDiffer() {
        XCTAssertTrue(Milestone(daysRemaining: 99).triggersCard)
        XCTAssertFalse(Milestone(daysRemaining: 99).triggersNotification)

        for d in [100, 50, 30, 10, 1] {
            XCTAssertTrue(Milestone(daysRemaining: d).triggersCard, "d=\(d)")
            XCTAssertTrue(Milestone(daysRemaining: d).triggersNotification, "d=\(d)")
        }
    }

    func testNonMilestoneDays() {
        for d in [98, 51, 49, 31, 11, 2, 0, -1] {
            XCTAssertFalse(Milestone(daysRemaining: d).triggersCard, "d=\(d)")
        }
    }

    /// 每个节点一生只触发一次（5.8.2），靠这个 key 去重。
    func testFlagKeysAreUnique() {
        let keys = Milestone.cardTriggers.map { Milestone(daysRemaining: $0).flagKey }
        XCTAssertEqual(Set(keys).count, keys.count)
    }
}
