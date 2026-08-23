import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 打卡与心里话（需求文档 5.3）。
///
/// # 这一层刻意不提供的东西
/// 没有 `currentStreak`、没有 `daysSinceLastCheckIn`、没有 `missedDays`。
/// 设计决策 D-03：连续打卡会精准惩罚最努力的用户 ——
/// 大量高中生在校禁用手机，住校生一周才碰一次手机。
/// **不实现比"实现了但不显示"安全得多**：后者迟早会被某次迭代接到界面上。
@MainActor
public struct CheckInService {

    public let context: ModelContext
    public let cal: DayCalendar
    private var engine: CountdownEngine { CountdownEngine(cal: cal) }

    public init(context: ModelContext, cal: DayCalendar = .current) {
        self.context = context
        self.cal = cal
    }

    // MARK: - 打卡

    public enum CheckInResult: Equatable, Sendable {
        case recorded
        /// 今天已经记下了。不是错误 —— 按钮不该报错，只该温和地说一句。
        case alreadyRecorded
        /// 超出 14 天补签窗口（D-04）
        case outsideBackfillWindow
    }

    /// 「今天也在」。**点击即完成，零门槛，不需要任何确认**（5.3）。
    @discardableResult
    public func checkInToday(examID: String, today: Date = .now) -> CheckInResult {
        let day = cal.startOfDay(today)
        guard !hasCheckIn(on: day) else { return .alreadyRecorded }
        context.insert(CheckIn(date: day, examID: examID, isBackfill: false, createdAt: today))
        try? context.save()
        return .recorded
    }

    /// 补签。窗口 14 天（D-04）：无限补签会让「累计 128 天」失去意义，
    /// 而 14 天能覆盖住校生的月假周期。这是"有意义"和"不惩罚"之间的取值。
    ///
    /// **不设次数限制，不需要「补签卡」之类的道具。**
    @discardableResult
    public func backfill(date: Date, examID: String, today: Date = .now) -> CheckInResult {
        let day = cal.startOfDay(date)
        guard engine.canBackfill(date: day, today: today) else { return .outsideBackfillWindow }
        guard !hasCheckIn(on: day) else { return .alreadyRecorded }
        context.insert(CheckIn(date: day, examID: examID, isBackfill: true, createdAt: today))
        try? context.save()
        return .recorded
    }

    public func hasCheckIn(on date: Date) -> Bool {
        let day = cal.startOfDay(date)
        var descriptor = FetchDescriptor<CheckIn>(predicate: #Predicate { $0.date == day })
        descriptor.fetchLimit = 1
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    /// 累计打卡天数。**补签计入**（5.3）。
    public func totalCheckIns() -> Int {
        (try? context.fetchCount(FetchDescriptor<CheckIn>())) ?? 0
    }

    // MARK: - 心里话

    /// 心里话完全选填，上限 200 字。
    /// 已打卡后按钮不可重复点击，但**心里话可继续追加/编辑当天内容**（5.3）。
    @discardableResult
    /// - Parameter examID: 归属考试。删除考试时要靠它把心里话一并带走 ——
    ///   也要靠它保证**不带走**别的考试的记录。
    public func addNote(
        _ content: String,
        examID: String? = nil,
        on date: Date = .now
    ) -> Note? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let note = Note(date: cal.startOfDay(date), examID: examID,
                        content: trimmed, createdAt: date)
        context.insert(note)
        try? context.save()
        return note
    }

    public func totalNotes() -> Int {
        (try? context.fetchCount(FetchDescriptor<Note>())) ?? 0
    }
}
#endif
