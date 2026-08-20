import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// 动效。设计系统 1.4。
///
/// **必须支持 `prefers-reduced-motion`：直接显示终值，不做过渡。**
/// 判断集中在 `DSMotion.animation(_:reduceMotion:)` 一处，
/// 视图层不再各自 `if reduceMotion`，也就不会漏。
public enum DSMotion {

    /// 统一缓动 `cubic-bezier(.22,.61,.36,1)`
    public static let easeControlPoints: (Double, Double, Double, Double) = (0.22, 0.61, 0.36, 1)

    public struct Duration: Sendable {
        public let seconds: Double
        public init(ms: Double) { self.seconds = ms / 1000 }
    }

    /// 进度环入场填充
    public static let ringFill = Duration(ms: 1100)
    /// 浮层滑入
    public static let sheetSlide = Duration(ms: 340)
    /// 状态切换
    public static let stateChange = Duration(ms: 220)
    /// 选项选中后停留多久再切屏（引导第 1 屏：让选中有反馈）
    public static let optionSelectHold = Duration(ms: 220)

    /// 引导第 4 屏（需求文档 5.1 / ONBOARD-04 时序）
    public enum Onboarding {
        /// 数字从 0 滚动到实际天数
        public static let counterRoll = Duration(ms: 1400)
        /// 进度条起始延迟
        public static let barDelay = Duration(ms: 260)
        /// 进度条填充时长
        public static let barFill = Duration(ms: 1500)
        /// 剩余天数 / 树 / 按钮依次淡入。
        ///
        /// 下面是**绝对时刻**（自第 4 屏出现算起），换算自原型的
        /// 「300ms 起加 .on」+ 各自的 CSS transition-delay（0.9s / 1.4s / 1.9s）。
        /// 顺序不可颠倒：先「已经走过」，再「还剩」，最后才是树与按钮 —— 见 D-14。
        public static let fadeIn = Duration(ms: 600)
        public static let restFadeAt = Duration(ms: 1200)
        public static let treeFadeAt = Duration(ms: 1700)
        public static let footFadeAt = Duration(ms: 2200)
        /// 总时长约 2500ms。**不可跳过 —— 全产品唯一一次允许强制观看。**
        public static let total = Duration(ms: 2500)
    }

    /// 协议未勾选时的抖动（auth ACCOUNT/02）。
    /// **不弹 Alert** —— Alert 打断感强，抖动能明确指向问题所在。
    public enum Shake {
        public static let duration = Duration(ms: 400)
        public static let amplitude: Double = 5
    }

    /// Toast 停留时长
    public static let toast = Duration(ms: 1800)
}

#if canImport(SwiftUI)
extension DSMotion {
    /// 取动画。`reduceMotion` 为真时返回 `nil`，调用方直接赋终值即可。
    ///
    /// 用法：`withAnimation(DSMotion.animation(.ringFill, reduceMotion: reduceMotion)) { ... }`
    public static func animation(_ duration: Duration, reduceMotion: Bool, delay: Duration? = nil) -> Animation? {
        guard !reduceMotion else { return nil }
        let (x1, y1, x2, y2) = easeControlPoints
        let base = Animation.timingCurve(x1, y1, x2, y2, duration: duration.seconds)
        return delay.map { base.delay($0.seconds) } ?? base
    }
}
#endif
