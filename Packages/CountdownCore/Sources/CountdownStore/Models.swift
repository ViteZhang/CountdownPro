import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 需求文档 4.1 Exam（考试事件）
@Model
public final class Exam {
    @Attribute(.unique) public var id: String
    public var typeRaw: String
    public var title: String
    /// **起始日期，核心字段**，用于计算「已走过」。
    /// 引导第 3 屏的副标题说得很直白：这是这个 App 最重要的一个数字的来源。
    public var startDate: Date
    /// 目标日期（考试首日）
    public var targetDate: Date
    /// 省份，用于考后接力日程（V1 可选填）
    public var province: String?
    /// 是否为首页主展示。V1 支持多考试，但首页只展示这一个。
    public var isPrimary: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public var type: ExamType {
        get { ExamType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        type: ExamType,
        title: String,
        startDate: Date,
        targetDate: Date,
        province: String? = nil,
        isPrimary: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.title = title
        self.startDate = startDate
        self.targetDate = targetDate
        self.province = province
        self.isPrimary = isPrimary
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

/// 需求文档 4.2 CheckIn（打卡记录）。**一天一条。**
///
/// 注意这里**没有** `streak` / `consecutiveDays` 字段，也永远不会有。
/// 设计决策 D-03：连续打卡会精准惩罚最努力的用户（在校禁手机 / 住校生一周才碰一次手机）。
@Model
public final class CheckIn {
    /// 主键：归属日期（当天 00:00）
    @Attribute(.unique) public var date: Date
    public var examID: String
    /// 是否为补签。日历上以浅色区分，但**计入累计天数**。
    public var isBackfill: Bool
    /// 实际操作时间
    public var createdAt: Date

    public init(date: Date, examID: String, isBackfill: Bool, createdAt: Date = .now) {
        self.date = date
        self.examID = examID
        self.isBackfill = isBackfill
        self.createdAt = createdAt
    }
}

/// 需求文档 4.3 Note（心里话）。上限 200 字，完全选填。
@Model
public final class Note {
    @Attribute(.unique) public var id: String
    /// 归属日期
    public var date: Date
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        date: Date,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.content = String(content.prefix(Strings.NoteSheet.maxLength))
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

/// 需求文档 4.4 Letter（未来信件）。
///
/// # 封存后不可查看、不可修改
/// 验收标准要求「封存中的信件内容在**任何界面、任何调试路径**下均不可见」。
/// 明文字段做不到这一点 —— 越狱设备直接 dump SQLite 就能读。
/// 所以正文以密文存储（见 `LetterSealing`），`openAt` 到达前代码路径上不存在解密入口。
///
/// 设计决策 D-08：可以偷看的信就不是信，是备忘录。这个功能的全部价值在于"不可撤销"。
@Model
public final class Letter {
    @Attribute(.unique) public var id: String
    /// **密文。** 不要在任何地方直接展示这个字段。
    public var sealedContent: Data
    public var writtenAt: Date
    public var openAt: Date
    public var openTriggerRaw: String
    public var isOpened: Bool
    public var openedAt: Date?
    /// 已开启后缓存的明文。开启后永久可重读（5.6）。
    public var revealedContent: String?

    public var openTrigger: LetterTrigger {
        get { LetterTrigger(rawValue: openTriggerRaw) ?? .custom }
        set { openTriggerRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        sealedContent: Data,
        writtenAt: Date = .now,
        openAt: Date,
        openTrigger: LetterTrigger
    ) {
        self.id = id
        self.sealedContent = sealedContent
        self.writtenAt = writtenAt
        self.openAt = openAt
        self.openTriggerRaw = openTrigger.rawValue
        self.isOpened = false
        self.openedAt = nil
        self.revealedContent = nil
    }
}

/// 需求文档 4.0 Account（账号，可选）。
///
/// **账号是保险箱，不是入场券**（设计决策 D-10）。
/// 这张表为空是完全正常的状态 —— 未登录时全部功能可用，包括离线。
@Model
public final class Account {
    @Attribute(.unique) public var uid: String
    public var bindTypeRaw: String
    public var boundAt: Date
    public var lastSyncAt: Date?
    /// 手机号**后四位**，仅用于展示。
    /// 需求文档 4.0 / 5.14.3：不在客户端持久化明文，服务端加密存储。
    public var phoneLastFour: String?
    /// 年龄确认结果。**只存布尔值，不存生日** ——
    /// 生日是可识别个人信息，而我们只需要判断是否需要监护人同意（个保法第 31 条）。
    /// 注：需求文档 4.0 的表格漏了这个字段，依 countdown-app-auth.html ACCOUNT/04 补入。
    public var isOver14: Bool

    public var bindType: BindType {
        get { BindType(rawValue: bindTypeRaw) ?? .phone }
        set { bindTypeRaw = newValue.rawValue }
    }

    public init(
        uid: String,
        bindType: BindType,
        boundAt: Date = .now,
        phoneLastFour: String? = nil,
        isOver14: Bool
    ) {
        self.uid = uid
        self.bindTypeRaw = bindType.rawValue
        self.boundAt = boundAt
        self.lastSyncAt = nil
        self.phoneLastFour = phoneLastFour
        self.isOver14 = isOver14
    }
}

/// 一次性标记：引导是否完成、各价值时刻是否已弹、各节点卡是否已弹、小组件引导次数。
///
/// 这些是**状态**，不是可推导值，所以可以存 —— 与「不存储任何可推导的值」不冲突。
@Model
public final class AppFlag {
    @Attribute(.unique) public var key: String
    public var intValue: Int
    public var updatedAt: Date

    public init(key: String, intValue: Int, updatedAt: Date = .now) {
        self.key = key
        self.intValue = intValue
        self.updatedAt = updatedAt
    }
}

public enum ModelSchema {
    public static let all: [any PersistentModel.Type] = [
        Exam.self, CheckIn.self, Note.self, Letter.self, Account.self, AppFlag.self,
    ]
}
#endif
