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
        XCTAssertTrue(Strings.ShareCard.watermark.hasPrefix("⟪待补文案："))
        XCTAssertTrue(Strings.Notifications.letterOpen.hasPrefix("⟪待补文案："))
        // 用户协议与隐私政策正文必须由律师/合规出具，**不许 AI 生成后直接上线**。
        XCTAssertTrue(Strings.About.privacyBody.hasPrefix("⟪待补文案："))
        XCTAssertTrue(Strings.About.termsBody.hasPrefix("⟪待补文案："))
        XCTAssertTrue(Strings.About.icpNumber.hasPrefix("⟪待补文案："))
    }

    // MARK: - 心理支持资源
    //
    // 这一组断言守的不是拼写，是"不许编"。
    // 号码写错、主办单位写错、或者写成一个好听但不存在的号码，
    // 后果是一个真的很难熬的人打过去没人接。

    func testHotlineNumbersAreTheOfficialOnes() {
        // 12356：国家卫生健康委协调工业和信息化部设置的全国统一心理援助热线
        XCTAssertEqual(Strings.MentalHealth.hotlineNationalNumber, "12356")
        XCTAssertTrue(Strings.MentalHealth.hotlineNationalCaption.contains("国家卫生健康委"))
        // 12355：共青团中央设立的青少年服务台
        XCTAssertEqual(Strings.MentalHealth.hotlineYouthNumber, "12355")
        XCTAssertTrue(Strings.MentalHealth.hotlineYouthCaption.contains("共青团中央"))
    }

    /// **不得声称 24 小时。**
    /// 国家卫生健康委的要求是每个设区的市每日不少于 18 小时，各地实际时长并不统一。
    /// 写死「24 小时」会让一个半夜打不通的人以为是自己的问题。
    func testHotlineNeverPromisesRoundTheClock() {
        for s in [Strings.MentalHealth.intro,
                  Strings.MentalHealth.footnote,
                  Strings.MentalHealth.hotlineNationalCaption,
                  Strings.MentalHealth.hotlineYouthCaption] {
            XCTAssertFalse(s.contains("24 小时"), s)
            XCTAssertFalse(s.contains("24小时"), s)
            XCTAssertFalse(s.contains("全天"), s)
        }
        // 打不通时给的是替代方案，不是道歉，也不是"请稍后再试"。
        XCTAssertTrue(Strings.MentalHealth.footnote.contains("换一个试试"))
    }

    /// 页面内不做任何情绪评估、量表、问卷 —— 那是没有资质的心理筛查。
    /// 文案层面先堵住：不出现任何提问句式。
    func testMentalHealthPageAsksNothing() {
        for s in [Strings.MentalHealth.intro, Strings.MentalHealth.footnote] {
            XCTAssertFalse(s.contains("？"), s)
            XCTAssertFalse(s.contains("?"), s)
        }
    }

    /// 考后停止打卡的两句文案：陈述，不评价。
    func testPostExamFreezeIsStatedNotCelebrated() {
        let total = Strings.PostExam.frozenTotal(315)
        XCTAssertEqual(total, "你一共来了 315 天")
        XCTAssertEqual(Strings.PostExam.frozenCaption, "这个数字不会再变了")
        for s in [total, Strings.PostExam.frozenCaption, Strings.PostExam.resultDay] {
            XCTAssertFalse(s.contains("恭喜"), s)
            XCTAssertFalse(s.contains("！"), s)
        }
    }

    /// 删除考试必须报出具体会丢什么，且给出数字。
    /// 只说「数据将被删除」等于没说。
    func testDeleteExamSpellsOutWhatIsLost() {
        let body = Strings.Exams.deleteBody(checkInDays: 128, notes: 36, letters: 3)
        XCTAssertTrue(body.contains("128"))
        XCTAssertTrue(body.contains("36"))
        XCTAssertTrue(body.contains("3"))
        // 按钮不是「确定 / 取消」——「留着」比「取消」更清楚地说明了不点会发生什么。
        XCTAssertEqual(Strings.Exams.deleteConfirm, "删掉")
        XCTAssertEqual(Strings.Exams.deleteCancel, "留着")
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

    // MARK: - 信件文案禁区（信件文案表第 9 节）

    /// 这个功能的全部价值在于情感重量，任何一句被改成产品腔，重量就没了。
    /// 这条测试把禁区清单钉死 —— 它拦的不是拼写，是语气。
    func testLetterCopyAvoidsForbiddenPhrasings() {
        let forbidden = [
            "亲爱的自己", "致未来的我",   // 替用户定调，很多人写不出这种口吻
            "时光胶囊",                   // 产品术语，不是人话
            "见证你的成长", "记录你的蜕变", // 鸡汤
            "相信努力会有回报",            // 预设结果，考砸的人看到会刺痛
            "恭喜",                       // 这不是成就
            "保存成功", "操作成功",        // 系统腔
            "抱歉",                       // 不道歉
            "加油", "冲鸭",
        ]
        let all = [
            Strings.Letters.title, Strings.Letters.subtitle, Strings.Letters.writeNew,
            Strings.Letters.emptyTitle, Strings.Letters.emptySubtitle, Strings.Letters.emptyAction,
            Strings.Letters.composeTitle, Strings.Letters.composeSubtitle,
            Strings.Letters.composePlaceholder, Strings.Letters.composeNext,
            Strings.Letters.draftPromptTitle, Strings.Letters.draftPromptBody,
            Strings.Letters.triggerTitle, Strings.Letters.triggerSubtitle,
            Strings.Letters.resultDayHint,
            Strings.Letters.customDateBody, Strings.Letters.customDateInPast,
            Strings.Letters.customDateAfterExam, Strings.Letters.customDateIsToday,
            Strings.Letters.sealTitle, Strings.Letters.sealConfirm, Strings.Letters.sealCancel,
            Strings.Letters.sealedDoneTitle, Strings.Letters.sealedDoneBack,
            Strings.Letters.dueTitle, Strings.Letters.dueOpen, Strings.Letters.dueLater,
            Strings.Letters.readDone,
            Strings.Letters.deleteDraftTitle, Strings.Letters.deleteDraftBody,
            Strings.Letters.deleteSealedTitle, Strings.Letters.deleteSealedBody,
            Strings.Letters.deleteOpenedTitle, Strings.Letters.deleteOpenedBody,
            Strings.Letters.deleteConfirm, Strings.Letters.deleteCancel,
            Strings.Letters.deletedToast, Strings.Letters.lengthFull,
            Strings.Letters.notificationTitle, Strings.Letters.notificationBodyNightBefore,
        ] + [Strings.Letters.sealBody(openDate: "2027年2月27日"),
             Strings.Letters.sealedDoneSubtitle(days: 100),
             Strings.Letters.notificationBody(daysAgo: 100)]

        for text in all {
            for phrase in forbidden {
                XCTAssertFalse(text.contains(phrase), "「\(phrase)」出现在：\(text)")
            }
            XCTAssertFalse(text.contains("！"), text)
        }
    }

    /// 「出分那天」的副文案是刻意中性的。
    /// 出分日会把用户分成截然不同的两群，提前用一句中性的话打个底，
    /// 比考完之后再想办法补救要好。
    func testResultDayHintStaysNeutral() {
        XCTAssertEqual(Strings.Letters.resultDayHint, "不管结果怎样，那天你可能会需要它")
        for presumptuous in ["好成绩", "理想", "梦想", "如愿", "上岸"] {
            XCTAssertFalse(Strings.Letters.resultDayHint.contains(presumptuous))
        }
    }

    /// 封存确认的主按钮不加「确认」二字 ——「封起来」本身就是动作；
    /// 次按钮用「再看看」不用「取消」；删除的次按钮用有立场的「留着」。
    func testActionVerbsAreNotGenericChrome() {
        XCTAssertEqual(Strings.Letters.sealConfirm, "封起来")
        XCTAssertFalse(Strings.Letters.sealConfirm.contains("确认"))
        XCTAssertEqual(Strings.Letters.sealCancel, "再看看")
        XCTAssertEqual(Strings.Letters.deleteCancel, "留着")
        for text in [Strings.Letters.sealCancel, Strings.Letters.deleteCancel] {
            XCTAssertNotEqual(text, "取消")
        }
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
