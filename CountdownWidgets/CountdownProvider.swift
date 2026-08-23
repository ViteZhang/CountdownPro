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

/// # 隔离形态（Swift 6 + WidgetKit SDK 事实）
/// 协议 `TimelineProvider` 整体是非隔离的（只有 completion 是 @Sendable），
/// 全部依赖（WidgetDataSource / DayCalendar / WidgetEntryData）也都是 Sendable
/// 值类型。因此 provider 保持 nonisolated 是既合法又零开销的形态 ——
/// 曾尝试给类型或 witness 标 @MainActor，均触发 "crosses into main
/// actor-isolated code" 硬错误，不要再走那条路。
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
