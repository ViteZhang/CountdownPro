import Foundation

/// 信件正文的加解密。具体算法由平台层提供（见 CountdownStore.KeychainLetterCipher）。
public protocol LetterCipher: Sendable {
    func seal(_ plaintext: String) throws -> Data
    func reveal(_ ciphertext: Data) throws -> String
}

/// 解密凭证。
///
/// 这个类型存在的唯一理由，是让"想读一封已封存的信"必须先说出它的开启日 ——
/// 从而不可能在调用处忘记做日期校验（D-08）。
public enum LetterAccess: Equatable, Sendable {
    /// 草稿：可查看、可修改。
    case draft
    /// 已封存：到期才可见。
    case sealed(openAt: Date)
}

public enum LetterVaultError: Error, Equatable {
    /// 开启日未到。**这是唯一正确的失败方式** —— 不返回部分内容、不返回长度、不返回摘要。
    case notYetOpenable(daysRemaining: Int)
    case contentTooLong(limit: Int)
    case cipherFailure
}

/// 封存信件的唯一出入口。
///
/// # 为什么需要这一层
/// 需求文档 5.6 的验收标准是：「封存中的信件内容在**任何界面、任何调试路径**下均不可见」。
/// 只在 UI 层不展示是达不到的 —— 明文存在 SQLite 里，dump 一下就能读，
/// 导出的 JSON 发到电脑上打开也能读。
///
/// 所以正文以密文落库，而**解密只有 `reveal` 这一个入口，它第一行就校验开启日**。
/// 想偷看必须先改这个函数，改不动就是防线。
///
/// 设计决策 D-08：可以偷看的信就不是信，是备忘录。这个功能的全部价值在于"不可撤销"。
public struct LetterVault: Sendable {

    public let cipher: LetterCipher
    public let cal: DayCalendar

    public init(cipher: LetterCipher, cal: DayCalendar = .current) {
        self.cipher = cipher
        self.cal = cal
    }

    /// 封存。上限 1000 字（需求文档 4.4）。
    public func seal(_ content: String) throws -> Data {
        guard content.count <= Strings.Letters.maxLength else {
            throw LetterVaultError.contentTooLong(limit: Strings.Letters.maxLength)
        }
        do {
            return try cipher.seal(content)
        } catch {
            throw LetterVaultError.cipherFailure
        }
    }

    /// **全产品唯一的解密入口。**
    ///
    /// 草稿与已封存的信走同一个入口，但访问凭证不同：
    /// `.sealed` 这个 case **必须**携带开启日，构造它就等于接受日期校验。
    /// 没有"绕过校验"的第三种调用方式。
    ///
    /// - Throws: `LetterVaultError.notYetOpenable` 当封存信的 `today < openAt`。
    public func reveal(sealed: Data, access: LetterAccess, today: Date) throws -> String {
        switch access {
        case .draft:
            // 草稿可查看、可修改、可删除（信件文案表第 0 节）。
            // 它还没被"封起来"，重量尚未建立。
            break
        case .sealed(let openAt):
            let remaining = cal.days(from: today, to: openAt)
            guard remaining <= 0 else {
                throw LetterVaultError.notYetOpenable(daysRemaining: remaining)
            }
        }
        do {
            return try cipher.reveal(sealed)
        } catch {
            throw LetterVaultError.cipherFailure
        }
    }

    /// 信箱列表用：这封信现在能不能开。**不碰密文。**
    public func isOpenable(openAt: Date, today: Date) -> Bool {
        cal.days(from: today, to: openAt) <= 0
    }

    /// 信箱列表用：封存中还剩几天。**不碰密文。**
    public func daysUntilOpen(openAt: Date, today: Date) -> Int {
        max(cal.days(from: today, to: openAt), 0)
    }
}
