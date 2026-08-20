import Foundation

/// 登录方式（需求文档 5.14.2 / auth 原型 ACCOUNT/01）。
public enum LoginMethod: String, CaseIterable, Sendable, Identifiable {
    case wechat
    case qq
    case phone
    case apple

    public var id: String { rawValue }

    /// 是否为第三方登录。
    ///
    /// 这个判断有法律后果：**一旦提供任何第三方登录，
    /// iOS 端必须同时提供 Sign in with Apple**，否则审核不通过
    /// （App Store 审核指南 4.8）。
    public var isThirdParty: Bool {
        switch self {
        case .wechat, .qq, .apple: return true
        case .phone:               return false
        }
    }

    /// 需要企业主体（微信开放平台移动应用需企业认证）。
    public var requiresBusinessEntity: Bool {
        self == .wechat || self == .qq
    }
}

public enum AuthPlatform: Sendable {
    case iOS
    case android
}

/// 开发主体资质。已确认：**企业主体**，四种方式全部可用。
public enum DeveloperEntity: Sendable {
    case business
    case individual
}

public enum LoginMethodPolicy {

    /// 登录方式的展示顺序与可用性。
    ///
    /// 排序：微信 → QQ → 手机号 → Apple。微信置顶且为主按钮（转化最高）。
    ///
    /// - 个人主体拿不到微信/QQ 的移动应用资质 → 只剩手机号 + Apple。
    /// - **iOS 只要出现任何第三方登录，就必须同时提供 Apple。** 这条是审核硬要求，
    ///   不是产品偏好，所以由这个函数保证，而不是靠视图层记得加。
    /// - Android 端隐藏 Apple。
    public static func methods(platform: AuthPlatform, entity: DeveloperEntity) -> [LoginMethod] {
        var result: [LoginMethod] = []

        if entity == .business {
            result.append(.wechat)
            result.append(.qq)
        }
        result.append(.phone)

        switch platform {
        case .iOS:
            // iOS 端一律提供 Apple。
            //
            // 审核指南 4.8 的硬要求是「有第三方登录就必须有 Apple」，
            // 但它并不禁止单独提供 Apple；而需求文档 5.14.2 明确规定
            // 个人主体也要做「手机号 + Sign in with Apple」。
            // 两者合起来就是：iOS 无条件带 Apple。
            result.append(.apple)
        case .android:
            // Android 端隐藏 Apple。
            break
        }
        return result
    }

    /// 主按钮（实心）。列表里只有第一项是主按钮，其余是描边。
    public static func primaryMethod(platform: AuthPlatform, entity: DeveloperEntity) -> LoginMethod? {
        methods(platform: platform, entity: entity).first
    }

    /// 自检：这套配置是否满足 App Store 审核指南 4.8。
    public static func satisfiesAppleSignInRequirement(
        platform: AuthPlatform, entity: DeveloperEntity
    ) -> Bool {
        let list = methods(platform: platform, entity: entity)
        guard platform == .iOS else { return true }
        let hasOtherThirdParty = list.contains { $0.isThirdParty && $0 != .apple }
        return !hasOtherThirdParty || list.contains(.apple)
    }
}

/// 短信频控（auth 原型 ACCOUNT/03「成本」）。
///
/// 短信约 0.03–0.05 元/条，必须做频控 —— 否则会被刷到破产。
/// 客户端这一层只是第一道；服务端仍需独立限流，客户端的限制永远可以被绕过。
public struct SMSRateLimit: Sendable {
    /// 同号码 60 秒一条
    public static let perNumberCooldownSeconds = 60
    /// 同号码单日上限 10 条
    public static let perNumberDailyLimit = 10

    public static func canSend(
        lastSentAt: Date?,
        sentTodayCount: Int,
        now: Date = .now
    ) -> Bool {
        guard sentTodayCount < perNumberDailyLimit else { return false }
        guard let lastSentAt else { return true }
        return now.timeIntervalSince(lastSentAt) >= Double(perNumberCooldownSeconds)
    }

    public static func remainingCooldown(lastSentAt: Date?, now: Date = .now) -> Int {
        guard let lastSentAt else { return 0 }
        let elapsed = now.timeIntervalSince(lastSentAt)
        return max(0, perNumberCooldownSeconds - Int(elapsed))
    }
}

/// 验证码校验（auth 原型 ACCOUNT/03「异常」）。
public struct VerificationCodePolicy: Sendable {
    public static let length = 6
    /// 超过 5 次失败 → 锁定 15 分钟并提示换登录方式。
    public static let maxAttempts = 5
    public static let lockoutMinutes = 15

    /// **输满 6 位自动提交**，不设「确认」按钮。
    public static func shouldAutoSubmit(_ code: String) -> Bool {
        code.filter(\.isNumber).count == length
    }

    public static func isLockedOut(failedAttempts: Int) -> Bool {
        failedAttempts >= maxAttempts
    }

    public static func lockoutEnds(from date: Date) -> Date {
        date.addingTimeInterval(Double(lockoutMinutes) * 60)
    }
}

/// 手机号登录这一步的可提交性。
public enum PhoneStepPolicy {

    /// 「获取验证码」是否可点。
    ///
    /// 注意**只看手机号位数，不看协议是否勾选**。
    ///
    /// 原因：协议未勾选时按钮应当**可点**，点下去给抖动反馈 ——
    /// 如果把按钮置灰，用户不知道为什么点不动。
    /// auth 原型 ACCOUNT/02 明确：未勾选时抖动 + 文字变警示色，**不弹 Alert**
    /// （Alert 打断感强，抖动能明确指向问题所在）。
    public static func canTapSendCode(phone: String) -> Bool {
        PhoneMask.isValid(phone)
    }

    /// 点下去之后是发送，还是抖动。
    public static func outcome(phone: String, agreedToTerms: Bool) -> Outcome {
        guard PhoneMask.isValid(phone) else { return .ignored }
        // 协议同意项**独立勾选、不得默认勾选**（5.14.3 法规硬性要求）。
        return agreedToTerms ? .send : .shakeAgreement
    }

    public enum Outcome: Equatable, Sendable {
        case send
        /// 抖动 + 文字变警示色。**不弹 Alert。**
        case shakeAgreement
        case ignored
    }
}
