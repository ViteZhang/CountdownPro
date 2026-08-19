import Foundation

/// 需求文档 4.1 Exam.type
public enum ExamType: String, Codable, CaseIterable, Sendable {
    case gaokao
    case zhongkao
    case kaoyan
    case kaogong
    case custom
}

/// 需求文档 4.4 Letter.open_trigger
public enum LetterTrigger: String, Codable, CaseIterable, Sendable {
    /// 还剩 100 天
    case d100
    /// 还剩 50 天
    case d50
    /// 考前一晚 = target_date − 1 天
    case nightBefore = "night_before"
    /// 出分日。依赖考后日程表（需求文档 5.12），无日程数据时不可选。
    case resultDay = "result_day"
    case custom
}

/// 需求文档 4.0 Account.bind_type
public enum BindType: String, Codable, CaseIterable, Sendable {
    case phone
    case wechat
    case qq
    case apple
}
