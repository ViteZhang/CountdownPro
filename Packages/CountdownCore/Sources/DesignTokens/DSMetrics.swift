import Foundation

/// 尺寸与间距。设计系统 1.3。
///
/// 视图层禁止出现字面量尺寸 —— 需要一个新值就在这里加一个具名 token，
/// 这样后续视觉精修只需要改这一层。
public enum DSRadius {
    /// 卡片
    public static let card: Double = 16
    /// 浮层（顶部两角）
    public static let sheet: Double = 26
    /// 主要按钮
    public static let button: Double = 16
    /// 胶囊按钮（小）
    public static let pillSmall: Double = 20
    /// 胶囊按钮（大）
    public static let pillLarge: Double = 26
    /// 分段控件外框
    public static let segmentTrack: Double = 11
    /// 分段控件选中块
    public static let segmentThumb: Double = 9
    /// 输入框 / 提示条
    public static let field: Double = 14
    /// 协议勾选框
    public static let checkbox: Double = 4
}

public enum DSSpacing {
    /// 页面左右边距（首页 / 记录 / 信箱）
    public static let pageHorizontal: Double = 22
    /// 页面左右边距（引导 / 账号，设计系统给的是 22–26 区间）
    public static let pageHorizontalWide: Double = 26
    /// 卡片间距
    public static let cardGap: Double = 10
    public static let cardGapWide: Double = 11

    public static let xs: Double = 4
    public static let sm: Double = 8
    public static let md: Double = 14
    public static let lg: Double = 22
    public static let xl: Double = 34
}

public enum DSStroke {
    /// 描边统一 0.5pt（设计系统 1.3）
    public static let hairline: Double = 0.5

    /// 进度环 stroke-width（设计系统 1.5）
    public static let ring: Double = 9
    /// 进度条高度：首页 / 分享卡
    public static let bar: Double = 2.5
    /// 进度条高度：小组件小号
    public static let barWidget: Double = 5

    // 树曾经是代码画的线稿，需要 stroke 宽度（设计系统 1.5 规定 1.3–1.8）。
    // 美术交付实心剪影 PNG 后这两个值不再有落点，一并删掉 ——
    // 留着会让下一个人以为树还是画出来的，去调它，然后发现调了没反应。
}

/// 进度环绘制规则（设计系统 1.5 / 需求文档 5.2）。
public enum DSRing {
    /// 端点 round
    public static let roundCap = true
    /// 起点 12 点方向顺时针 → SwiftUI 里需要 rotate −90°
    public static let startAngleDegrees: Double = -90
    /// 轨道用描边色，填充用主文字色
    /// **填充比例 = 已走过比例**（设计决策 D-01），不是打卡完成率。
    public static let fillIsPassedRatio = true
}

/// 具名字号。
///
/// 视图层禁止出现字面量字号 —— 一律引用这里的常量，
/// 后续视觉精修只改这一处。字重由字号自动推导（见 `DSFontWeight`），所以这里只需给尺寸。
public enum DSType {
    // 首页
    /// 进度环中心的剩余天数。
    ///
    /// 需求文档 5.2 给的区间是 `56–66`，原型用了 `68` —— 取区间内的 64，以需求文档为准。
    public static let ringNumber: Double = 64
    /// 环内副标题「天后见分晓」/ 分割线下「你已走过 X 天」
    public static let ringCaption: Double = 13
    /// 顶部栏考试名
    public static let navTitle: Double = 16
    /// 顶部栏日期
    public static let navSubtitle: Double = 12
    /// 数据卡大数字
    public static let statNumber: Double = 23
    public static let statLabel: Double = 11

    // 通用
    public static let screenTitle: Double = 20
    public static let question: Double = 23
    public static let bodyLarge: Double = 15
    public static let body: Double = 14
    public static let caption: Double = 12
    public static let captionSmall: Double = 11
    public static let footnote: Double = 10.5

    // 引导 / 结果
    public static let onboardingResult: Double = 82
    public static let onboardingDate: Double = 40

    // 分享卡（导出为 1080×1440 时整体等比放大）
    public static let cardBigNumber: Double = 60
    public static let cardMilestoneNumber: Double = 96
    public static let cardQuote: Double = 16
    public static let cardWatermark: Double = 9

    // 用户写的内容（衬线）
    public static let userNote: Double = 15
    public static let userLetter: Double = 16
}
