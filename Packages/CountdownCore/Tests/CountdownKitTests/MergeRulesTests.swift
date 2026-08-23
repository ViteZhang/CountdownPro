import XCTest
@testable import CountdownKit

/// 需求文档 5.14.4。合并逻辑出错会让用户的累计天数变少 —— 那是这个产品最不能出的错。
final class MergeRulesTests: XCTestCase {

    let cal = DayCalendar.fixed()

    private func checkIn(_ y: Int, _ m: Int, _ d: Int, backfill: Bool = false, created: Date? = nil)
        -> ExportSnapshot.CheckInDTO {
        let date = cal.day(y, m, d)
        return .init(date: date, examID: "E1", isBackfill: backfill, createdAt: created ?? date)
    }

    /// 打卡取并集 —— 不同设备的打卡都算数。
    func testCheckInsAreUnioned() {
        let local = [checkIn(2026, 12, 1), checkIn(2026, 12, 2)]
        let remote = [checkIn(2026, 12, 2), checkIn(2026, 12, 3)]
        let merged = MergeRules.mergeCheckIns(local: local, remote: remote)
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged.map { cal.dayOfMonth(of: $0.date) }, [1, 2, 3])
    }

    /// D-03「累计只增不减」在同步层的兑现：合并结果永远 ≥ 任一端。
    func testMergeNeverShrinksTotal() {
        let local = (1...20).map { checkIn(2026, 12, $0) }
        let remote = (10...31).map { checkIn(2026, 12, $0) }
        let merged = MergeRules.mergeCheckIns(local: local, remote: remote)
        XCTAssertGreaterThanOrEqual(merged.count, local.count)
        XCTAssertGreaterThanOrEqual(merged.count, remote.count)
        XCTAssertEqual(merged.count, 31)
    }

    /// 同一天一端补签、一端正常打卡 → 不算补签，且保留更早的操作时间。
    func testCheckInConflictPrefersRealCheckInAndEarliestCreation() {
        let early = cal.day(2026, 12, 1)
        let late = cal.day(2026, 12, 5)
        let local = [checkIn(2026, 12, 1, backfill: true, created: late)]
        let remote = [checkIn(2026, 12, 1, backfill: false, created: early)]
        let merged = MergeRules.mergeCheckIns(local: local, remote: remote)
        XCTAssertEqual(merged.count, 1)
        XCTAssertFalse(merged[0].isBackfill)
        XCTAssertEqual(merged[0].createdAt, early)
    }

    /// 冲突以最后写入时间较晚者为准。
    func testNoteConflictPrefersLatestUpdate() {
        let base = cal.day(2026, 12, 1)
        let older = ExportSnapshot.NoteDTO(id: "N1", date: base, content: "旧", createdAt: base, updatedAt: base)
        let newer = ExportSnapshot.NoteDTO(
            id: "N1", date: base, content: "新", createdAt: base, updatedAt: cal.day(2026, 12, 9)
        )
        XCTAssertEqual(MergeRules.mergeNotes(local: [older], remote: [newer]).first?.content, "新")
        XCTAssertEqual(MergeRules.mergeNotes(local: [newer], remote: [older]).first?.content, "新")
    }

    private func exam(_ id: String, primary: Bool, updated: Date) -> ExportSnapshot.ExamDTO {
        .init(id: id, type: .gaokao, title: "高考",
              startDate: cal.day(2024, 9, 1), targetDate: cal.day(2027, 6, 7),
              province: nil, isPrimary: primary, createdAt: cal.day(2026, 1, 1), updatedAt: updated)
    }

    /// 两端各自设了不同的主考试 → 合并后必须**恰好一个** isPrimary，否则首页不知道展示哪个。
    func testExactlyOnePrimaryExamAfterMerge() {
        let local = [exam("A", primary: true, updated: cal.day(2026, 12, 1)),
                     exam("B", primary: false, updated: cal.day(2026, 12, 1))]
        let remote = [exam("A", primary: false, updated: cal.day(2026, 12, 2)),
                      exam("B", primary: true, updated: cal.day(2026, 12, 5))]
        let merged = MergeRules.mergeExams(local: local, remote: remote)
        XCTAssertEqual(merged.filter(\.isPrimary).count, 1)
        XCTAssertEqual(merged.first(where: \.isPrimary)?.id, "B")
    }

    func testMergeExamsWithNoPrimaryStillProducesOne() {
        let merged = MergeRules.mergeExams(
            local: [exam("A", primary: false, updated: cal.day(2026, 12, 1))],
            remote: []
        )
        XCTAssertEqual(merged.filter(\.isPrimary).count, 1)
    }

    private func letter(_ id: String, opened: Bool, openedAt: Date? = nil, content: String? = nil,
                        draft: Bool = false, updated: Date? = nil) -> ExportSnapshot.LetterDTO {
        .init(id: id, writtenAt: cal.day(2026, 8, 24), openAt: cal.day(2026, 12, 2),
              openTrigger: .d100, isOpened: opened, openedAt: openedAt,
              isDraft: draft, updatedAt: updated ?? cal.day(2026, 8, 24),
              content: content, sealedContentBase64: opened ? nil : "c2VhbGVk")
    }

    // MARK: - 草稿与封存的合并（信件文案表第 0 节）

    /// 两端都是草稿 → 后写入者胜，和心里话一样。
    func testDraftConflictPrefersLatestUpdate() {
        let older = letter("L1", opened: false, content: nil, draft: true, updated: cal.day(2026, 12, 1))
        var newer = older
        newer.updatedAt = cal.day(2026, 12, 5)
        newer.sealedContentBase64 = "bmV3ZXI="
        XCTAssertEqual(MergeRules.mergeLetters(local: [older], remote: [newer]).first?.sealedContentBase64,
                       "bmV3ZXI=")
        XCTAssertEqual(MergeRules.mergeLetters(local: [newer], remote: [older]).first?.sealedContentBase64,
                       "bmV3ZXI=")
    }

    /// **封存不可逆。** 一端已封存、另一端还是草稿 → 结果是已封存。
    ///
    /// 否则同步会把一封已经"托付出去"的信变回可编辑，D-08 的全部重量就没了。
    /// 注意这一条**不看 updatedAt** —— 草稿那一端更晚也不能翻案。
    func testSealingIsIrreversibleAcrossSync() {
        let draft = letter("L1", opened: false, draft: true, updated: cal.day(2026, 12, 9))
        let sealed = letter("L1", opened: false, draft: false, updated: cal.day(2026, 12, 1))
        for merged in [MergeRules.mergeLetters(local: [draft], remote: [sealed]),
                       MergeRules.mergeLetters(local: [sealed], remote: [draft])] {
            XCTAssertEqual(merged.count, 1)
            XCTAssertFalse(merged[0].isDraft, "封存不可逆")
        }
    }

    /// 信件不可修改，唯一会变的是「是否已开启」—— 任一端开启过即为已开启。
    func testLetterOpenedOnEitherSideWins() {
        let sealed = letter("L1", opened: false)
        let opened = letter("L1", opened: true, openedAt: cal.day(2026, 12, 2), content: "正文")
        for merged in [MergeRules.mergeLetters(local: [sealed], remote: [opened]),
                       MergeRules.mergeLetters(local: [opened], remote: [sealed])] {
            XCTAssertEqual(merged.count, 1)
            XCTAssertTrue(merged[0].isOpened)
            XCTAssertEqual(merged[0].content, "正文")
        }
    }

    /// 合并**不得**把未开启的信提前变成明文 —— 导出与同步都不能成为偷看的旁路（D-08）。
    func testSealedLetterStaysSealedThroughMerge() {
        let merged = MergeRules.mergeLetters(local: [letter("L1", opened: false)],
                                             remote: [letter("L1", opened: false)])
        XCTAssertEqual(merged.count, 1)
        XCTAssertFalse(merged[0].isOpened)
        XCTAssertNil(merged[0].content)
        XCTAssertNotNil(merged[0].sealedContentBase64)
    }

    func testMergeIsCommutativeInCount() {
        let l = ExportSnapshot(exportedAt: cal.day(2026, 12, 1),
                               exams: [exam("A", primary: true, updated: cal.day(2026, 12, 1))],
                               checkIns: [checkIn(2026, 12, 1)], notes: [], letters: [])
        let r = ExportSnapshot(exportedAt: cal.day(2026, 12, 2),
                               exams: [exam("A", primary: true, updated: cal.day(2026, 12, 2))],
                               checkIns: [checkIn(2026, 12, 2)], notes: [], letters: [])
        let ab = MergeRules.merge(local: l, remote: r, now: cal.day(2026, 12, 3))
        let ba = MergeRules.merge(local: r, remote: l, now: cal.day(2026, 12, 3))
        XCTAssertEqual(ab.checkIns, ba.checkIns)
        XCTAssertEqual(ab.exams.count, ba.exams.count)
    }
}

/// 删除必须能同步出去。
///
/// 合并规则本身只会让数据变多（心里话按 id 取较新，打卡取并集）。
/// 没有墓碑时，本地删掉的一句心里话会在下一次同步时从服务端原样长回来，
/// 而用户已经以为它没了 —— **一个会自己撤销的删除比没有删除更糟**。
final class DeletionMergeTests: XCTestCase {

    private let cal = DayCalendar.fixed()

    private func note(_ id: String, updated: Date) -> ExportSnapshot.NoteDTO {
        ExportSnapshot.NoteDTO(id: id, date: cal.day(2026, 12, 1), content: "在",
                               createdAt: cal.day(2026, 12, 1), updatedAt: updated)
    }

    private func tomb(_ id: String, at: Date) -> ExportSnapshot.DeletionDTO {
        ExportSnapshot.DeletionDTO(id: id, kind: .note, deletedAt: at)
    }

    /// 本地删了、远端还有 → 结果里没有。这是这套机制存在的全部理由。
    func testTombstonedNoteDoesNotComeBackFromTheServer() {
        let written = cal.day(2026, 12, 1)
        let merged = MergeRules.mergeNotes(
            local: [],
            remote: [note("N1", updated: written)],
            deletions: [tomb("N1", at: cal.day(2026, 12, 2))]
        )
        XCTAssertTrue(merged.isEmpty)
    }

    /// 删除不享受特权：另一端在删除之后又改过同一句，内容留下。
    /// 这跟本文件其他地方的"后写入者胜"是同一条规则。
    func testAnEditAfterTheDeleteWins() {
        let merged = MergeRules.mergeNotes(
            local: [],
            remote: [note("N1", updated: cal.day(2026, 12, 5))],
            deletions: [tomb("N1", at: cal.day(2026, 12, 2))]
        )
        XCTAssertEqual(merged.count, 1)
    }

    /// 同一天删的、同一天改的 → 删除生效（`deletedAt >= updatedAt`）。
    /// 取等号是因为两边都按天对齐，不取等号时"当天删的"会被当天写的顶掉。
    func testSameInstantCountsAsDeleted() {
        let t = cal.day(2026, 12, 2)
        let merged = MergeRules.mergeNotes(local: [note("N1", updated: t)], remote: [],
                                           deletions: [tomb("N1", at: t)])
        XCTAssertTrue(merged.isEmpty)
    }

    /// 墓碑没点名的记录一个都不能少。
    func testOtherNotesAreUntouched() {
        let merged = MergeRules.mergeNotes(
            local: [note("N1", updated: cal.day(2026, 12, 1))],
            remote: [note("N2", updated: cal.day(2026, 12, 1))],
            deletions: [tomb("N1", at: cal.day(2026, 12, 3))]
        )
        XCTAssertEqual(merged.map(\.id), ["N2"])
    }

    /// 墓碑本身取并集，且**不会因为记录复活而消失** ——
    /// 丢掉它，第三台设备就会重新把这条记录带回来。
    func testTombstonesSurviveTheMergeEvenWhenTheRecordDid() {
        let local = ExportSnapshot(exportedAt: cal.day(2026, 12, 9), exams: [], checkIns: [],
                                   notes: [], letters: [],
                                   deletions: [tomb("N1", at: cal.day(2026, 12, 2))])
        let remote = ExportSnapshot(exportedAt: cal.day(2026, 12, 9), exams: [], checkIns: [],
                                    notes: [note("N1", updated: cal.day(2026, 12, 5))],
                                    letters: [], deletions: [])
        let merged = MergeRules.merge(local: local, remote: remote, now: cal.day(2026, 12, 9))
        XCTAssertEqual(merged.notes.count, 1)          // 改在删之后，内容留下
        XCTAssertEqual(merged.deletions.count, 1)      // 墓碑照样带走
    }

    /// 同一条被两端各删一次 → 只留一条，取更晚的那次。
    func testDeletionsDedupeToTheLatest() {
        let merged = MergeRules.mergeDeletions(
            local: [tomb("N1", at: cal.day(2026, 12, 2))],
            remote: [tomb("N1", at: cal.day(2026, 12, 4))]
        )
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].deletedAt, cal.day(2026, 12, 4))
    }

    /// 这个字段是后加的。**旧导出文件必须还能读** ——
    /// "导出文件要跨版本读"正是这份格式存在的理由，加一个字段就废掉所有存档是不可接受的。
    func testOldExportsWithoutTheDeletionsKeyStillDecode() throws {
        let json = """
        {
          "schemaVersion": 1,
          "exportedAt": "2026-12-01T00:00:00Z",
          "exams": [], "checkIns": [], "notes": [], "letters": []
        }
        """
        let snapshot = try ExportSnapshot.jsonDecoder()
            .decode(ExportSnapshot.self, from: Data(json.utf8))
        XCTAssertTrue(snapshot.deletions.isEmpty)
    }
}
