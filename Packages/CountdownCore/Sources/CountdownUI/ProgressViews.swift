import Foundation
import CountdownKit
import DesignTokens
#if canImport(SwiftUI)
import SwiftUI

/// 进度环（设计系统 1.5 / 需求文档 5.2）。
///
/// # 唯一需要记住的一件事
/// **填充比例 = 已走过比例，不是打卡完成率**（设计决策 D-01）。
///
/// 普通倒计时只给减法，数字每天变小，只有失去感 —— 这是它既制造焦虑又留不住人的
/// 根本原因。同一块屏幕上必须同时存在加法。把填充改成打卡完成率，产品就退化成
/// 一个普通倒计时，其余设计全部失去意义。
public struct DSRingView<Center: View>: View {

    public let progress: Double
    public let palette: Palette
    public let lineWidth: Double
    /// 入场填充动画。`reduceMotion` 为真时直接显示终值。
    public let animated: Bool
    @ViewBuilder public let center: () -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    public init(
        progress: Double,
        palette: Palette,
        lineWidth: Double = DSStroke.ring,
        animated: Bool = true,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.progress = progress
        self.palette = palette
        self.lineWidth = lineWidth
        self.animated = animated
        self.center = center
    }

    public var body: some View {
        ZStack {
            // 轨道用描边色
            Circle()
                .stroke(palette.line.color, lineWidth: lineWidth)

            // 填充用主文字色，端点 round，起点 12 点方向顺时针
            Circle()
                .trim(from: 0, to: shown)
                .stroke(
                    palette.textPrimary.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: DSRing.roundCap ? .round : .butt)
                )
                .rotationEffect(.degrees(DSRing.startAngleDegrees))

            center()
        }
        .onAppear { fill() }
        .onChange(of: progress) { _, _ in fill() }
    }

    private func fill() {
        guard animated, !reduceMotion else {
            shown = progress
            return
        }
        shown = 0
        withAnimation(DSMotion.animation(DSMotion.ringFill, reduceMotion: reduceMotion)) {
            shown = progress
        }
    }
}

extension DSRingView where Center == EmptyView {
    public init(progress: Double, palette: Palette, lineWidth: Double = DSStroke.ring, animated: Bool = true) {
        self.init(progress: progress, palette: palette, lineWidth: lineWidth, animated: animated) {
            EmptyView()
        }
    }
}

/// 进度条。
///
/// 设计决策 D-11：分享卡不放二维码，**「已走过」进度条是无码情况下全部的品牌识别**，
/// 所以它必须出现在每一张分享卡上。首页、小组件同样使用这一个组件，
/// 保证三处的形状完全一致 —— 这才叫"统一符号"。
public struct DSProgressBar: View {

    public let progress: Double
    public let palette: Palette
    public let height: Double

    public init(progress: Double, palette: Palette, height: Double = DSStroke.bar) {
        self.progress = progress
        self.palette = palette
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.line.color)
                Capsule()
                    .fill(palette.textPrimary.color)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// 锁屏用的去色进度条。
///
/// 需求文档 5.10：**锁屏组件会被系统去色**，进度只能靠填充比例表达，
/// 不得依赖颜色区分。所以这里用 `.foregroundStyle` 的层级色而不是 palette，
/// 让系统的染色管线接管。
public struct DSAccessoryBar: View {

    public let progress: Double
    public let height: Double

    public init(progress: Double, height: Double = DSStroke.bar) {
        self.progress = progress
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().foregroundStyle(.tertiary)
                Capsule()
                    .foregroundStyle(.primary)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}
#endif
