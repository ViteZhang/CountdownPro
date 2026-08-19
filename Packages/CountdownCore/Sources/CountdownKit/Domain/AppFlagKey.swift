import Foundation

/// 一次性标记的 key。集中定义，避免字符串散落。
public enum AppFlagKey {
    /// 首次启动引导是否完成
    public static let onboardingCompleted = "onboarding_completed"
    /// 首次打开 App 的日期（用于 5.10「第 2 天提示添加小组件」）
    public static let firstLaunchDate = "first_launch_date"
    /// 小组件引导已提示次数。**最多 2 次**（5.10）。
    public static let widgetPromptCount = "widget_prompt_count"
    public static let widgetPromptMaxCount = 2
    /// 通知权限是否已请求过。时机为**第一次打卡之后**，绝不在首次启动时请求（5.11）。
    public static let notificationPermissionAsked = "notification_permission_asked"

    /// 登录价值时刻触发点。**每个触发点一生只弹一次**，关闭后不再重复。
    public enum AuthPrompt: String, CaseIterable, Sendable {
        /// 写完第一封未来信件后 —— **最高优先级**。
        /// 它是唯一「不可重建」的数据：打卡断了能补，心里话丢了能再写，
        /// 一封写给未来的信没了就是没了。情感驱动的绑定转化率远高于功能驱动。
        case firstLetter
        /// 累计打卡满 7 天
        case sevenDays
        /// 主动使用「数据导出」
        case export
        /// 考后接力开启时
        case postExam

        public var flagKey: String { "auth_prompt_shown_\(rawValue)" }
    }

    public static let sevenDaysThreshold = 7
}
