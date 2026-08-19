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

    public init(
        schemaVersion: Int = ExportSnapshot.currentSchemaVersion,
        exportedAt: Date,
        exams: [ExamDTO],
        checkIns: [CheckInDTO],
        notes: [NoteDTO],
        letters: [LetterDTO]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.exams = exams
        self.checkIns = checkIns
        self.notes = notes
        self.letters = letters
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
        public var content: String
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: String, date: Date, content: String, createdAt: Date, updatedAt: Date) {
            self.id = id; self.date = date; self.content = content
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
        /// 仅当 `isOpened == true` 时有值。
        public var content: String?
        /// 未开启时的密文。
        public var sealedContentBase64: String?

        public init(id: String, writtenAt: Date, openAt: Date, openTrigger: LetterTrigger,
                    isOpened: Bool, openedAt: Date?, content: String?, sealedContentBase64: String?) {
            self.id = id; self.writtenAt = writtenAt; self.openAt = openAt
            self.openTrigger = openTrigger; self.isOpened = isOpened; self.openedAt = openedAt
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
