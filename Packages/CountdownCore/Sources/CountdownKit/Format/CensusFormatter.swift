import Foundation

/// 同考人数（需求文档 5.7 / 设计决策 D-09）。
///
/// **诚实性是强约束。** 这个模块除了信任没有别的护城河，数字一旦被发现造假，
/// 产品建立的全部信任瞬间归零。所以：
/// - < 10,000 → 整块隐藏，**不是**显示「不足 1 万」，也不是取整放大
/// - 拉不到 / 无网络 → 同样整块隐藏，不显示错误态、不显示骨架屏
/// 两条路径**故意走同一个返回值 `nil`**，让调用方无法区分、也就无从为「失败」单独做 UI。
public enum CensusFormatter {

    /// 展示阈值。低于此值整块隐藏。见 D-09。
    public static let visibilityThreshold = 10_000

    /// - Returns: 可展示的「万」字符串（如 `"41.2"`），或 `nil` 表示**整块隐藏**。
    public static func display(count: Int?) -> String? {
        guard let count, count >= visibilityThreshold else { return nil }
        let wan = Double(count) / 10_000
        return String(format: "%.1f", wan)
    }
}
