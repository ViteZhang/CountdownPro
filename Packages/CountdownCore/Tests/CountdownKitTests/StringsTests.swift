import XCTest
@testable import CountdownKit

/// 文案是产品的一半。这些断言不是在测代码，是在**锁住产品决策**。
final class StringsTests: XCTestCase {

    /// 设计决策 D-02：按钮是「今天也在」，不是「打卡」。
    func testCheckInButtonWording() {
        XCTAssertEqual(Strings.Home.checkIn, "今天也在")
        XCTAssertEqual(Strings.Home.checkInDone, "今天也在")
        XCTAssertFalse(Strings.Home.checkIn.contains("打卡"))
    }

    /// 设计决策 D-01 / D-14：加法必须存在，且「已走过」在前。
    func testPassedCopyExists() {
        XCTAssertEqual(Strings.Home.passed(620), "你已走过 620 天")
        XCTAssertEqual(Strings.Onboarding.resultLabel, "你已经走过的天数")
    }

    /// 需求文档第 7 章：不制造紧迫与恐吓，不堆感叹号。
    func testNoExclamationMarksInUserFacingCopy() {
        let samples = [
            Strings.Home.checkIn, Strings.Home.ringSubtitle, Strings.Home.treeCaption,
            Strings.Onboarding.step1Title, Strings.Onboarding.step3Subtitle,
            Strings.Onboarding.resultFootnote, Strings.Letters.sealedFootnote,
            Strings.Log.backfillFootnote, Strings.Auth.methodTitle,
            Strings.Auth.guardianTitle, Strings.Auth.successTitle,
        ]
        for s in samples {
            XCTAssertFalse(s.contains("!"), s)
            XCTAssertFalse(s.contains("！"), s)
        }
    }

    /// 5.12 强约束：出分日不使用「恭喜」。归零卡也只肯定过程。
    func testNoCongratulations() {
        XCTAssertEqual(Strings.ShareCard.walkedItAll, "天，走完了")
        XCTAssertFalse(Strings.ShareCard.walkedItAll.contains("恭喜"))
        XCTAssertEqual(Strings.Auth.successTitle, "存好了") // 不是「登录成功」
    }

    /// 资料未给的文案必须是刺眼占位符，不能被误当成成品。
    func testMissingCopyIsLoudlyMarked() {
        XCTAssertTrue(Strings.Letters.composeTitle.hasPrefix("⟪待补文案："))
        XCTAssertTrue(Strings.Settings.title.hasPrefix("⟪待补文案："))
        XCTAssertTrue(Strings.ShareCard.watermark.hasPrefix("⟪待补文案："))
        XCTAssertTrue(Strings.Notifications.letterOpen.hasPrefix("⟪待补文案："))
        // 心理支持资源绝不自拟
        XCTAssertTrue(Strings.Settings.mentalHealthContent.hasPrefix("⟪待补文案："))
    }

    /// 已给定的文案不得混入占位符。
    func testProvidedCopyIsNotPlaceholder() {
        let provided = [
            Strings.Home.checkIn, Strings.Home.ringSubtitle,
            Strings.Onboarding.step3Title, Strings.Onboarding.resultFootnote,
            Strings.NoteSheet.placeholder, Strings.Letters.sealedFootnote,
            Strings.Auth.ageOver14, Strings.Auth.deleteConfirmCheckbox,
        ]
        for s in provided {
            XCTAssertFalse(s.contains("待补文案"), s)
        }
    }

    /// auth 原型：用「以后再说」，不用「跳过」—— 后者暗示这是流程的一步。
    func testAuthUsesLaterNotSkip() {
        XCTAssertEqual(Strings.Auth.Prompt.later, "以后再说")
        XCTAssertFalse(Strings.Auth.Prompt.later.contains("跳过"))
    }

    /// 注销告知的第 3 条是最重要的一条，必须用强调色。
    func testDeleteConsequencesEmphasis() {
        XCTAssertEqual(Strings.Auth.deleteConsequences.count, 5)
        XCTAssertEqual(
            Strings.Auth.deleteConsequences[Strings.Auth.deleteEmphasizedIndex],
            "未开启的信件将永久丢失，无法找回"
        )
    }
}
