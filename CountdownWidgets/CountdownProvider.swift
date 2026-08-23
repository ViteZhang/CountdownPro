import WidgetKit
import SwiftUI
import CountdownKit
import CountdownStore

/// 需求文档 5.10：**天数一天只变一次 → 预生成未来 7 天的 entry。**
///
/// 这样小组件完全离线可用、零服务器依赖，也不需要后台唤醒 ——
/// 而小组件是本产品最重要的触达通道：高中生在校瞄一眼锁屏不算"玩手机"。
struct CountdownEntry: TimelineEntry {
    let date: Date
    let data: WidgetEntryData?

    /// 还没走完引导时的占位态。显示占位文案，**不显示 0 天**。
    static func placeholder(at date: Date) -> CountdownEntry {
        CountdownEntry(date: date, data: nil)
    }
}

/// # 为什么这里一个 `@MainActor` 都没有
/// `TimelineProvider` 的三个方法都是 nonisolated 的。给任意一个加上 `@MainActor`，
/// Swift 6 严格并发就会判定「协议遵循跨越主 actor 边界」并报错。
/// 小组件本来也不需要主线程：数据全部来自 App Group 内的只读 store，
/// 读完立刻转成 `Sendable` 的值类型。
struct CountdownProvider: TimelineProvider {

    private let dataSource = WidgetDataSource(configuration: .shared)
    private let cal = DayCalendar.current

    func placeholder(in context: Context) -> CountdownEntry {
        .placeholder(at: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        guard let snapshot = dataSource.snapshot() else {
            completion(Timeline(entries: [.placeholder(at: .now)], policy: .after(cal.adding(days: 1, to: .now))))
            return
        }

        let entries = WidgetTimelineBuilder
            .entries(snapshot: snapshot, from: .now, cal: cal)
            .map { CountdownEntry(date: $0.date, data: $0) }

        // 用 .after 而不是 .atEnd：即使 App 长期没被打开，
        // 系统也会在第 7 天来要新 timeline，天数不会停在旧值上。
        completion(Timeline(
            entries: entries,
            policy: .after(WidgetTimelineBuilder.reloadDate(from: .now, cal: cal))
        ))
    }

    private func currentEntry() -> CountdownEntry {
        guard let snapshot = dataSource.snapshot(),
              let first = WidgetTimelineBuilder.entries(snapshot: snapshot, from: .now, cal: cal).first
        else { return .placeholder(at: .now) }
        return CountdownEntry(date: first.date, data: first)
    }
}
