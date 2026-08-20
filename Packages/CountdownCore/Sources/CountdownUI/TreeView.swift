import Foundation
import CountdownKit
import DesignTokens
#if canImport(SwiftUI)
import SwiftUI

/// 成长物（需求文档 5.4）。
///
/// # 这是全产品唯一的美术资产
/// 也是**唯一允许使用彩色**的元素（设计决策 D-06）。
/// 每多一个彩色元素，树的焦点性就削弱一分。
///
/// # 当前是占位线稿
/// 资料只给了「抽枝」与「开花」两个 SVG，其余 5 个阶段由这里按设计系统 1.5 的
/// 规格（线稿、stroke 1.3–1.8、不填充）推演。**最终美术到位后只需替换本文件**，
/// 所有调用方拿到的都是 `TreeView(stage:)`，不会受影响。
///
/// # 绝对不做
/// 不浇水、不施肥、不因断更枯萎、不因打卡加速生长。
/// 树的生长**只与时间有关，与表现无关** —— 它是同行者，不是奖惩机制（D-05）。
/// 注意这个视图的入参只有 `GrowthStage`，而 `GrowthStage` 只能由 progress 得到，
/// 想让它响应打卡数，必须一路改到 `GrowthStage.stage` 的签名。
public struct TreeView: View {

    public let stage: GrowthStage
    public let color: DSColor
    public let lineWidth: Double
    /// 实心。设计系统 1.5：线稿是常态，**唯一例外是归零卡上的树用实心** ——
    /// 终局才允许"完成"的实感。
    public let filled: Bool

    public init(
        stage: GrowthStage,
        color: DSColor,
        lineWidth: Double = DSStroke.treeMax,
        filled: Bool = false
    ) {
        self.stage = stage
        self.color = color
        self.lineWidth = lineWidth
        self.filled = filled
    }

    /// 设计稿坐标系。所有 path 在 40×46 里绘制，再按容器等比缩放。
    private static let designSize = CGSize(width: 40, height: 46)

    public var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / Self.designSize.width,
                            geo.size.height / Self.designSize.height)
            ZStack {
                strokePaths(scale: scale)
                if filled { filledPaths(scale: scale) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(Self.designSize.width / Self.designSize.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: - 线稿

    @ViewBuilder
    private func strokePaths(scale: Double) -> some View {
        let w = lineWidth * scale
        ZStack {
            // 主干：随阶段由短到长
            Path { p in
                p.move(to: pt(20, 44, scale))
                p.addLine(to: pt(20, trunkTop, scale))
            }
            .stroke(color.color, style: StrokeStyle(lineWidth: w, lineCap: .round))

            // 土壤线：只有种子阶段画
            if stage == .seed {
                Path { p in
                    p.move(to: pt(10, 40, scale))
                    p.addLine(to: pt(30, 40, scale))
                }
                .stroke(color.color, style: StrokeStyle(lineWidth: w * 0.85, lineCap: .round))
            }

            // 枝
            ForEach(Array(branches.enumerated()), id: \.offset) { _, branch in
                Path { p in
                    p.move(to: pt(branch.0, branch.1, scale))
                    p.addLine(to: pt(branch.2, branch.3, scale))
                }
                .stroke(color.color, style: StrokeStyle(lineWidth: w * 0.78, lineCap: .round))
            }

            // 冠 / 叶 / 苞：线稿圆
            if !filled {
                ForEach(Array(canopy.enumerated()), id: \.offset) { _, c in
                    Circle()
                        .stroke(color.color, lineWidth: w * 0.78)
                        .frame(width: c.2 * 2 * scale, height: c.2 * 2 * scale)
                        .position(pt(c.0, c.1, scale))
                }
            }
        }
    }

    /// 实心版本（归零卡专用）
    @ViewBuilder
    private func filledPaths(scale: Double) -> some View {
        ForEach(Array(canopy.enumerated()), id: \.offset) { _, c in
            Circle()
                .fill(color.color)
                .frame(width: c.2 * 2 * scale, height: c.2 * 2 * scale)
                .position(pt(c.0, c.1, scale))
        }
    }

    private func pt(_ x: Double, _ y: Double, _ scale: Double) -> CGPoint {
        CGPoint(x: x * scale, y: y * scale)
    }

    // MARK: - 七个阶段的形态

    /// 主干顶端的 y（越小越高）
    private var trunkTop: Double {
        switch stage {
        case .seed:      return 41     // 几乎没有，只是土里一点
        case .sprout:    return 34
        case .branching: return 19
        case .leafing:   return 17
        case .lush:      return 16
        case .budding:   return 16
        case .blooming:  return 17
        }
    }

    /// 枝：(x1, y1, x2, y2)
    private var branches: [(Double, Double, Double, Double)] {
        switch stage {
        case .seed:
            return []
        case .sprout:
            // 两片子叶
            return [(20, 36, 13, 32), (20, 36, 27, 32)]
        case .branching:
            return [(20, 31, 11, 24), (20, 26, 29, 19)]
        case .leafing:
            return [(20, 32, 11, 25), (20, 27, 29, 20)]
        case .lush, .budding:
            return [(20, 33, 10, 26), (20, 28, 30, 21), (20, 24, 14, 19)]
        case .blooming:
            return [(20, 33, 10, 26), (20, 28, 30, 21)]
        }
    }

    /// 冠：(cx, cy, r)
    private var canopy: [(Double, Double, Double)] {
        switch stage {
        case .seed:
            // 土壤中的种子
            return [(20, 43, 1.8)]
        case .sprout:
            // 两片子叶用小圆示意
            return [(12, 31, 3), (28, 31, 3)]
        case .branching:
            // 资料给定形态：细枝 + 少量叶
            return [(20, 14, 8), (10, 21, 5), (30, 17, 5.5)]
        case .leafing:
            // 树冠成形
            return [(20, 13, 9), (10, 21, 5.5), (30, 17, 6)]
        case .lush:
            // 饱满树冠
            return [(20, 12, 10), (9, 20, 6.5), (31, 16, 7)]
        case .budding:
            // 繁茂 + 花苞（小圆点）
            return [(20, 12, 10), (9, 20, 6.5), (31, 16, 7),
                    (14, 8, 1.6), (26, 9, 1.6), (20, 4, 1.6)]
        case .blooming:
            // 资料给定形态：满树花
            return [(20, 12, 9), (9, 20, 6), (31, 17, 6.5)]
        }
    }
}
#endif
