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
/// # 七张图，一个色
/// 美术给的是七张实心剪影 PNG（200×200，`lush` 244×200），随 SPM 包分发，
/// App 与小组件读的是同一份。
///
/// 它们**一律以 `.template` 模式渲染**，颜色来自 `palette.tree`。
/// 这不是为了省事：皮肤有四套，每套的树色不同（深空偏冷绿、晨雾偏黄绿、
/// 夜潮偏青、旧纸偏橄榄）。如果按原图上色，换皮肤时树就不跟着变，
/// 或者要为每套皮肤各出七张图 —— 而那样「树的颜色由色板决定」这条规则
/// 就从代码里消失了，只剩下美术流程里的口头约定。
///
/// # 绝对不做
/// 不浇水、不施肥、不因断更枯萎、不因打卡加速生长。
/// 树的生长**只与时间有关，与表现无关** —— 它是同行者，不是奖惩机制（D-05）。
/// 注意这个视图的入参只有 `GrowthStage`，而 `GrowthStage` 只能由 progress 得到，
/// 想让它响应打卡数，必须一路改到 `GrowthStage.stage` 的签名。
public struct TreeView: View {

    public let stage: GrowthStage
    public let color: DSColor

    public init(stage: GrowthStage, color: DSColor) {
        self.stage = stage
        self.color = color
    }

    public var body: some View {
        Image(stage.assetName, bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color.color)
            .accessibilityHidden(true)
    }
}

extension GrowthStage {
    /// 资产文件名。
    ///
    /// 故意不用 `rawValue`：枚举名是领域词汇（`branching` / `leafing` / `budding` /
    /// `blooming`），文件名是美术交付时的命名（`branch` / `leaf` / `bud` / `bloom`）。
    /// 让其中任何一边去将就另一边，都会在下一次交付时重新错位一遍，
    /// 不如把这层映射显式写出来 —— `switch` 是穷尽的，加一个阶段就必须来这里补一行。
    public var assetName: String {
        switch self {
        case .seed:      return "seed"
        case .sprout:    return "sprout"
        case .branching: return "branch"
        case .leafing:   return "leaf"
        case .lush:      return "lush"
        case .budding:   return "bud"
        case .blooming:  return "bloom"
        }
    }
}
#endif
