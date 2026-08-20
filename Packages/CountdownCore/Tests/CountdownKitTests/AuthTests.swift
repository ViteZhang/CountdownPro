import XCTest
@testable import CountdownKit

final class LoginMethodPolicyTests: XCTestCase {

    /// 已确认为**企业主体** → 四种方式全部可用。
    /// 排序：微信 → QQ → 手机号 → Apple，微信置顶且为主按钮。
    func testBusinessEntityOnIOS() {
        XCTAssertEqual(LoginMethodPolicy.methods(platform: .iOS, entity: .business),
                       [.wechat, .qq, .phone, .apple])
        XCTAssertEqual(LoginMethodPolicy.primaryMethod(platform: .iOS, entity: .business), .wechat)
    }

    /// **一旦提供任何第三方登录，iOS 必须同时提供 Sign in with Apple**
    /// （App Store 审核指南 4.8）。这是审核硬要求，不是产品偏好。
    func testAppleSignInIsMandatoryWheneverThirdPartyExists() {
        for entity in [DeveloperEntity.business, .individual] {
            let methods = LoginMethodPolicy.methods(platform: .iOS, entity: entity)
            let hasOtherThirdParty = methods.contains { $0.isThirdParty && $0 != .apple }
            if hasOtherThirdParty {
                XCTAssertTrue(methods.contains(.apple), "\(entity)：有第三方登录就必须有 Apple")
            }
            XCTAssertTrue(LoginMethodPolicy.satisfiesAppleSignInRequirement(platform: .iOS, entity: entity))
        }
    }

    /// 个人主体拿不到微信/QQ 资质 —— 但 Apple 仍在，所以规则依然成立。
    func testIndividualEntityFallsBackToPhoneAndApple() {
        XCTAssertEqual(LoginMethodPolicy.methods(platform: .iOS, entity: .individual),
                       [.phone, .apple])
    }

    /// Android 端隐藏 Apple。
    func testAndroidHidesApple() {
        XCTAssertEqual(LoginMethodPolicy.methods(platform: .android, entity: .business),
                       [.wechat, .qq, .phone])
        XCTAssertFalse(LoginMethodPolicy.methods(platform: .android, entity: .business).contains(.apple))
    }

    /// 手机号是基线方案，任何主体、任何平台都必须有（5.14.2）。
    func testPhoneIsAlwaysAvailable() {
        for platform in [AuthPlatform.iOS, .android] {
            for entity in [DeveloperEntity.business, .individual] {
                XCTAssertTrue(LoginMethodPolicy.methods(platform: platform, entity: entity).contains(.phone))
            }
        }
    }

    /// 不做账号密码登录、不做邮箱注册。
    func testNoPasswordOrEmailMethods() {
        let names = LoginMethod.allCases.map(\.rawValue)
        for banned in ["password", "email", "username"] {
            XCTAssertFalse(names.contains(banned))
        }
    }
}

final class PhoneStepPolicyTests: XCTestCase {

    /// 「获取验证码」只看手机号位数 —— **协议未勾选时按钮仍可点**。
    ///
    /// 置灰的话用户不知道为什么点不动；可点 + 抖动才能指向问题所在。
    func testButtonEnabledDependsOnlyOnPhoneLength() {
        XCTAssertFalse(PhoneStepPolicy.canTapSendCode(phone: "1380000888"))
        XCTAssertTrue(PhoneStepPolicy.canTapSendCode(phone: "13800008888"))
    }

    /// 未勾选协议 → 抖动，**不弹 Alert**（Alert 打断感强）。
    func testUnagreedShakesInsteadOfAlerting() {
        XCTAssertEqual(PhoneStepPolicy.outcome(phone: "13800008888", agreedToTerms: false),
                       .shakeAgreement)
        XCTAssertEqual(PhoneStepPolicy.outcome(phone: "13800008888", agreedToTerms: true),
                       .send)
        XCTAssertEqual(PhoneStepPolicy.outcome(phone: "138", agreedToTerms: true), .ignored)
    }

    /// 脱敏展示：前 3 后 4，中间打码。
    func testPhoneMasking() {
        XCTAssertEqual(PhoneMask.masked("13800008888"), "138 **** 8888")
        XCTAssertEqual(PhoneMask.lastFour("13800008888"), "8888")
        XCTAssertEqual(PhoneMask.masked("138"), "")
    }
}

final class SMSRateLimitTests: XCTestCase {

    let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// 短信 0.03–0.05 元/条，同号码 60 秒一条。
    func testPerNumberCooldown() {
        XCTAssertTrue(SMSRateLimit.canSend(lastSentAt: nil, sentTodayCount: 0, now: now))
        XCTAssertFalse(SMSRateLimit.canSend(lastSentAt: now.addingTimeInterval(-30),
                                            sentTodayCount: 1, now: now))
        XCTAssertTrue(SMSRateLimit.canSend(lastSentAt: now.addingTimeInterval(-60),
                                           sentTodayCount: 1, now: now))
    }

    func testDailyLimit() {
        XCTAssertFalse(SMSRateLimit.canSend(lastSentAt: nil, sentTodayCount: 10, now: now))
        XCTAssertTrue(SMSRateLimit.canSend(lastSentAt: nil, sentTodayCount: 9, now: now))
    }

    func testRemainingCooldownDrivesTheResendLabel() {
        XCTAssertEqual(SMSRateLimit.remainingCooldown(lastSentAt: now, now: now), 60)
        XCTAssertEqual(SMSRateLimit.remainingCooldown(lastSentAt: now.addingTimeInterval(-45), now: now), 15)
        XCTAssertEqual(SMSRateLimit.remainingCooldown(lastSentAt: now.addingTimeInterval(-90), now: now), 0)
    }
}

final class VerificationCodePolicyTests: XCTestCase {

    /// 输满 6 位**自动提交**，不设「确认」按钮。
    func testAutoSubmitAtSixDigits() {
        XCTAssertFalse(VerificationCodePolicy.shouldAutoSubmit("12345"))
        XCTAssertTrue(VerificationCodePolicy.shouldAutoSubmit("123456"))
    }

    /// 超过 5 次失败 → 锁定 15 分钟并提示换登录方式。
    func testLockout() {
        XCTAssertFalse(VerificationCodePolicy.isLockedOut(failedAttempts: 4))
        XCTAssertTrue(VerificationCodePolicy.isLockedOut(failedAttempts: 5))
        let start = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(VerificationCodePolicy.lockoutEnds(from: start).timeIntervalSince1970, 900)
    }
}

final class AuthPromptTests: XCTestCase {

    /// **已登录不弹。** 账号已经有了，再弹就是骚扰。
    func testNeverPromptsWhenSignedIn() {
        XCTAssertNil(AuthPromptResolver.resolve(
            isSignedIn: true, satisfied: Set(AuthPromptTrigger.allCases), shownFlags: []
        ))
    }

    /// 写完第一封信是**最高优先级** —— 唯一"不可重建"的数据。
    func testFirstLetterWins() {
        XCTAssertEqual(
            AuthPromptResolver.resolve(
                isSignedIn: false,
                satisfied: [.firstLetter, .sevenDays, .export, .postExam],
                shownFlags: []
            ),
            .firstLetter
        )
    }

    /// **每个触发点一生只弹一次**，关闭后不再重复。
    func testEachTriggerFiresOnlyOnce() {
        XCTAssertEqual(
            AuthPromptResolver.resolve(isSignedIn: false,
                                       satisfied: [.firstLetter, .sevenDays],
                                       shownFlags: [.firstLetter]),
            .sevenDays
        )
        XCTAssertNil(AuthPromptResolver.resolve(isSignedIn: false,
                                                satisfied: [.firstLetter, .sevenDays],
                                                shownFlags: [.firstLetter, .sevenDays]))
    }

    func testSatisfiedTriggersFromData() {
        XCTAssertEqual(
            AuthPromptResolver.satisfiedTriggers(sealedLetterCount: 0, totalCheckIns: 6,
                                                 didRequestExport: false, isAfterExam: false),
            []
        )
        XCTAssertEqual(
            AuthPromptResolver.satisfiedTriggers(sealedLetterCount: 1, totalCheckIns: 7,
                                                 didRequestExport: true, isAfterExam: true),
            [.firstLetter, .sevenDays, .export, .postExam]
        )
    }

    /// 累计满 7 天，不是连续 7 天（D-03）。
    func testSevenDaysIsCumulative() {
        XCTAssertTrue(
            AuthPromptResolver.satisfiedTriggers(sealedLetterCount: 0, totalCheckIns: 7,
                                                 didRequestExport: false, isAfterExam: false)
                .contains(.sevenDays)
        )
        XCTAssertEqual(AppFlagKey.sevenDaysThreshold, 7)
    }

    /// 触发点的 flag key 互不相同，否则弹过一个会连带压掉另一个。
    func testFlagKeysAreDistinct() {
        let keys = AuthPromptTrigger.allCases.map(\.flagKey)
        XCTAssertEqual(Set(keys).count, keys.count)
    }
}
