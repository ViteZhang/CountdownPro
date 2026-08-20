import XCTest
@testable import CountdownKit

final class LetterPresentationTests: XCTestCase {

    let cal = DayCalendar.fixed()
    lazy var today = cal.day(2026, 12, 2)

    // MARK: - 列表状态

    func testStateDerivation() {
        func state(isDraft: Bool = false, isOpened: Bool = false, openAt: Date) -> LetterState {
            LetterPresentation.state(isDraft: isDraft, isOpened: isOpened, openedAt: nil,
                                     openAt: openAt, today: today, cal: cal)
        }
        XCTAssertEqual(state(isDraft: true, openAt: today), .draft)
        XCTAssertEqual(state(openAt: cal.day(2027, 3, 12)), .sealed(daysRemaining: 100))
        XCTAssertEqual(state(openAt: today), .openable)
        XCTAssertEqual(state(openAt: cal.day(2026, 11, 1)), .openable)  // 逾期未拆仍可开
        XCTAssertEqual(state(isOpened: true, openAt: cal.day(2026, 11, 1)),
                       .opened(at: cal.day(2026, 11, 1)))
    }

    /// 草稿优先于一切 —— 它还没封存，谈不上到期。
    func testDraftBeatsEverything() {
        XCTAssertEqual(
            LetterPresentation.state(isDraft: true, isOpened: false, openedAt: nil,
                                     openAt: cal.day(2020, 1, 1), today: today, cal: cal),
            .draft
        )
    }

    // MARK: - 封存占位方块

    /// 用实心方块，不用模糊或马赛克 ——
    /// 模糊暗示"看得到但看不清"，会诱发用户去试；实心方块是彻底的不可见。
    func testPlaceholderUsesSolidBlocks() {
        let p = LetterPresentation.sealedPlaceholder(contentLength: 200)
        XCTAssertTrue(p.allSatisfy { $0 == "■" })
        XCTAssertFalse(p.isEmpty)
    }

    /// **方块数不得能反推字数。**
    /// 只有 5 档，所以一个方块数对应一大段长度区间。
    func testBlockCountCannotRevealLength() {
        let sameBucket = [151, 200, 275, 350].map { LetterPresentation.blockCount(contentLength: $0) }
        XCTAssertEqual(Set(sameBucket).count, 1, "同一档内的不同长度必须给出相同方块数")

        let allBuckets = Set((1...1000).map { LetterPresentation.blockCount(contentLength: $0) })
        XCTAssertLessThanOrEqual(allBuckets.count, 5, "档位过多会泄露长度信息")
    }

    /// 但仍要"粗略换算"：长信看起来确实更长一些。
    func testLongerContentGetsMoreBlocks() {
        XCTAssertLessThan(LetterPresentation.blockCount(contentLength: 20),
                          LetterPresentation.blockCount(contentLength: 900))
    }

    func testEmptyAndHugeContentAreHandled() {
        XCTAssertEqual(LetterPresentation.blockCount(contentLength: 0), 6)
        XCTAssertEqual(LetterPresentation.blockCount(contentLength: 100_000), 18)
    }

    // MARK: - 落款

    func testSignatureUsesActualInterval() {
        XCTAssertEqual(
            LetterPresentation.signature(writtenAt: cal.day(2026, 8, 24), openedAt: today, cal: cal),
            "—— 100 天前的你"
        )
    }

    /// 间隔 ≥ 365 天改用「一年多以前」——
    /// "四百多天前"读起来像账单，"一年多以前"才是人话。
    func testSignatureSwitchesToVagueFormAfterAYear() {
        // 364 天：仍报具体天数
        XCTAssertEqual(
            LetterPresentation.signature(writtenAt: cal.day(2025, 12, 3), openedAt: cal.day(2026, 12, 2), cal: cal),
            "—— 364 天前的你"
        )
        // 恰好 365 天起：转模糊说法（文案表规则是「≥ 365」）
        XCTAssertEqual(
            LetterPresentation.signature(writtenAt: cal.day(2025, 12, 2), openedAt: cal.day(2026, 12, 2), cal: cal),
            "—— 一年多以前的你"
        )
        XCTAssertEqual(
            LetterPresentation.signature(writtenAt: cal.day(2024, 12, 2), openedAt: cal.day(2026, 12, 2), cal: cal),
            "—— 一年多以前的你"
        )
    }

    // MARK: - 字数提示

    /// 剩余 > 100 字时不显示 —— 计数器会让人分心，
    /// 而这一屏的全部目的是降低门槛、不制造表达压力。
    func testCounterHiddenUntilNearLimit() {
        XCTAssertNil(LetterPresentation.remainingHint(contentLength: 0))
        XCTAssertNil(LetterPresentation.remainingHint(contentLength: 899))
        XCTAssertEqual(LetterPresentation.remainingHint(contentLength: 900), "还能写 100 字")
        XCTAssertEqual(LetterPresentation.remainingHint(contentLength: 913), "还能写 87 字")
    }

    /// 写满了用「写满了」，不用「已达上限」。
    func testCounterAtLimit() {
        XCTAssertEqual(LetterPresentation.remainingHint(contentLength: 1000), "写满了")
        XCTAssertEqual(LetterPresentation.remainingHint(contentLength: 1200), "写满了")
    }

    // MARK: - 自定义开启日期

    func testCustomDateValidation() {
        let target = cal.day(2027, 6, 7)
        func check(_ d: Date) -> LetterPresentation.CustomDateIssue? {
            LetterPresentation.validateCustomDate(d, today: today, targetDate: target, cal: cal)
        }
        XCTAssertEqual(check(cal.day(2026, 12, 1)), .inPast)
        XCTAssertEqual(check(today), .isToday)
        XCTAssertEqual(check(cal.day(2027, 8, 1)), .afterExam)
        XCTAssertNil(check(cal.day(2027, 3, 1)))
    }

    /// 晚于考试日**允许** —— 有人就是想写给考完的自己。只提示，不阻拦。
    /// 已过去的**阻断** —— 一封立刻能拆的信没有意义。
    func testOnlyPastDatesAreBlocked() {
        let target = cal.day(2027, 6, 7)
        XCTAssertFalse(LetterPresentation.canUseCustomDate(cal.day(2026, 12, 1), today: today,
                                                          targetDate: target, cal: cal))
        XCTAssertTrue(LetterPresentation.canUseCustomDate(cal.day(2027, 8, 1), today: today,
                                                         targetDate: target, cal: cal))
        XCTAssertTrue(LetterPresentation.canUseCustomDate(today, today: today,
                                                         targetDate: target, cal: cal))
    }

    // MARK: - 考试日期变动后的节点重算

    private func item(_ id: String, trigger: LetterTrigger, openAt: Date) -> LetterListItem {
        LetterListItem(id: id, state: .sealed(daysRemaining: 1),
                       writtenAt: cal.day(2026, 8, 24), openAt: openAt, trigger: trigger)
    }

    /// 只调整预设节点的信，**自定义日期的信不动** ——
    /// 用户自己挑的那一天，凭什么替他改。
    func testOnlyPresetTriggersAreRecalculated() {
        let letters = [
            item("a", trigger: .d100, openAt: cal.day(2027, 2, 27)),
            item("b", trigger: .nightBefore, openAt: cal.day(2027, 6, 6)),
            item("c", trigger: .custom, openAt: cal.day(2027, 4, 1)),
        ]
        let changes = LetterPresentation.recalculateTriggers(
            letters: letters, newTargetDate: cal.day(2027, 6, 20), cal: cal
        )
        XCTAssertEqual(Set(changes.map(\.letterID)), ["a", "b"])
        XCTAssertEqual(changes.first { $0.letterID == "b" }?.newOpenAt, cal.day(2027, 6, 19))
    }

    /// 日期没变就不算"调整过"，否则 Toast 会说「有 3 封信调整了」但其实什么都没动。
    func testUnchangedDatesAreNotReported() {
        let letters = [item("a", trigger: .d100, openAt: cal.day(2027, 2, 27))]
        XCTAssertTrue(LetterPresentation.recalculateTriggers(
            letters: letters, newTargetDate: cal.day(2027, 6, 7), cal: cal
        ).isEmpty)
    }

    /// 出分日没有日程数据时不参与重算，不会把 openAt 抹成空。
    func testResultDayWithoutScheduleIsLeftAlone() {
        let letters = [item("a", trigger: .resultDay, openAt: cal.day(2027, 6, 23))]
        XCTAssertTrue(LetterPresentation.recalculateTriggers(
            letters: letters, newTargetDate: cal.day(2027, 6, 20), cal: cal
        ).isEmpty)
    }

    func testToastCountMatchesChanges() {
        let letters = [
            item("a", trigger: .d100, openAt: cal.day(2027, 2, 27)),
            item("b", trigger: .d50, openAt: cal.day(2027, 4, 18)),
        ]
        let changes = LetterPresentation.recalculateTriggers(
            letters: letters, newTargetDate: cal.day(2027, 6, 20), cal: cal
        )
        XCTAssertEqual(Strings.Letters.triggersAdjusted(changes.count), "有 2 封信的开启日期跟着调整了")
    }
}
