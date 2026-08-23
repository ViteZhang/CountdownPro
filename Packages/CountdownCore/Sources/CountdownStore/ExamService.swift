import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 考试管理（《V1 剩余页面》第三节）。
///
/// # 这一层承担的三件事，都是"改一个字段会牵动别处"的那种
/// 1. 改考试日期 → 预设节点的信件开启日必须跟着走。
/// 2. 删除考试 → 打卡、心里话、信件要一起删，且**必须先数清楚再告诉用户**。
/// 3. 删除主考试 → 必须有人接手，App 不允许进入"没有考试"的空状态。
///
/// 把它们放在视图里各写一遍，迟早会有一处漏掉 —— 而漏掉的那次是数据丢失。
@MainActor
public struct ExamService {

    public let context: ModelContext
    public let cal: DayCalendar
    private var engine: CountdownEngine { CountdownEngine(cal: cal) }

    public init(context: ModelContext, cal: DayCalendar = .current) {
        self.context = context
        self.cal = cal
    }

    // MARK: - 读

    public func allExams() -> [Exam] {
        (try? context.fetch(FetchDescriptor<Exam>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    public func primaryExam() -> Exam? {
        allExams().first(where: \.isPrimary)
    }

    // MARK: - 主考试

    /// 设为首页展示的那一场。
    ///
    /// 先全部置 false 再置 true，而不是"把旧的那个找出来关掉" ——
    /// 后者在数据已经异常（同步冲突留下两个 primary）时会把异常保留下来。
    public func setPrimary(_ exam: Exam) {
        for e in allExams() where e.isPrimary {
            e.isPrimary = false
            e.updatedAt = .now
        }
        exam.isPrimary = true
        exam.updatedAt = .now
        try? context.save()
    }

    // MARK: - 改日期

    /// 改考试日期的连带结果。
    ///
    /// 界面必须把它逐条念给用户听 —— 「保存成功」这种话在这里等于什么都没说。
    public struct DateChangeEffect: Equatable, Sendable {
        /// 被顺延的**预设节点**信件数（100 天 / 50 天 / 考前一晚 / 出分日）。
        public let lettersShifted: Int
        /// 改完之后的「已走过」。
        public let daysPassed: Int
    }

    /// 改考试日期。
    ///
    /// 「只调整预设节点、不动自定义日期」这条规则**只有一份实现**，
    /// 在 `LetterPresentation.recalculateTriggers` 里（`LetterService` 走的也是它）。
    /// 这里只负责把范围限定到这一场考试，并把结果落库 ——
    /// 规则本身要是有两份，迟早只有一份会被改到，而不一致的那次
    /// 表现为用户的信被挪到了错误的日子。
    @discardableResult
    public func updateTargetDate(
        _ exam: Exam,
        to newTarget: Date,
        today: Date = .now
    ) -> DateChangeEffect {
        let target = cal.startOfDay(newTarget)
        let resultDay = PostExamScheduleTable.schedule(
            examType: exam.type, province: exam.province, targetDate: target, cal: cal
        ).resultDay

        // 已开启的信不动：它已经被读过了，改开启日只会让历史变得不可信。
        let pending = letters(of: exam).filter { !$0.isOpened }
        let changes = LetterPresentation.recalculateTriggers(
            letters: pending.map {
                LetterListItem(id: $0.id, state: .sealed(daysRemaining: 0),
                               writtenAt: $0.writtenAt, openAt: $0.openAt, trigger: $0.openTrigger)
            },
            newTargetDate: target, resultDay: resultDay, cal: cal
        )
        let byID = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0) })
        for change in changes {
            byID[change.letterID]?.openAt = change.newOpenAt
        }
        let shifted = changes.count

        exam.targetDate = target
        exam.updatedAt = .now
        try? context.save()

        let countdown = engine.countdown(
            startDate: exam.startDate, targetDate: target, today: today)
        return DateChangeEffect(lettersShifted: shifted, daysPassed: countdown.daysPassed)
    }

    /// 改起始日期。只影响「已走过」，不牵动信件。
    @discardableResult
    public func updateStartDate(
        _ exam: Exam,
        to newStart: Date,
        today: Date = .now
    ) -> DateChangeEffect {
        exam.startDate = cal.startOfDay(newStart)
        exam.updatedAt = .now
        try? context.save()

        let countdown = engine.countdown(
            startDate: exam.startDate, targetDate: exam.targetDate, today: today)
        return DateChangeEffect(lettersShifted: 0, daysPassed: countdown.daysPassed)
    }

    // MARK: - 删除

    /// 删除一场考试会连带删掉什么。
    ///
    /// **删除对话框必须报出具体数字。** 「相关数据将被删除」是一句让人无法判断的话，
    /// 而这个操作不可撤销。
    public struct DeletionImpact: Equatable, Sendable {
        public let checkInDays: Int
        public let notes: Int
        public let letters: Int
    }

    public func deletionImpact(of exam: Exam) -> DeletionImpact {
        DeletionImpact(
            checkInDays: checkIns(of: exam).count,
            notes: notes(of: exam).count,
            letters: letters(of: exam).count
        )
    }

    public enum DeletionOutcome: Equatable, Sendable {
        /// 删掉了。`handedPrimaryTo` 非空表示主考试易主，需要 Toast 告知。
        case deleted(handedPrimaryTo: String?)
        /// **这是最后一场，不许删。** 给替代方案，不给"确定要删吗"。
        case blockedLastExam
    }

    /// 删除考试。
    ///
    /// 删除唯一一场考试时**阻止操作** —— 不允许 App 进入没有任何考试的空状态。
    /// 那个状态下首页无从渲染，而用户真正想做的多半是改日期，不是重建。
    ///
    /// # 已知缺口：考试与信件的墓碑还没做
    /// 这里只给心里话立墓碑。考试本身和它的信在多设备同步时仍可能被服务端那份带回来。
    /// 没有顺手补上，是因为信的合并规则里"封存不可逆"和"删除"要一起想清楚 ——
    /// 一封已封存的信被删掉之后又同步回来，跟一句心里话回来不是同一个量级的问题。
    /// `DeletionDTO.Kind` 里已经留了 `.exam`，格式不用再改一次。
    @discardableResult
    public func delete(_ exam: Exam) -> DeletionOutcome {
        let all = allExams()
        guard all.count > 1 else { return .blockedLastExam }

        let wasPrimary = exam.isPrimary
        let now = Date.now
        for item in checkIns(of: exam) { context.delete(item) }
        for item in notes(of: exam) {
            // 心里话跟着考试一起删时，墓碑一样要立 —— 合并规则不区分它是
            // 被单独删掉的还是被连带删掉的，少了墓碑照样会长回来。
            context.insert(Deletion(recordID: item.id, kind: .note, deletedAt: now))
            context.delete(item)
        }
        for item in letters(of: exam) { context.delete(item) }
        context.delete(exam)

        var handedTo: String?
        if wasPrimary, let heir = all.first(where: { $0.id != exam.id }) {
            // 剩余考试中创建最早的一场接手（allExams 已按 createdAt 排序）。
            heir.isPrimary = true
            heir.updatedAt = .now
            handedTo = heir.title
        }
        try? context.save()
        return .deleted(handedPrimaryTo: handedTo)
    }

    // MARK: - 归属查询
    //
    // 归属为 nil 的记录**一律不参与**：既不计入删除影响，也不被删除。
    // 宁可在库里留下一条孤儿，也不能误删用户写下的东西 —— 尤其是信。

    private func checkIns(of exam: Exam) -> [CheckIn] {
        let id = exam.id
        return (try? context.fetch(
            FetchDescriptor<CheckIn>(predicate: #Predicate { $0.examID == id })
        )) ?? []
    }

    private func notes(of exam: Exam) -> [Note] {
        let id = exam.id
        return (try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.examID == id })
        )) ?? []
    }

    private func letters(of exam: Exam) -> [Letter] {
        let id = exam.id
        return (try? context.fetch(
            FetchDescriptor<Letter>(predicate: #Predicate { $0.examID == id })
        )) ?? []
    }
}
#endif
