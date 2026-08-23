import Foundation

/// 数据导出（需求文档 5.13）与同步上行共用的 DTO。
///
/// **即使有账号，用户也应能把自己的记录带走。** 导出入口在账号页与设置页都必须提供。
///
/// 注意：导出**不含**任何可推导的值（累计天数、进度、成长阶段），
/// 与「不存储任何可推导的值」同一条原则 —— 导出的是事实，不是结论。
public struct ExportSnapshot: Codable, Equatable, Sendable {

    /// 结构版本。同步与跨版本导入靠它判断兼容性。
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var exams: [ExamDTO]
    public var checkIns: [CheckInDTO]
    public var notes: [NoteDTO]
    public var letters: [LetterDTO]
    /// 墓碑：本地删掉过什么。见 `DeletionDTO`。
    public var deletions: [DeletionDTO]

    public init(
        schemaVersion: Int = ExportSnapshot.currentSchemaVersion,
        exportedAt: Date,
        exams: [ExamDTO],
        checkIns: [CheckInDTO],
        notes: [NoteDTO],
        letters: [LetterDTO],
        deletions: [DeletionDTO] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.exams = exams
        self.checkIns = checkIns
        self.notes = notes
        self.letters = letters
        self.deletions = deletions
    }

    /// 手写 `init(from:)` 只为了一件事：`deletions` 缺失时补成空数组。
    ///
    /// 合成的 Codable 会因为缺 key 直接抛错，于是所有**这个字段出现之前**导出的文件
    /// 都会变成不可导入 —— 而"导出文件要跨版本读"正是这份格式存在的理由。
    /// 加字段不改 `schemaVersion`：旧版本读到多出来的 key 会忽略，双向都兼容。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try c.decode(Date.self, forKey: .exportedAt)
        exams = try c.decode([ExamDTO].self, forKey: .exams)
        checkIns = try c.decode([CheckInDTO].self, forKey: .checkIns)
        notes = try c.decode([NoteDTO].self, forKey: .notes)
        letters = try c.decode([LetterDTO].self, forKey: .letters)
        deletions = try c.decodeIfPresent([DeletionDTO].self, forKey: .deletions) ?? []
    }

    /// 一条删除记录。
    ///
    /// # 为什么删除也要同步
    /// 合并规则对心里话取的是"按 id 合并、后写入者胜"，对打卡取的是并集 ——
    /// 两条规则都**只会让数据变多**。没有墓碑的话，本地删掉一句心里话，
    /// 下一次同步服务端那份又原样长回来，而用户已经以为它没了。
    /// 一个会自己撤销的删除比没有删除更糟。
    ///
    /// 墓碑只记 id 和时间，**不记内容** —— 它是"这条没了"的证据，
    /// 不是被删内容的副本。
    ///
    /// 注：V1 不清理墓碑。它每条只有几十字节，而清理需要知道"所有设备都同步过了"，
    /// 那是一个比它要解决的问题大得多的机制。
    public struct DeletionDTO: Codable, Equatable, Sendable, Identifiable {
        public enum Kind: String, Codable, Equatable, Sendable {
            case note
            /// 考试删除目前**不写墓碑**（见 `ExamService.delete` 的注释）。
            /// 这个 case 先占好位置，免得将来补上时要动一次数据格式。
            case exam
        }
        public var id: String
        public var kind: Kind
        public var deletedAt: Date

        public init(id: String, kind: Kind, deletedAt: Date) {
            self.id = id; self.kind = kind; self.deletedAt = deletedAt
        }
    }

    public struct ExamDTO: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var type: ExamType
        public var title: String
        public var startDate: Date
        public var targetDate: Date
        public var province: String?
        public var isPrimary: Bool
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: String, type: ExamType, title: String, startDate: Date, targetDate: Date,
                    province: String?, isPrimary: Bool, createdAt: Date, updatedAt: Date) {
            self.id = id; self.type = type; self.title = title
            self.startDate = startDate; self.targetDate = targetDate
            self.province = province; self.isPrimary = isPrimary
            self.createdAt = createdAt; self.updatedAt = updatedAt
        }
    }

    public struct CheckInDTO: Codable, Equatable, Sendable {
        public var date: Date
        public var examID: String
        public var isBackfill: Bool
        public var createdAt: Date

        public init(date: Date, examID: String, isBackfill: Bool, createdAt: Date) {
            self.date = date; self.examID = examID
            self.isBackfill = isBackfill; self.createdAt = createdAt
        }
    }

    public struct NoteDTO: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var date: Date
        /// 归属考试。`nil` = 归属未知（多考试之前的记录）。
        public var examID: String?
        public var content: String
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: String, date: Date, examID: String? = nil, content: String,
                    createdAt: Date, updatedAt: Date) {
            self.id = id; self.date = date; self.examID = examID; self.content = content
            self.createdAt = createdAt; self.updatedAt = updatedAt
        }
    }

    /// 信件。**未开启的信导出的是密文**，导出文件同样不能成为偷看的旁路（D-08）。
    public struct LetterDTO: Codable, Equatable, Sendable, Identifiable {
        public var id: String
        public var writtenAt: Date
        public var openAt: Date
        public var openTrigger: LetterTrigger
        public var isOpened: Bool
        public var openedAt: Date?
        /// 草稿。草稿参与同步合并；已封存的信 append-only。
        public var isDraft: Bool
        public var updatedAt: Date
        /// 归属考试。`nil` = 归属未知。
        public var examID: String?
        /// 仅当 `isOpened == true` 时有值。
        public var content: String?
        /// 未开启时的密文。草稿同样以密文导出。
        public var sealedContentBase64: String?

        public init(id: String, writtenAt: Date, openAt: Date, openTrigger: LetterTrigger,
                    isOpened: Bool, openedAt: Date?, isDraft: Bool = false, updatedAt: Date,
                    examID: String? = nil,
                    content: String?, sealedContentBase64: String?) {
            self.id = id; self.writtenAt = writtenAt; self.openAt = openAt
            self.openTrigger = openTrigger; self.isOpened = isOpened; self.openedAt = openedAt
            self.isDraft = isDraft; self.updatedAt = updatedAt; self.examID = examID
            self.content = content; self.sealedContentBase64 = sealedContentBase64
        }
    }

    public static func jsonEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    public static func jsonDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
