import Foundation

/// 考后接力（需求文档 5.12 / 《V1 剩余页面》第六节）。
///
/// # 为什么考完了还要留住用户
/// 考试当天不是终点，是等待期的开始 —— 出分、填报、开学，中间是三段
/// 比备考更难熬的空白。这个 App 唯一的角色是陪着，所以它得陪到底。
///
/// # 三条不可动摇的约束（5.12 / 6.3）
/// 1. **不提供任何成绩输入、查询、对比功能。** 一个也不行。
/// 2. **文案保持中性，不使用「恭喜」** —— 你不知道屏幕那头是什么情绪。
/// 3. 出分日不推送任何营销或第三方内容。
///
/// 兜底校验法：把任何一句放进「一个刚查完分、没考好的学生正看着屏幕」的场景里读一遍。

/// 考后的四个阶段。
public enum PostExamPhase: String, Equatable, Sendable, CaseIterable {
    /// 考试当天。中心大字是「今天」而不是 0 —— 0 会被读成"结束了"。
    case examDay
    /// 等出分
    case awaitingResult
    /// 填报
    case application
    /// 等开学
    case awaitingSchool
}

/// 考后日程。
///
/// # 这是**内置数据**，不是用户数据
/// 5.12 / 6.5：日程按省份内置为静态 JSON，随版本更新。
/// 所以它不落在 `Exam` 上，也不进导出快照 —— 导出的是用户的事实，
/// 不是我们这一版恰好内置了哪张表。
///
/// 任何一项为 `nil` 表示该段日程未知，此时**跳过那一段**，而不是编一个日期。
public struct PostExamSchedule: Equatable, Sendable {
    public let resultDay: Date?
    public let applicationDeadline: Date?
    public let schoolStart: Date?

    public init(resultDay: Date? = nil, applicationDeadline: Date? = nil, schoolStart: Date? = nil) {
        self.resultDay = resultDay
        self.applicationDeadline = applicationDeadline
        self.schoolStart = schoolStart
    }

    /// 什么都不知道。考后只显示冻结的累计天数。
    public static let unknown = PostExamSchedule()
}

/// 考后某一天的完整状态。和 `Countdown` 一样是现算的值快照，不落库。
public struct PostExamState: Equatable, Sendable {
    public let phase: PostExamPhase
    /// 距本阶段终点还有几天。考试当天为 0。
    public let daysRemaining: Int
    /// **本阶段**已走过的比例，0...1。
    ///
    /// 每次切换阶段环重新从 0 填充（6.1）：这是新的一段路，不是旧进度的延续。
    /// 把它算成"从考试日到开学日的总进度"会让等出分那两周的环几乎不动 ——
    /// 而那恰好是最需要看见"在走"的两周。
    public let progress: Double
}

public struct PostExamEngine: Sendable {

    public let cal: DayCalendar

    public init(cal: DayCalendar = .current) { self.cal = cal }

    /// 计算考后状态。返回 `nil` 表示还没到考试日，或考后日程已全部走完。
    ///
    /// 各阶段区间取**左开右闭**：出分日当天仍属「等出分」且 `daysRemaining == 0`，
    /// 对应 6.2 的「今天出分。」—— 出分日不是等待的结束，是等待的最后一天。
    public func state(
        targetDate: Date,
        schedule: PostExamSchedule,
        today: Date
    ) -> PostExamState? {
        let target = cal.startOfDay(targetDate)
        let now = cal.startOfDay(today)

        if now < target { return nil }
        if now == target {
            return PostExamState(phase: .examDay, daysRemaining: 0, progress: 1)
        }

        // 依次尝试三段。每段的起点是上一段的终点 —— 缺失的那段整体跳过，
        // 起点顺延给下一段，不会在时间轴上留出一个无人认领的空洞。
        var segmentStart = target
        let segments: [(PostExamPhase, Date?)] = [
            (.awaitingResult, schedule.resultDay),
            (.application, schedule.applicationDeadline),
            (.awaitingSchool, schedule.schoolStart),
        ]

        for (phase, end) in segments {
            guard let end = end.map(cal.startOfDay) else { continue }
            guard end > segmentStart else { continue }   // 日程本身不自洽时跳过，不 crash
            if now <= end {
                let span = cal.days(from: segmentStart, to: end)
                let walked = cal.days(from: segmentStart, to: now)
                return PostExamState(
                    phase: phase,
                    daysRemaining: cal.days(from: now, to: end),
                    progress: span > 0 ? min(max(Double(walked) / Double(span), 0), 1) : 1
                )
            }
            segmentStart = end
        }

        return nil
    }

    // MARK: - 心理支持入口的位置

    /// 出分日**前 3 天至后 14 天**，心理支持入口上移至设置页第一项。
    ///
    /// 这是全 App 唯一一处主动调整心理支持入口位置的规则。
    /// 它仍然不加红点、不推送、不弹窗 —— 只是把它挪到手边。
    /// 「常驻但不显眼、可找到」这句话里，这段时间要加强的是"找得到"，不是"显眼"。
    public static let mentalHealthLeadDays = 3
    public static let mentalHealthTrailDays = 14

    public func mentalHealthGoesFirst(resultDay: Date?, today: Date) -> Bool {
        guard let resultDay else { return false }
        let d = cal.days(from: cal.startOfDay(today), to: cal.startOfDay(resultDay))
        return d <= Self.mentalHealthLeadDays && d >= -Self.mentalHealthTrailDays
    }
}

// MARK: - 阶段切换提示

/// 阶段切换时的一次性提示（6.2）。每个阶段一生只提示一次。
public enum PostExamNotice: Equatable, Sendable {
    case examEnded(daysToResult: Int)
    case resultDay
    case applicationOpened(daysLeft: Int)
    case schoolCountdownStarted(days: Int)

    public var text: String {
        switch self {
        case .examEnded(let d):             return Strings.PostExam.examEnded(daysToResult: d)
        case .resultDay:                    return Strings.PostExam.resultDay
        case .applicationOpened(let d):     return Strings.PostExam.applicationOpened(daysLeft: d)
        case .schoolCountdownStarted(let d): return Strings.PostExam.schoolCountdownStarted(days: d)
        }
    }
}

extension PostExamState {
    /// 本阶段对应的一次性提示。
    ///
    /// 「出分日当天」和「等出分期间」是同一个 phase，靠 `daysRemaining == 0` 分开 ——
    /// 所以它需要一个和阶段本身不同的 flag key，否则出分日那条会被
    /// 考完次日那条给顶掉，用户永远看不到「今天出分。」。
    public var notice: PostExamNotice? {
        switch phase {
        case .examDay:
            return nil
        case .awaitingResult:
            return daysRemaining == 0 ? .resultDay : .examEnded(daysToResult: daysRemaining)
        case .application:
            return .applicationOpened(daysLeft: daysRemaining)
        case .awaitingSchool:
            return .schoolCountdownStarted(days: daysRemaining)
        }
    }

    /// 提示的一次性标记。同一条提示只出现一次。
    public var noticeFlagKey: String? {
        switch phase {
        case .examDay:        return nil
        case .awaitingResult: return daysRemaining == 0
                                 ? "post_exam_notice_result_day"
                                 : "post_exam_notice_exam_ended"
        case .application:    return "post_exam_notice_application"
        case .awaitingSchool: return "post_exam_notice_school"
        }
    }

    /// 副文案。考试当天由 `Strings.PostExam.examDayCaption` 单独承担（要带累计天数）。
    public var caption: String? {
        switch phase {
        case .examDay:        return nil
        case .awaitingResult: return Strings.PostExam.awaitingResultCaption
        case .application:    return Strings.PostExam.applicationCaption
        case .awaitingSchool: return Strings.PostExam.awaitingSchoolCaption
        }
    }
}
