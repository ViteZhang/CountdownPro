import XCTest
@testable import CountdownKit

/// 法务文本的四条断言。
///
/// 它们守的不是措辞 —— 措辞归律师。守的是**"这份草案不能被当成成品发出去"**，
/// 以及**"里面写的必须是代码真的在做的事"**。
final class LegalTextTests: XCTestCase {

    private var allTexts: [(String, String)] {
        [("用户协议", LegalText.termsOfService),
         ("隐私政策", LegalText.privacyPolicy),
         ("个人信息收集清单", LegalText.personalInfoCollected),
         ("第三方信息共享清单", LegalText.thirdPartySharing)]
    }

    /// 每一份的开头都必须顶着草案横幅。
    ///
    /// 它在正文里而不是在注释里：注释拦不住任何人把文本复制去提审，
    /// 而删掉正文第一行是一个显眼的、需要解释的动作。
    /// 律师审完真要上线时，删掉横幅的同时这条测试会红 —— 那正是该停下来确认的时刻。
    func testEveryDocumentStillDeclaresItselfADraft() {
        for (name, text) in allTexts {
            XCTAssertTrue(text.hasPrefix(LegalText.draftBanner), name)
            XCTAssertTrue(text.contains("尚未经法律顾问审核"), name)
        }
    }

    /// 主体信息、联系方式这类开发方无权决定的内容必须还是占位符。
    /// 编一个上去比空着危险得多 —— 一份写着假主体的隐私政策是可以被直接处罚的。
    func testFactsWeDoNotKnowAreStillPlaceholders() {
        XCTAssertTrue(LegalText.termsOfService.contains("⟪待补文案：运营主体全称⟫"))
        XCTAssertTrue(LegalText.termsOfService.contains("⟪待补文案：联系邮箱⟫"))
        XCTAssertTrue(LegalText.privacyPolicy.contains("⟪待补文案：生效日期⟫"))
        XCTAssertTrue(LegalText.privacyPolicy.contains("⟪待补文案：数据存储地区⟫"))
        // 备案号在关于页底部单独展示，不在正文里。
        XCTAssertTrue(Strings.About.icpNumber.hasPrefix("⟪待补文案："))
    }

    /// 隐私政策里最重要的四句，每一句都对应代码里的一条硬约束。
    /// 改代码把某条约束破坏掉时，这里不会红 —— 但改这份文本删掉某一句时会红，
    /// 而那通常意味着有人打算让实现去迁就文本，方向反了。
    func testPrivacyPolicyStatesTheFourThingsTheCodeActuallyGuarantees() {
        let p = LegalText.privacyPolicy
        // 1. 不注册不收集（D-10：账号不是入场券）
        XCTAssertTrue(p.contains("不注册时，我们不收集你的任何个人信息"))
        // 2. 同考人数匿名（D-09）
        XCTAssertTrue(p.contains("不包含设备标识符"))
        // 3. 只存年龄布尔值，不存生日
        XCTAssertTrue(p.contains("不保存你的出生日期"))
        // 4. 封存的信我们也读不到（D-08）
        XCTAssertTrue(p.contains("我们也不例外"))
    }

    /// 不许出现"可能收集"这种给自己留余地的写法。
    ///
    /// 通用模板为了保险会把没做的事也写上。写多了不是谨慎，是失真：
    /// 用户按那份文本理解产品会得出完全错误的印象，监管按它核对实际行为也对不上。
    /// 这份文本的唯一优势就是**它是照着代码写的**，模糊化会把这个优势抵消掉。
    func testNoWeaselWords() {
        for (name, text) in allTexts {
            for weasel in ["可能收集", "可能会收集", "等信息", "包括但不限于"] {
                XCTAssertFalse(text.contains(weasel), "\(name) 里出现了「\(weasel)」")
            }
        }
    }

    /// 产品名不能写死，必须跟着 `Strings.productName` 走。
    /// 隐私政策里印着一个旧名字，是审核和抽查都会当场发现的问题。
    func testProductNameFlowsFromTheSingleSource() {
        for (name, text) in allTexts {
            XCTAssertTrue(text.contains(Strings.productName), name)
        }
    }

    /// 免责那一段必须点明"以官方信息为准"。
    /// 这个 App 会显示出分日和开学日，而 `PostExamScheduleTable` 里目前只有全国近似值 ——
    /// 用户照着它安排事情、结果差了几天，这一段是唯一说清楚过的地方。
    func testTermsSayTheDatesAreNotAuthoritative() {
        XCTAssertTrue(LegalText.termsOfService.contains("以考试主管部门发布的官方信息为准"))
        // 也必须说清这不是升学咨询或心理服务 —— 后者尤其重要（没有资质）。
        XCTAssertTrue(LegalText.termsOfService.contains("心理诊疗"))
    }
}
