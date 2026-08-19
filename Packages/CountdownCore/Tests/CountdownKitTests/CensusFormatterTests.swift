import XCTest
@testable import CountdownKit

/// 需求文档 5.7 / 设计决策 D-09：这个产品除了信任没有别的护城河。
final class CensusFormatterTests: XCTestCase {

    func testHiddenBelowThreshold() {
        XCTAssertNil(CensusFormatter.display(count: 0))
        XCTAssertNil(CensusFormatter.display(count: 9_999))
        XCTAssertNil(CensusFormatter.display(count: 500))
    }

    func testShownAtOrAboveThreshold() {
        XCTAssertEqual(CensusFormatter.display(count: 10_000), "1.0")
        XCTAssertEqual(CensusFormatter.display(count: 412_000), "41.2")
        XCTAssertEqual(CensusFormatter.display(count: 1_234_567), "123.5")
    }

    /// 无网络 / 拉取失败与「不足 1 万」走**同一个返回值**，
    /// 让调用方无法区分，也就无从为「失败」单独做错误态或骨架屏。
    func testNilCountIsIndistinguishableFromBelowThreshold() {
        XCTAssertNil(CensusFormatter.display(count: nil))
        XCTAssertEqual(CensusFormatter.display(count: nil), CensusFormatter.display(count: 9_999))
    }
}
