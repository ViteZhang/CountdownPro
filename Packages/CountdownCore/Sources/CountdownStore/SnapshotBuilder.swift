import Foundation
import CountdownKit

#if canImport(SwiftData)
import SwiftData

/// 把本地库读成 `ExportSnapshot`。数据导出（5.13）与同步上行共用这一条路径。
///
/// # 为什么导出和同步用同一个构造器
/// 两者只要有一处不一致，就会出现「导出文件里有的东西同步没带上」这类问题，
/// 而这类问题用户发现时数据已经丢了。共用一个入口，差异就不可能存在。
///
/// # 导出的是事实，不是结论
/// 快照里没有累计天数、没有进度、没有成长阶段 —— 它们全部可从打卡与日期推导。
/// 这跟「不存储任何可推导的值」是同一条原则的延伸：
/// 导出文件是要跨版本、跨实现读的，写进结论就等于把当前版本的算法冻进了别人的存档。
@MainActor
public struct SnapshotBuilder {

    public let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func build(now: Date = .now) -> ExportSnapshot {
        ExportSnapshot(
            exportedAt: now,
            exams: exams(),
            checkIns: checkIns(),
            notes: notes(),
            letters: letters(),
            deletions: deletions()
        )
    }

    /// 导出为 JSON 数据。
    public func exportJSON(now: Date = .now) throws -> Data {
        try ExportSnapshot.jsonEncoder().encode(build(now: now))
    }

    /// 导出文件名。带日期，便于用户区分多次导出。
    public static func fileName(now: Date = .now, cal: DayCalendar = .current) -> String {
        let y = cal.year(of: now), m = cal.month(of: now), d = cal.dayOfMonth(of: now)
        return String(format: "countdown-export-%04d%02d%02d.json", y, m, d)
    }

    // MARK: - 各表

    private func exams() -> [ExportSnapshot.ExamDTO] {
        let items = (try? context.fetch(
            FetchDescriptor<Exam>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []
        return items.map {
            ExportSnapshot.ExamDTO(
                id: $0.id, type: $0.type, title: $0.title,
                startDate: $0.startDate, targetDate: $0.targetDate,
                province: $0.province, isPrimary: $0.isPrimary,
                createdAt: $0.createdAt, updatedAt: $0.updatedAt
            )
        }
    }

    private func checkIns() -> [ExportSnapshot.CheckInDTO] {
        let items = (try? context.fetch(
            FetchDescriptor<CheckIn>(sortBy: [SortDescriptor(\.date)])
        )) ?? []
        return items.map {
            ExportSnapshot.CheckInDTO(
                date: $0.date, examID: $0.examID,
                isBackfill: $0.isBackfill, createdAt: $0.createdAt
            )
        }
    }

    private func notes() -> [ExportSnapshot.NoteDTO] {
        let items = (try? context.fetch(
            FetchDescriptor<Note>(sortBy: [SortDescriptor(\.date)])
        )) ?? []
        return items.map {
            ExportSnapshot.NoteDTO(
                id: $0.id, date: $0.date, examID: $0.examID, content: $0.content,
                createdAt: $0.createdAt, updatedAt: $0.updatedAt
            )
        }
    }

    /// 信件。
    ///
    /// **未开启的信导出的是密文** —— 导出文件不能成为偷看的旁路（D-08）。
    /// 一个能通过"导出再用文本编辑器打开"读到封存内容的实现，
    /// 等于把这个功能的全部价值撤销掉，而且用户不会知道。
    private func letters() -> [ExportSnapshot.LetterDTO] {
        let items = (try? context.fetch(
            FetchDescriptor<Letter>(sortBy: [SortDescriptor(\.writtenAt)])
        )) ?? []
        return items.map { letter in
            ExportSnapshot.LetterDTO(
                id: letter.id,
                writtenAt: letter.writtenAt,
                openAt: letter.openAt,
                openTrigger: letter.openTrigger,
                isOpened: letter.isOpened,
                openedAt: letter.openedAt,
                isDraft: letter.isDraft,
                updatedAt: letter.updatedAt,
                examID: letter.examID,
                // 只有已开启的信才带明文 —— 草稿也不带。
                content: letter.isOpened ? letter.revealedContent : nil,
                sealedContentBase64: letter.sealedContent.base64EncodedString()
            )
        }
    }

    /// 墓碑。同步要靠它才能把删除也传出去（见 `MergeRules.mergeNotes`）。
    ///
    /// 导出文件里同样带着 —— 导出和同步共用这一个构造器，
    /// 一份"记录已经删了、导出文件里却还在"的存档，会在导入时把它们全带回来。
    private func deletions() -> [ExportSnapshot.DeletionDTO] {
        let items = (try? context.fetch(
            FetchDescriptor<Deletion>(sortBy: [SortDescriptor(\.deletedAt)])
        )) ?? []
        return items.compactMap { item in
            guard let kind = item.kind else { return nil }
            return ExportSnapshot.DeletionDTO(id: item.recordID, kind: kind, deletedAt: item.deletedAt)
        }
    }
}
#endif
