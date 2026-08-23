import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 小组件的数据来源。
///
/// # 零服务器依赖
/// 需求文档 5.10 的验收标准是「飞行模式下所有小组件正常显示」。
/// 这里读的每一样东西都在 App Group 容器内：
/// - 考试（SwiftData）
/// - 同考人数（UserDefaults 缓存，由主 App 在有网时写入）
///
/// 小组件**从不发起网络请求**，也从不解密信件 —— 它只需要天数。
public struct WidgetDataSource: Sendable {

    public let configuration: StoreConfiguration

    public init(configuration: StoreConfiguration) {
        self.configuration = configuration
    }

    /// 读取渲染所需的快照。返回 `nil` 表示用户还没走完引导（没有主考试），
    /// 此时小组件应显示占位态而不是 0 天。
    ///
    /// # 为什么**不能**加 `@MainActor`
    /// `TimelineProvider` 的三个方法都是 nonisolated 的。一旦这里要求主线程，
    /// Provider 就必须跟着标 `@MainActor`，而那会让整个协议遵循「跨越 actor 边界」——
    /// Swift 6 严格并发下这是编译错误，不是警告。
    ///
    /// 而它本来也不需要主线程：`ModelContainer` / `ModelContext` 都在函数体内
    /// 创建并用完即弃，`Exam` 从不逃逸出这个函数，跨出去的只有 `WidgetSnapshot`
    /// 这个 `Sendable` 值类型。小组件是只读的，也不存在与主 App 争写同一个 store 的问题。
    public func snapshot() -> WidgetSnapshot? {
        guard let exam = primaryExam() else { return nil }
        return WidgetSnapshot(
            examTitle: exam.title,
            startDate: exam.startDate,
            targetDate: exam.targetDate,
            censusCount: cachedCensusCount()
        )
    }

    /// 返回值是 `@Model` 类（非 Sendable），但它只被同一个同步调用栈上的 `snapshot()` 消费，
    /// 不跨任何隔离域，因此不需要隔离标注。
    private func primaryExam() -> Exam? {
        guard let container = try? makeContainer() else { return nil }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Exam>(
            predicate: #Predicate { $0.isPrimary },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func makeContainer() throws -> ModelContainer {
        guard let url = configuration.storeURL else {
            throw StoreError.appGroupUnavailable
        }
        // 小组件只读。写入一律由主 App 负责，避免两个进程同时写同一个 store。
        let config = ModelConfiguration(url: url, allowsSave: false)
        return try ModelContainer(for: Schema(ModelSchema.all), configurations: config)
    }

    /// 同考人数缓存。
    ///
    /// 缓存本身带日期戳：**只有当缓存写于今天时才采用**。
    /// 隔夜的数字拿来说「今天有 X 万人和你一起」就是造假（D-09），
    /// 宁可整块隐藏。
    private func cachedCensusCount(now: Date = .now, cal: DayCalendar = .current) -> Int? {
        guard let defaults = UserDefaults(suiteName: configuration.appGroupIdentifier),
              let payload = defaults.dictionary(forKey: configuration.censusCacheKey),
              let count = payload["count"] as? Int,
              let storedAt = payload["date"] as? Date,
              cal.isSameDay(storedAt, now)
        else { return nil }
        return count
    }
}

public enum StoreError: Error {
    case appGroupUnavailable
}
#endif
