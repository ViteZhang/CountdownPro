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
    /// 归属考试。
    ///
    /// `nil` = 归属未知（多考试之前写下的记录）。
    /// 删除考试时**不删归属未知的记录** —— 宁可留下一条孤儿，
    /// 也不能误删用户写下的东西。删错的代价是不可逆的，留错只是数据库里多一行。
    public var examID: String?
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        date: Date,
        examID: String? = nil,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.examID = examID
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

    /// 草稿。
    ///
    /// 1000 字写到一半误触返回就全部丢失，对这个功能来说不可接受。
    /// `isDraft == true` 时内容可查看、可修改、可删除；
    /// **封存后置 false 且不可逆** —— 之后只能删除。
    public var isDraft: Bool
    /// 草稿可修改，同步合并需要它。已封存的信不再变动。
    public var updatedAt: Date

    /// 归属考试。`nil` = 归属未知。删除考试时不删归属未知的信 —— 见 `Note.examID`。
    /// 对信件这条规则尤其硬：信是全 App 唯一不可重建的数据。
    public var examID: String?

    public var openTrigger: LetterTrigger {
        get { LetterTrigger(rawValue: openTriggerRaw) ?? .custom }
        set { openTriggerRaw = newValue.rawValue }
    }

    public init(
        id: String = UUID().uuidString,
        sealedContent: Data,
        writtenAt: Date = .now,
        openAt: Date,
        openTrigger: LetterTrigger,
        isDraft: Bool = false,
        examID: String? = nil
    ) {
        self.id = id
        self.sealedContent = sealedContent
        self.examID = examID
        self.writtenAt = writtenAt
        self.openAt = openAt
        self.openTriggerRaw = openTrigger.rawValue
        self.isOpened = false
        self.openedAt = nil
        self.revealedContent = nil
        self.isDraft = isDraft
        self.updatedAt = writtenAt
    }

    /// 封存。**不可逆** —— 这是这个功能的全部价值所在（D-08）。
    public func seal(at date: Date = .now) {
        isDraft = false
        updatedAt = date
    }

    public var access: LetterAccess {
        isDraft ? .draft : .sealed(openAt: openAt)
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

/// 墓碑：本地删掉过什么。
///
/// # 为什么删除要留一行
/// 同步的合并规则只会让数据变多（心里话按 id 取较新，打卡取并集）。
/// 不留墓碑的话，在手机上删掉的一句心里话，会在下一次同步时从服务端原样长回来 ——
/// 而用户已经以为它没了。**一个会自己撤销的删除比没有删除更糟。**
///
/// 只记 id、类型和时间，**不记内容**：它是"这条没了"的证据，不是被删内容的副本。
/// 尤其不能因为想做"回收站"就把正文抄一份进来 —— 那等于删除是假的。
@Model
public final class Deletion {
    @Attribute(.unique) public var key: String
    public var recordID: String
    public var kindRaw: String
    public var deletedAt: Date

    public var kind: ExportSnapshot.DeletionDTO.Kind? {
        ExportSnapshot.DeletionDTO.Kind(rawValue: kindRaw)
    }

    public init(recordID: String, kind: ExportSnapshot.DeletionDTO.Kind, deletedAt: Date = .now) {
        self.key = "\(kind.rawValue):\(recordID)"
        self.recordID = recordID
        self.kindRaw = kind.rawValue
        self.deletedAt = deletedAt
    }
}

public enum ModelSchema {
    public static let all: [any PersistentModel.Type] = [
        Exam.self, CheckIn.self, Note.self, Letter.self, Account.self, AppFlag.self,
        Deletion.self,
    ]
}
#endif
