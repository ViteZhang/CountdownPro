import Foundation

/// 考后日程的来源（需求文档 5.12 / 《V1 剩余页面》6.5）。
///
/// # 口径
/// 「日程数据按省份内置为静态 JSON，随版本更新；用户未填省份时使用全国通用近似日期。」
///
/// # 这里为什么大部分是空的
/// 出分日、填报截止日**逐省不同且逐年公布**，没有一张可以推算出来的表。
/// 编一组"看起来合理"的日期是这个文件最容易犯、也最不能犯的错：
/// 用户会照着它去等，然后在错误的那天打开 App 发现什么都没有 ——
/// 而这个产品除了信任没有别的护城河。
///
/// 所以：**只有确实存在全国口径的项才给值，其余一律 `nil`。**
/// `PostExamEngine` 会整段跳过 `nil` 的阶段，不会因此崩溃，也不会显示占位日期。
///
/// 补上省份数据时改这一个文件即可，`byProvince` 就是那张表的落点。
public enum PostExamScheduleTable {

    /// 一年之内的月日。**不带年份** —— 表是逐省的固定日程，年份由目标日期给。
    ///
    /// 存月日而不是存整个 `Date`：日程表随版本内置，而 `Date` 会把生成它的
    /// 那一年也一起冻进去，明年这张表就悄悄失效了，而且不会有任何地方报错。
    public struct MonthDay: Equatable, Sendable {
        public let month: Int
        public let day: Int
        public init(_ month: Int, _ day: Int) {
            self.month = month
            self.day = day
        }
    }

    /// 一套逐省日程。任何一项为 `nil` 表示该省这一项未知 —— 引擎会整段跳过。
    public struct Entry: Equatable, Sendable {
        public let resultDay: MonthDay?
        public let applicationDeadline: MonthDay?
        public let schoolStart: MonthDay?
        public init(resultDay: MonthDay? = nil,
                    applicationDeadline: MonthDay? = nil,
                    schoolStart: MonthDay? = nil) {
            self.resultDay = resultDay
            self.applicationDeadline = applicationDeadline
            self.schoolStart = schoolStart
        }
    }

    /// 省份日程表。**当前为空** —— 权威数据尚未拿到，见 DOCS/待补文案清单.md。
    ///
    /// key 为「省级行政区名 + 考试类型」（省份写法与 `Exam.province` 一致）。
    static let byProvince: [String: [ExamType: Entry]] = [:]

    /// 取某场考试的考后日程。
    ///
    /// - Parameter province: 用户填的省份。为空或表里没有时回落到全国通用近似值。
    public static func schedule(
        examType: ExamType,
        province: String?,
        targetDate: Date,
        cal: DayCalendar = .current
    ) -> PostExamSchedule {
        let year = cal.year(of: targetDate)
        if let province, let entry = byProvince[province]?[examType] {
            func date(_ md: MonthDay?) -> Date? { md.map { cal.day(year, $0.month, $0.day) } }
            return PostExamSchedule(
                resultDay: date(entry.resultDay),
                applicationDeadline: date(entry.applicationDeadline),
                schoolStart: date(entry.schoolStart)
            )
        }
        return nationalApproximate(examType: examType, targetDate: targetDate, cal: cal)
    }

    /// 全国通用近似值。
    ///
    /// 只写下面两条，因为只有这两条有全国口径：
    /// - **高考出分**：各省集中在 6 月 23–25 日公布，取 6 月 24 日作为近似中值。
    ///   它是"近似"，不是"准确"，所以拿到省份数据后必须被覆盖。
    /// - **开学**：9 月 1 日是全国通行的秋季学期开学日。
    ///
    /// **填报截止日不给近似值。** 各省批次设置差异过大，
    /// 给一个平均数会让某些省的用户以为还有一周，实际昨天就截止了 ——
    /// 这个错误的代价是一整年，不能用"聊胜于无"来换。
    public static func nationalApproximate(
        examType: ExamType,
        targetDate: Date,
        cal: DayCalendar = .current
    ) -> PostExamSchedule {
        let year = cal.year(of: targetDate)
        switch examType {
        case .gaokao:
            return PostExamSchedule(
                resultDay: cal.day(year, 6, 24),
                applicationDeadline: nil,
                schoolStart: cal.day(year, 9, 1)
            )
        case .zhongkao, .kaoyan, .kaogong, .custom:
            // 中考逐市不同；考研 / 考公的出分与后续流程按年度公告，没有稳定的全国口径。
            return .unknown
        }
    }
}
