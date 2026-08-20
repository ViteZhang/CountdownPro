import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 一次性标记的读写。
///
/// 这些是**状态**，不是可推导值，所以可以存 —— 与「不存储任何可推导的值」不冲突。
@MainActor
public struct FlagStore {

    public let context: ModelContext
    public let cal: DayCalendar

    public init(context: ModelContext, cal: DayCalendar = .current) {
        self.context = context
        self.cal = cal
    }

    public func flag(_ key: String) -> AppFlag? {
        var descriptor = FetchDescriptor<AppFlag>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    public func isSet(_ key: String) -> Bool {
        flag(key) != nil
    }

    public func set(_ key: String, value: Int = 1, at date: Date = .now) {
        if let existing = flag(key) {
            existing.intValue = value
            existing.updatedAt = date
        } else {
            context.insert(AppFlag(key: key, intValue: value, updatedAt: date))
        }
        try? context.save()
    }

    public func intValue(_ key: String) -> Int {
        flag(key)?.intValue ?? 0
    }

    /// 已经弹过的节点（每个节点一生只弹一次）。
    public func shownMilestoneDays() -> Set<Int> {
        Milestone.cardTriggers.filter { isSet(Milestone(daysRemaining: $0).flagKey) }.reduce(into: []) {
            $0.insert($1)
        }
    }

    /// 今天点过「待会儿」的信。
    ///
    /// 存的是**最后一次推迟的日期**，不是一个永久开关 ——
    /// 规则是「当天不再弹，次日再触发，直到被拆开」。
    public func lettersDeferredToday(letterIDs: [String], today: Date = .now) -> Set<String> {
        var result: Set<String> = []
        for id in letterIDs {
            guard let flag = flag(AppFlagKey.letterDuePromptDeferred(letterID: id)) else { continue }
            if cal.isSameDay(flag.updatedAt, today) { result.insert(id) }
        }
        return result
    }

    public func deferLetterPrompt(letterID: String, at date: Date = .now) {
        set(AppFlagKey.letterDuePromptDeferred(letterID: letterID), value: 1, at: date)
    }
}
#endif
