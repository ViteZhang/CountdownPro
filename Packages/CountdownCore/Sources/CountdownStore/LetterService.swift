import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 未来信件（需求文档 5.6 / 《未来信件 · 完整文案表》）。
///
/// # 这一层守着 D-08
/// 封存后不可查看、不可修改。所有读取正文的路径都必须经过 `LetterVault`，
/// 而 `LetterVault.reveal` 要求调用方交出 `LetterAccess` 凭证 ——
/// `.sealed` 这个 case 必然携带开启日，也就必然被校验。
///
/// 这里唯一构造 `.sealed(...)` 的地方是 `Letter.access`，它直接读 `letter.openAt`，
/// 没有任何可以传入"假日期"的入口。
@MainActor
public struct LetterService {

    public let context: ModelContext
    public let vault: LetterVault
    public let cal: DayCalendar

    public init(context: ModelContext, vault: LetterVault, cal: DayCalendar = .current) {
        self.context = context
        self.vault = vault
        self.cal = cal
    }

    // MARK: - 草稿

    /// 存草稿。草稿可查看、可修改、可删除。
    @discardableResult
    public func saveDraft(
        _ content: String,
        existing: Letter? = nil,
        openAt: Date? = nil,
        trigger: LetterTrigger = .custom,
        examID: String? = nil,
        now: Date = .now
    ) throws -> Letter {
        let sealed = try vault.seal(content)
        if let existing {
            existing.sealedContent = sealed
            existing.updatedAt = now
            if let openAt { existing.openAt = openAt }
            existing.openTrigger = trigger
            try? context.save()
            return existing
        }
        let letter = Letter(
            sealedContent: sealed,
            writtenAt: now,
            openAt: openAt ?? cal.adding(days: 1, to: now),
            openTrigger: trigger,
            isDraft: true,
            examID: examID
        )
        context.insert(letter)
        try? context.save()
        return letter
    }

    /// 读草稿正文。走 `letter.access`，草稿态无日期闸门。
    public func draftContent(of letter: Letter) throws -> String {
        try vault.reveal(sealed: letter.sealedContent, access: letter.access, today: .now)
    }

    // MARK: - 封存

    /// 封起来。**不可逆。**
    ///
    /// 这一步之后正文就只有到期才能读到了 —— 这是这个功能的全部重量所在。
    public func seal(_ letter: Letter, openAt: Date, trigger: LetterTrigger, now: Date = .now) {
        letter.openAt = cal.startOfDay(openAt)
        letter.openTrigger = trigger
        letter.seal(at: now)
        try? context.save()
    }

    // MARK: - 开启

    /// 拆信。到期日之前调用会抛错 —— 这不是防御性编程，这是产品语义。
    @discardableResult
    public func open(_ letter: Letter, now: Date = .now) throws -> String {
        let content = try vault.reveal(sealed: letter.sealedContent, access: letter.access, today: now)
        letter.isOpened = true
        letter.openedAt = now
        // 开启后永久可重读（5.6）
        letter.revealedContent = content
        letter.updatedAt = now
        try? context.save()
        return content
    }

    // MARK: - 删除

    /// 删除。**不做撤销** —— 撤销会削弱"删除是认真的"这件事，
    /// 而这个功能的全部价值就建立在不可逆之上。
    public func delete(_ letter: Letter) {
        context.delete(letter)
        try? context.save()
    }

    // MARK: - 考试日期变动后的节点重算

    /// 用户改了考试日期 → 预设节点信件的开启日跟着重算，自定义日期的信不动。
    ///
    /// 预设节点是"相对考试日的某一天"，考试日变了它当然要跟着变；
    /// 自定义日期是用户亲手指定的一个绝对日子（生日、纪念日），
    /// 我们没有任何理由去动它 —— 那是替用户改他自己的决定。
    ///
    /// 已开启的信也不动：它已经被读过了，改开启日只会让历史变得不可信。
    ///
    /// - Parameter examID: 限定在这一场考试的信。`nil` = 不限定（单考试时代的调用方）。
    ///   归属为 `nil` 的信**不参与** —— 不知道它属于哪场考试，就不该因为某场考试改期而动它。
    /// - Returns: 实际调整了几封，供提示文案使用。
    @discardableResult
    public func recalculateTriggers(
        newTargetDate: Date,
        resultDay: Date? = nil,
        examID: String? = nil
    ) -> Int {
        let descriptor = FetchDescriptor<Letter>(predicate: #Predicate { !$0.isOpened })
        guard var letters = try? context.fetch(descriptor) else { return 0 }
        if let examID { letters = letters.filter { $0.examID == examID } }

        let items = letters.map {
            LetterListItem(id: $0.id,
                           state: .sealed(daysRemaining: 0),
                           writtenAt: $0.writtenAt,
                           openAt: $0.openAt,
                           trigger: $0.openTrigger)
        }
        let changes = LetterPresentation.recalculateTriggers(
            letters: items, newTargetDate: newTargetDate, resultDay: resultDay, cal: cal
        )
        let byID = Dictionary(uniqueKeysWithValues: letters.map { ($0.id, $0) })
        for change in changes {
            byID[change.letterID]?.openAt = change.newOpenAt
        }
        if !changes.isEmpty { try? context.save() }
        return changes.count
    }
}
#endif
