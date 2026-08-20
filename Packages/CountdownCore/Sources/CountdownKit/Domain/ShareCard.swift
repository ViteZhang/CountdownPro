import Foundation

/// 三类分享卡（需求文档 5.8.1）。
///
/// # 这是 V1 最重要的模块，投入应等同于核心功能
/// 无二维码的前提下（D-11），分享卡是零预算下唯一的获客渠道。
public enum ShareCardKind: String, CaseIterable, Sendable {
    /// 系统触发：还剩 100 / 99（进入两位数）/ 50 / 30 / 10 / 1 天
    case milestone
    /// 用户写完心里话后弹出入口；记录页长按
    case note
    /// 考试当天
    case zero
}

/// 一张分享卡上的全部内容。
///
/// 做成值类型的理由：卡片渲染必须能在 500ms 内完成（5.8 验收标准），
/// 所以渲染时不能再去查数据库或算日期 —— 这里已经全部算好。
public struct ShareCardContent: Equatable, Sendable {
    public let kind: ShareCardKind

    /// 顶部小标签。节点卡是「距离高考」，心里话卡是「第 129 天」，归零卡是日期。
    public let label: String
    /// 大数字（节点卡 / 归零卡）。心里话卡没有。
    public let bigNumber: String?
    /// 大数字后面的单位或短语。
    public let bigUnit: String?
    /// 心里话原文。只有心里话卡有。
    public let quote: String?

    /// **「已走过」进度条的填充比例。**
    ///
    /// 设计决策 D-11：进度条必须出现在**每一张**卡上 ——
    /// 没有二维码的情况下，它是全部的品牌识别。所以这个字段不是可选的。
    public let passedProgress: Double

    /// 进度条下方的脚注。每张卡都必须点出「已走过」多少天。
    public let footnotes: [String]

    /// 归零卡专属：开花的树用实心（设计系统 1.5 的唯一例外）。
    public let showsBloomingTree: Bool

    /// 水印。仅一行淡色产品名 —— 不含 Logo、不含二维码、不含下载引导。
    public let watermark: String
}

public struct ShareCardBuilder: Sendable {

    public let cal: DayCalendar
    public init(cal: DayCalendar = .current) { self.cal = cal }

    private var display: DateDisplay { DateDisplay(cal: cal) }

    /// 节点卡。
    public func milestone(examTitle: String, countdown: Countdown) -> ShareCardContent {
        ShareCardContent(
            kind: .milestone,
            label: Strings.ShareCard.distanceTo(examTitle),
            bigNumber: "\(max(countdown.daysRemaining, 0))",
            bigUnit: Strings.Common.day,
            quote: nil,
            passedProgress: countdown.progress,
            footnotes: [Strings.ShareCard.passed(countdown.daysPassed)],
            showsBloomingTree: false,
            watermark: Strings.ShareCard.watermark
        )
    }

    /// 心里话卡。
    ///
    /// - Parameter censusDisplay: 同考人数。`nil` 时**整行不出现** ——
    ///   与首页、小组件同一条规则（D-09）。分享出去的图更不能带假数字。
    public func note(
        content: String,
        date: Date,
        nthCheckInDay: Int,
        countdown: Countdown,
        censusDisplay: String?
    ) -> ShareCardContent {
        var footnotes = [
            Strings.ShareCard.noteMeta(date: display.dotted(date), remaining: max(countdown.daysRemaining, 0))
        ]
        if let censusDisplay {
            footnotes.append(Strings.ShareCard.togetherOnCard(censusDisplay))
        }
        return ShareCardContent(
            kind: .note,
            label: Strings.ShareCard.nthDay(nthCheckInDay),
            bigNumber: nil,
            bigUnit: nil,
            quote: content,
            passedProgress: countdown.progress,
            footnotes: footnotes,
            showsBloomingTree: false,
            watermark: Strings.ShareCard.watermark
        )
    }

    /// 归零卡。
    ///
    /// 文案是「807 天，走完了」—— 肯定过程，不肯定结果。
    /// 需求文档 5.12 强约束：**不使用「恭喜」。**
    ///
    /// 注：原型上的日期是 `2027.06.08`，比 target(`06.07`) 晚一天，来源未确认；
    /// 这里用**考试当天**，因为 5.12 规定归零卡在考试当日 18:00 后触发。
    public func zero(
        examDate: Date,
        countdown: Countdown,
        totalCheckIns: Int,
        totalNotes: Int
    ) -> ShareCardContent {
        ShareCardContent(
            kind: .zero,
            label: display.dotted(examDate),
            bigNumber: "\(countdown.totalDays)",
            bigUnit: Strings.ShareCard.walkedItAll,
            quote: nil,
            passedProgress: 1.0,
            footnotes: [Strings.ShareCard.zeroStats(days: totalCheckIns, notes: totalNotes)],
            showsBloomingTree: true,
            watermark: Strings.ShareCard.watermark
        )
    }

    /// 导出尺寸。3:4 竖版，1080×1440，适配朋友圈与 QQ 空间。
    public static let exportSize = (width: 1080.0, height: 1440.0)
    /// 设计稿尺寸。导出时按 `exportScale` 放大。
    public static let designSize = (width: 270.0, height: 360.0)
    public static var exportScale: Double { exportSize.width / designSize.width }
}
