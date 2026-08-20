import XCTest
@testable import CountdownKit

/// 需求文档 5.6 验收标准：封存中的信件内容在任何界面、任何调试路径下均不可见。
final class LetterVaultTests: XCTestCase {

    /// 测试替身：把 UTF-8 字节反转当作"加密"。
    /// 这里验的不是密码学强度，而是**时间闸门** —— 那才是产品语义所在。
    struct ReversingCipher: LetterCipher {
        func seal(_ plaintext: String) throws -> Data { Data(Array(Data(plaintext.utf8)).reversed()) }
        func reveal(_ ciphertext: Data) throws -> String {
            String(decoding: Data(Array(ciphertext).reversed()), as: UTF8.self)
        }
    }

    let cal = DayCalendar.fixed()
    lazy var vault = LetterVault(cipher: ReversingCipher(), cal: cal)

    let body = "如果你正在读这封信，说明你撑过了一百天。"

    func testCannotRevealBeforeOpenDate() throws {
        let sealed = try vault.seal(body)
        XCTAssertThrowsError(
            try vault.reveal(sealed: sealed, access: .sealed(openAt: cal.day(2027, 6, 6)), today: cal.day(2026, 12, 2))
        ) { error in
            XCTAssertEqual(error as? LetterVaultError, .notYetOpenable(daysRemaining: 186))
        }
    }

    /// 差一天也不行。
    func testCannotRevealOneDayEarly() throws {
        let sealed = try vault.seal(body)
        XCTAssertThrowsError(
            try vault.reveal(sealed: sealed, access: .sealed(openAt: cal.day(2027, 6, 6)), today: cal.day(2027, 6, 5))
        )
    }

    func testCanRevealOnOpenDate() throws {
        let sealed = try vault.seal(body)
        let revealed = try vault.reveal(sealed: sealed, access: .sealed(openAt: cal.day(2027, 6, 6)), today: cal.day(2027, 6, 6))
        XCTAssertEqual(revealed, body)
    }

    /// 开启日已过但用户没打开 App → 下次打开时仍可开启（5.6 边界情况）。
    func testCanRevealAfterOpenDatePassed() throws {
        let sealed = try vault.seal(body)
        let revealed = try vault.reveal(sealed: sealed, access: .sealed(openAt: cal.day(2027, 6, 6)), today: cal.day(2027, 7, 1))
        XCTAssertEqual(revealed, body)
    }

    /// 密文里不得出现明文。
    func testSealedBytesDoNotContainPlaintext() throws {
        let sealed = try vault.seal(body)
        XCTAssertFalse(sealed.range(of: Data(body.utf8)) != nil)
    }

    /// 草稿可查看、可修改（信件文案表第 0 节）——
    /// 1000 字写到一半误触返回就全丢，对这个功能不可接受。
    func testDraftIsReadableWithoutDateGate() throws {
        let sealed = try vault.seal(body)
        XCTAssertEqual(try vault.reveal(sealed: sealed, access: .draft, today: cal.day(2026, 12, 2)), body)
    }

    /// 但草稿一旦封存，就回到日期闸门之下 —— 封存不可逆。
    func testSealedAccessAlwaysCarriesTheDateGate() throws {
        let sealed = try vault.seal(body)
        XCTAssertThrowsError(
            try vault.reveal(sealed: sealed,
                             access: .sealed(openAt: cal.day(2027, 6, 6)),
                             today: cal.day(2026, 12, 2))
        )
    }

    /// 列表态查询**不碰密文**，所以不存在"查询顺手解密"的旁路。
    func testListingQueriesDoNotNeedCiphertext() {
        let openAt = cal.day(2027, 6, 6)
        XCTAssertFalse(vault.isOpenable(openAt: openAt, today: cal.day(2026, 12, 2)))
        XCTAssertTrue(vault.isOpenable(openAt: openAt, today: cal.day(2027, 6, 6)))
        XCTAssertEqual(vault.daysUntilOpen(openAt: openAt, today: cal.day(2027, 6, 1)), 5)
        XCTAssertEqual(vault.daysUntilOpen(openAt: openAt, today: cal.day(2027, 7, 1)), 0)
    }

    func testRejectsOverLengthContent() {
        let tooLong = String(repeating: "字", count: Strings.Letters.maxLength + 1)
        XCTAssertThrowsError(try vault.seal(tooLong)) { error in
            XCTAssertEqual(error as? LetterVaultError, .contentTooLong(limit: 1000))
        }
        XCTAssertNoThrow(try vault.seal(String(repeating: "字", count: Strings.Letters.maxLength)))
    }
}
