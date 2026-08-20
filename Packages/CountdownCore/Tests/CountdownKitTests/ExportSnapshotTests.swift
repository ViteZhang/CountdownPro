import XCTest
@testable import CountdownKit

/// 需求文档 5.13：**即使有账号，用户也应能把自己的记录带走。**
final class ExportSnapshotTests: XCTestCase {

    let cal = DayCalendar.fixed()

    private func sample() -> ExportSnapshot {
        ExportSnapshot(
            exportedAt: cal.day(2026, 12, 2),
            exams: [.init(id: "E1", type: .gaokao, title: "高考",
                          startDate: cal.day(2024, 9, 1), targetDate: cal.day(2027, 6, 7),
                          province: nil, isPrimary: true,
                          createdAt: cal.day(2024, 9, 1), updatedAt: cal.day(2024, 9, 1))],
            checkIns: [.init(date: cal.day(2026, 12, 1), examID: "E1",
                             isBackfill: false, createdAt: cal.day(2026, 12, 1))],
            notes: [.init(id: "N1", date: cal.day(2026, 12, 1), content: "今天很累，什么都没学进去。但还是来打个卡。",
                          createdAt: cal.day(2026, 12, 1), updatedAt: cal.day(2026, 12, 1))],
            letters: [.init(id: "L1", writtenAt: cal.day(2026, 8, 24), openAt: cal.day(2027, 6, 6),
                            openTrigger: .nightBefore, isOpened: false, openedAt: nil,
                            isDraft: false, updatedAt: cal.day(2026, 8, 24),
                            content: nil, sealedContentBase64: "c2VhbGVk")]
        )
    }

    func testRoundTrip() throws {
        let original = sample()
        let data = try ExportSnapshot.jsonEncoder().encode(original)
        let decoded = try ExportSnapshot.jsonDecoder().decode(ExportSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testSchemaVersionIsPresent() throws {
        let data = try ExportSnapshot.jsonEncoder().encode(sample())
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"schemaVersion\" : 1"))
    }

    /// 导出的是**事实**，不是结论。累计天数 / 进度 / 成长阶段都不进导出文件。
    func testExportContainsNoDerivedValues() throws {
        let data = try ExportSnapshot.jsonEncoder().encode(sample())
        let json = String(decoding: data, as: UTF8.self)
        for derived in ["daysPassed", "daysRemaining", "progress", "growthStage", "totalCheckIns", "streak"] {
            XCTAssertFalse(json.contains(derived), "导出不得含可推导值：\(derived)")
        }
    }

    /// 未开启的信在导出文件里也只有密文（D-08）。
    /// 导出文件是最容易被忽略的偷看旁路：把 JSON 发到电脑上打开就能读。
    func testSealedLetterExportsCiphertextOnly() throws {
        let plaintext = "如果你正在读这封信，说明你撑过了一百天。"
        var snapshot = sample()
        snapshot.letters[0].sealedContentBase64 = Data(plaintext.utf8).base64EncodedString()

        let data = try ExportSnapshot.jsonEncoder().encode(snapshot)
        let json = String(decoding: data, as: UTF8.self)

        // 明文正文不得出现在导出文件里的任何位置
        XCTAssertFalse(json.contains(plaintext))

        let decoded = try ExportSnapshot.jsonDecoder().decode(ExportSnapshot.self, from: data)
        let letter = try XCTUnwrap(decoded.letters.first)
        XCTAssertFalse(letter.isOpened)
        XCTAssertNil(letter.content)
        XCTAssertNotNil(letter.sealedContentBase64)
    }
}
