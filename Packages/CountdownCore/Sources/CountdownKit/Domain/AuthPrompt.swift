import Foundation

/// 登录引导的价值时刻（需求文档 5.14.1）。
///
/// # 账号是保险箱，不是入场券
/// 设计决策 D-10：账号本身是必要的（跨设备同步、换机不丢数据、客服定位、考后变现），
/// 但**注册墙**才是杀手 —— 它出现在用户还没获得任何价值的那一刻。
///
/// 所以两者拆开：账号做，登录时机延后到用户已经攒下东西之后。
public enum AuthPromptTrigger: String, CaseIterable, Sendable, Identifiable {
    /// 写下第一封未来信件后 —— **最高优先级**。
    ///
    /// 它是唯一带有"不可重建"属性的数据：打卡断了可以补，心里话丢了还能再写，
    /// 但一封写给未来的信没了就是没了。用情感驱动绑定，转化率远高于功能驱动。
    case firstLetter
    /// 累计打卡满 7 天
    case sevenDays
    /// 主动使用「数据导出」
    case export
    /// 考后接力开启时
    case postExam

    public var id: String { rawValue }

    /// 优先级。数字越小越优先。
    public var priority: Int {
        switch self {
        case .firstLetter: return 0
        case .sevenDays:   return 1
        case .export:      return 1
        case .postExam:    return 2
        }
    }

    public var flagKey: String { AppFlagKey.AuthPrompt(rawValue: rawValue)?.flagKey ?? rawValue }
}

public enum AuthPromptResolver {

    /// 该不该弹登录引导，弹哪一个。
    ///
    /// # 三条铁律
    /// 1. **已登录不弹。** 账号已经有了，再弹就是骚扰。
    /// 2. **每个触发点一生只弹一次。** 关闭后不再重复。
    /// 3. **首次启动引导中永远不弹。** 这一条由代码结构保证 ——
    ///    引导流程不 import 任何 Auth 模块，压根拿不到这个函数。
    ///
    /// - Parameter satisfied: 此刻**条件已满足**的触发点。
    /// - Parameter shownFlags: 已经弹过的触发点。
    public static func resolve(
        isSignedIn: Bool,
        satisfied: Set<AuthPromptTrigger>,
        shownFlags: Set<AuthPromptTrigger>
    ) -> AuthPromptTrigger? {
        guard !isSignedIn else { return nil }
        return satisfied
            .subtracting(shownFlags)
            .min { ($0.priority, $0.rawValue) < ($1.priority, $1.rawValue) }
    }

    /// 由当前数据算出哪些触发点的条件已满足。
    public static func satisfiedTriggers(
        sealedLetterCount: Int,
        totalCheckIns: Int,
        didRequestExport: Bool,
        isAfterExam: Bool
    ) -> Set<AuthPromptTrigger> {
        var result: Set<AuthPromptTrigger> = []
        if sealedLetterCount >= 1 { result.insert(.firstLetter) }
        if totalCheckIns >= AppFlagKey.sevenDaysThreshold { result.insert(.sevenDays) }
        if didRequestExport { result.insert(.export) }
        if isAfterExam { result.insert(.postExam) }
        return result
    }
}

private func < (lhs: (Int, String), rhs: (Int, String)) -> Bool {
    lhs.0 == rhs.0 ? lhs.1 < rhs.1 : lhs.0 < rhs.0
}
