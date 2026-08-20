import Foundation

/// 账号服务的抽象。
///
/// # 为什么先有协议
/// 后端尚未就位。视图层只依赖这个协议，`MockAuthService` 让全流程现在就能跑通；
/// 真接口到位后只替换实现，**视图一行都不用改**。
///
/// # 这里刻意没有的东西
/// 没有昵称、头像、性别、学校、地区（5.14.5）。
/// 不收集除手机号 / openid 之外的任何个人信息。
public protocol AuthService: Sendable {
    /// 发送短信验证码。
    func sendCode(to phone: String) async throws
    /// 校验验证码，返回账号。
    func verifyCode(_ code: String, phone: String, isOver14: Bool) async throws -> AuthAccount
    /// 第三方登录。
    func signIn(with method: LoginMethod, isOver14: Bool) async throws -> AuthAccount
    func signOut() async
    /// 注销账号。**法定权利，不得设置任何挽留阻碍。**
    func deleteAccount() async throws
}

/// 服务端返回的账号。
///
/// 需求文档 4.0：uid 与手机号 / 第三方 openid **解耦**；
/// 本地**不存手机号明文**，只保留后四位用于展示。
public struct AuthAccount: Equatable, Sendable {
    public let uid: String
    public let bindType: BindType
    public let phoneLastFour: String?
    public let boundAt: Date

    public init(uid: String, bindType: BindType, phoneLastFour: String?, boundAt: Date) {
        self.uid = uid
        self.bindType = bindType
        self.phoneLastFour = phoneLastFour
        self.boundAt = boundAt
    }
}

public enum AuthError: Error, Equatable, Sendable {
    case invalidCode
    case lockedOut(minutes: Int)
    case rateLimited(retryAfterSeconds: Int)
    case network
    case cancelled
}

/// 本地占位实现，供后端就位前跑通全流程。
///
/// **不做任何真实网络请求**，所以未登录时"只有同考人数一个请求"这条依然成立。
public actor MockAuthService: AuthService {

    /// 开发期固定验证码。真接口接入后这个类型整体删除。
    public static let acceptedCode = "123456"

    private var lastSentAt: Date?
    private var sentTodayCount = 0
    private var failedAttempts = 0

    public init() {}

    public func sendCode(to phone: String) async throws {
        guard SMSRateLimit.canSend(lastSentAt: lastSentAt, sentTodayCount: sentTodayCount) else {
            throw AuthError.rateLimited(
                retryAfterSeconds: SMSRateLimit.remainingCooldown(lastSentAt: lastSentAt)
            )
        }
        lastSentAt = Date()
        sentTodayCount += 1
    }

    public func verifyCode(_ code: String, phone: String, isOver14: Bool) async throws -> AuthAccount {
        guard !VerificationCodePolicy.isLockedOut(failedAttempts: failedAttempts) else {
            throw AuthError.lockedOut(minutes: VerificationCodePolicy.lockoutMinutes)
        }
        guard code == Self.acceptedCode else {
            failedAttempts += 1
            throw AuthError.invalidCode
        }
        failedAttempts = 0
        return AuthAccount(uid: UUID().uuidString, bindType: .phone,
                           phoneLastFour: PhoneMask.lastFour(phone), boundAt: Date())
    }

    public func signIn(with method: LoginMethod, isOver14: Bool) async throws -> AuthAccount {
        let bindType: BindType = switch method {
        case .wechat: .wechat
        case .qq:     .qq
        case .apple:  .apple
        case .phone:  .phone
        }
        return AuthAccount(uid: UUID().uuidString, bindType: bindType,
                           phoneLastFour: nil, boundAt: Date())
    }

    public func signOut() async {}

    public func deleteAccount() async throws {}
}
