import XCTest
@testable import CountdownKit

final class ShareCardTests: XCTestCase {

    let cal = DayCalendar.fixed()
    lazy var builder = ShareCardBuilder(cal: cal)
    lazy var engine = CountdownEngine(cal: cal)

    private func countdown(today: Date? = nil) -> Countdown {
        engine.countdown(startDate: cal.day(2025, 3, 22),
                         targetDate: cal.day(2027, 6, 7),
                         today: today ?? cal.day(2026, 12, 2))
    }

    private var allCards: [ShareCardContent] {
        [
            builder.milestone(examTitle: "高考", countdown: countdown()),
            builder.note(content: "今天数学错了七道，但我把七道都弄懂了。",
                         date: cal.day(2026, 12, 2), nthCheckInDay: 129,
                         countdown: countdown(), censusDisplay: "41.2"),
            builder.zero(examDate: cal.day(2027, 6, 7),
                         countdown: countdown(today: cal.day(2027, 6, 7)),
                         totalCheckIns: 315, totalNotes: 92),
        ]
    }

    // MARK: - D-11：统一符号

    /// **「已走过」进度条必须出现在每一张卡上。**
    /// 没有二维码的情况下，它是全部的品牌识别 —— 所以它不是可选字段。
    func testEveryCardCarriesThePassedProgressBar() {
        for card in allCards {
            XCTAssertGreaterThanOrEqual(card.passedProgress, 0, "\(card.kind)")
            XCTAssertLessThanOrEqual(card.passedProgress, 1, "\(card.kind)")
        }
        let names = Mirror(reflecting: allCards[0]).children.compactMap(\.label)
        XCTAssertTrue(names.contains("passedProgress"))
    }

    /// 每张卡都要点出「已走过」多少天，不能只有减法。
    func testEveryCardStatesDaysPassed() {
        XCTAssertTrue(allCards[0].footnotes.contains { $0.contains("已经走过") })
        XCTAssertTrue(allCards[1].footnotes.contains { $0.contains("还剩") })
        XCTAssertTrue(allCards[2].footnotes.contains { $0.contains("累计坚持") })
        XCTAssertEqual(allCards[2].passedProgress, 1.0)
    }

    /// 水印仅一行淡色产品名 —— **不含 Logo、不含二维码、不含下载引导**。
    func testWatermarkCarriesNoCallToAction() {
        for card in allCards {
            for banned in ["二维码", "扫码", "下载", "长按", "识别", "http", "www"] {
                XCTAssertFalse(card.watermark.contains(banned), "\(card.kind): \(card.watermark)")
            }
        }
    }

    /// 三类卡的内容结构必须明显不同，避免"同一套模板"的廉价感。
    func testThreeKindsAreStructurallyDistinct() {
        let cards = allCards
        XCTAssertNotNil(cards[0].bigNumber)      // 节点卡：大数字主导
        XCTAssertNil(cards[0].quote)

        XCTAssertNil(cards[1].bigNumber)         // 心里话卡：引文主导，没有大数字
        XCTAssertNotNil(cards[1].quote)

        XCTAssertNotNil(cards[2].bigNumber)      // 归零卡：大数字 + 实心开花树
        XCTAssertTrue(cards[2].showsBloomingTree)
        XCTAssertFalse(cards[0].showsBloomingTree)
        XCTAssertFalse(cards[1].showsBloomingTree)
    }

    // MARK: - 内容

    func testMilestoneCard() {
        let card = builder.milestone(examTitle: "高考", countdown: countdown())
        XCTAssertEqual(card.label, "距离高考")
        XCTAssertEqual(card.bigNumber, "187")
        XCTAssertEqual(card.bigUnit, "天")
        XCTAssertEqual(card.footnotes, ["已经走过 620 天"])
    }

    func testNoteCard() {
        let card = builder.note(content: "今天很累。", date: cal.day(2026, 12, 2),
                                nthCheckInDay: 129, countdown: countdown(), censusDisplay: "41.2")
        XCTAssertEqual(card.label, "第 129 天")
        XCTAssertEqual(card.quote, "今天很累。")
        XCTAssertEqual(card.footnotes, ["2026.12.02 · 还剩 187 天", "今天有 41.2 万人和我一起"])
    }

    /// 同考人数拉不到时**整行不出现** —— 分享出去的图更不能带假数字（D-09）。
    func testNoteCardOmitsCensusLineWhenUnavailable() {
        let card = builder.note(content: "今天很累。", date: cal.day(2026, 12, 2),
                                nthCheckInDay: 129, countdown: countdown(), censusDisplay: nil)
        XCTAssertEqual(card.footnotes.count, 1)
        XCTAssertFalse(card.footnotes.contains { $0.contains("万人") })
    }

    /// 归零卡：「807 天，走完了」—— 肯定过程，不肯定结果。
    func testZeroCard() {
        let card = builder.zero(examDate: cal.day(2027, 6, 7),
                                countdown: countdown(today: cal.day(2027, 6, 7)),
                                totalCheckIns: 315, totalNotes: 92)
        XCTAssertEqual(card.label, "2027.06.07")
        XCTAssertEqual(card.bigNumber, "807")
        XCTAssertEqual(card.bigUnit, "天，走完了")
        XCTAssertEqual(card.footnotes, ["累计坚持 315 天 · 写下 92 句话"])
    }

    /// 5.12 强约束：不使用「恭喜」。文案规范：不堆感叹号、不写鸡汤。
    func testNoCardCopyIsCongratulatoryOrPushy() {
        let banned = ["恭喜", "！", "!", "加油", "冲刺", "梦想", "名校", "逆袭"]
        for card in allCards {
            let texts = [card.label, card.bigUnit ?? "", card.watermark] + card.footnotes
            for text in texts {
                for phrase in banned {
                    XCTAssertFalse(text.contains(phrase), "「\(phrase)」出现在 \(card.kind)：\(text)")
                }
            }
        }
    }

    /// 3:4 竖版，导出 1080×1440。
    func testExportGeometry() {
        XCTAssertEqual(ShareCardBuilder.exportSize.width / ShareCardBuilder.exportSize.height,
                       3.0 / 4.0, accuracy: 1e-9)
        XCTAssertEqual(ShareCardBuilder.designSize.width / ShareCardBuilder.designSize.height,
                       3.0 / 4.0, accuracy: 1e-9)
        XCTAssertEqual(ShareCardBuilder.exportScale, 4.0, accuracy: 1e-9)
    }
}

final class AppOpenPromptTests: XCTestCase {

    let cal = DayCalendar.fixed()
    lazy var today = cal.day(2026, 12, 2)
    lazy var engine = CountdownEngine(cal: cal)

    private func countdown(remaining: Int) -> Countdown {
        engine.countdown(startDate: cal.day(2025, 3, 22),
                         targetDate: cal.adding(days: remaining, to: today),
                         today: today)
    }

    private func letter(_ id: String, open: Date, opened: Bool = false, draft: Bool = false) -> LetterDigest {
        LetterDigest(id: id, writtenAt: cal.day(2026, 8, 24), openAt: open,
                     isOpened: opened, isDraft: draft)
    }

    private func resolve(
        remaining: Int = 200,
        letters: [LetterDigest] = [],
        deferred: Set<String> = [],
        shown: Set<Int> = []
    ) -> AppOpenPrompt? {
        AppOpenPromptResolver.resolve(
            countdown: countdown(remaining: remaining), letters: letters,
            deferredLetterIDs: deferred, shownMilestoneDays: shown, today: today, cal: cal
        )
    }

    func testNothingToShow() {
        XCTAssertNil(resolve())
    }

    /// **信件优先于分享卡**，即使同一天两者都命中。
    /// 信是不可重建的，卡片随时可以手动生成。
    func testLetterBeatsMilestoneCard() {
        let prompt = resolve(remaining: 100, letters: [letter("L1", open: today)])
        XCTAssertEqual(prompt, .letterDue(letterID: "L1", writtenDaysAgo: 100))
    }

    func testMilestoneShowsWhenNoLetterDue() {
        XCTAssertEqual(resolve(remaining: 100), .milestoneCard(daysRemaining: 100))
    }

    /// 「待会儿」当天不再弹 —— 但不影响同一天的节点卡补位。
    func testDeferredLetterFallsThroughToMilestone() {
        let prompt = resolve(remaining: 100, letters: [letter("L1", open: today)], deferred: ["L1"])
        XCTAssertEqual(prompt, .milestoneCard(daysRemaining: 100))
    }

    /// 「待会儿」**次日再触发**，直到被拆开 —— 所以 deferred 是按天判断的。
    func testDeferredLetterReturnsNextDay() {
        // 次日的 deferred 集合为空（存的是"最后推迟的日期"，不是永久开关）
        let prompt = resolve(remaining: 100, letters: [letter("L1", open: today)], deferred: [])
        XCTAssertEqual(prompt, .letterDue(letterID: "L1", writtenDaysAgo: 100))
    }

    func testOpenedAndDraftLettersNeverPrompt() {
        XCTAssertNil(resolve(letters: [letter("L1", open: today, opened: true)]))
        XCTAssertNil(resolve(letters: [letter("L2", open: today, draft: true)]))
    }

    /// 多封同时到期取最早的那封。
    func testEarliestDueLetterWins() {
        let prompt = resolve(letters: [
            letter("later", open: today),
            letter("earlier", open: cal.day(2026, 11, 20)),
        ])
        XCTAssertEqual(prompt, .letterDue(letterID: "earlier", writtenDaysAgo: 100))
    }

    /// 节点卡一生只弹一次。
    func testShownMilestoneDoesNotRepeat() {
        XCTAssertNil(resolve(remaining: 100, shown: [100]))
        XCTAssertEqual(resolve(remaining: 50, shown: [100]), .milestoneCard(daysRemaining: 50))
    }

    /// 最多弹一个 —— 不会让用户连吃两个全屏。
    func testAtMostOnePrompt() {
        let prompt = resolve(remaining: 100, letters: [letter("L1", open: today)])
        XCTAssertNotNil(prompt)
        if case .letterDue = prompt! {} else { XCTFail("信件应当优先") }
    }
}
