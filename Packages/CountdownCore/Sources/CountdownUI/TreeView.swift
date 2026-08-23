import Foundation
import CountdownKit
import DesignTokens
#if canImport(SwiftUI)
import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias TreePlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias TreePlatformImage = NSImage
#endif

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
        // 取不到图时给一个占位方框，**不是 EmptyView**：
        // 空视图会让首页看起来"本来就没有树"，正是这个 bug 最初活下来的原因。
        if let image = TreeAsset.image(for: stage) {
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color.color)
                .accessibilityHidden(true)
        } else {
            Rectangle()
                .strokeBorder(color.color, lineWidth: DSStroke.hairline)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityHidden(true)
        }
    }
}

/// 树的图片从包资源里读出来。
///
/// # 为什么不用 `Image(name, bundle: .module)`
/// 按名字查找会依次问资产目录和散装文件，任何一环没命中都**静默返回一张空图** ——
/// 不崩、不报错、不打日志，界面上只是少了一棵树。这个失败模式害我们查过一次，
/// 所以这里改成按确定路径读文件：命中不了就是命中不了，DEBUG 下直接断言。
///
/// 路径的确定性来自 `Package.swift` 里的 `.copy("Resources/Tree")`。
/// 仍然保留一次无子目录的兜底 —— Xcode 集成 SPM 时的拷贝行为和命令行不完全一致，
/// 而这里多试一次的代价只有一次 `url(forResource:)`。
enum TreeAsset {

    /// 小组件一条 timeline 要渲染 7 个 entry，首页每次重绘也会走这里，
    /// 每次都解一遍 PNG 是浪费。视图 body 在主 actor 上，缓存跟着它走。
    @MainActor private static var cache: [GrowthStage: Image] = [:]

    @MainActor static func image(for stage: GrowthStage) -> Image? {
        if let hit = cache[stage] { return hit }
        guard let made = load(stage.assetName) else {
            assertionFailure("树的资产读不出来：Tree/\(stage.assetName).png 不在 CountdownUI 的资源包里")
            return nil
        }
        cache[stage] = made
        return made
    }

    private static func load(_ name: String) -> Image? {
        let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Tree")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        guard let url,
              let data = try? Data(contentsOf: url),
              let platform = TreePlatformImage(data: data)
        else { return nil }
        #if canImport(UIKit)
        return Image(uiImage: platform)
        #elseif canImport(AppKit)
        return Image(nsImage: platform)
        #else
        return nil
        #endif
    }
}

extension GrowthStage {
    /// 资产文件名。
    ///
    /// 故意不用 `rawValue`：枚举名是领域词汇（`branching` / `leafing` / `budding` /
    /// `blooming`），文件名是美术交付时的命名（`branch` / `leaf` / `bud` / `bloom`）。
    /// 让其中任何一边去将就另一边，都会在下一次交付时重新错位一遍，
    /// 不如把这层映射显式写出来 —— `switch` 是穷尽的，加一个阶段就必须来这里补一行。
    ///
    /// `Scripts/check-tree-assets.sh` 拿这份映射去核对文件是否真的存在。
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
