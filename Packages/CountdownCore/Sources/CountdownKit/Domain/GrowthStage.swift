import Foundation

/// 需求文档 5.4 成长物阶段。
///
/// **由 progress 映射，不由打卡数映射**（设计决策 D-05：树只与时间有关，与表现无关）。
/// 这个类型的构造入口**故意只接受 progress**：想加入「浇水 / 断更枯萎」必须先改这个签名，
/// 改不动就是防线。
public enum GrowthStage: String, CaseIterable, Sendable {
    case seed        // 0–15%    种子
    case sprout      // 15–30%   破土
    case branching   // 30–50%   抽枝
    case leafing     // 50–70%   成叶
    case lush        // 70–90%   繁茂
    case budding     // 90–100%  结蕾
    case blooming    // 考试当天  开花

    /// 阶段区间按**左闭右开**处理（需求文档 5.4 表格未定义边界值归属，此处为实现约定）。
    ///
    /// - Parameters:
    ///   - progress: 已走过比例，调用方需已 clamp 到 0...1。
    ///   - isExamDay: 是否为考试当天。5.4 规定 `= 100%（考试当天）` 才开花，
    ///     所以「刚好走满但还没到考试日」不算开花。
    public static func stage(progress: Double, isExamDay: Bool) -> GrowthStage {
        if isExamDay || progress >= 1.0 { return .blooming }
        switch progress {
        case ..<0.15:  return .seed
        case ..<0.30:  return .sprout
        case ..<0.50:  return .branching
        case ..<0.70:  return .leafing
        case ..<0.90:  return .lush
        default:       return .budding
        }
    }

    /// 副文案。经确认：**只展示阶段名，不带序号。**
    public var displayName: String {
        switch self {
        case .seed:      return "种子"
        case .sprout:    return "破土"
        case .branching: return "抽枝"
        case .leafing:   return "成叶"
        case .lush:      return "繁茂"
        case .budding:   return "结蕾"
        case .blooming:  return "开花"
        }
    }
}
