import Foundation

/// 同步合并规则（需求文档 5.14.4）。
///
/// - **本地为真相源**，登录后上行合并
/// - 冲突以**最后写入时间较晚者**为准
/// - 打卡记录取**并集**（不同设备的打卡都算数）
/// - 信件不可修改，故不存在冲突
///
/// 这里全部是纯函数，不碰网络也不碰数据库 —— 合并逻辑出错的代价太高，必须能单测。
public enum MergeRules {

    /// 打卡取并集。同一天两端都有时，保留**更早的 `createdAt`**
    /// （那是真正第一次记下这一天的时刻），且只要有一端是正常打卡就不算补签。
    ///
    /// 为什么不按「后写入者胜」：打卡不是一个可以被"改写"的值，它是一个事实的存在与否。
    /// 并集永远不会让用户的累计天数**变少** —— 这是 D-03「累计只增不减」在同步层的兑现。
    public static func mergeCheckIns(
        local: [ExportSnapshot.CheckInDTO],
        remote: [ExportSnapshot.CheckInDTO]
    ) -> [ExportSnapshot.CheckInDTO] {
        var byDate: [Date: ExportSnapshot.CheckInDTO] = [:]
        for item in local + remote {
            if let existing = byDate[item.date] {
                byDate[item.date] = ExportSnapshot.CheckInDTO(
                    date: item.date,
                    examID: existing.examID,
                    isBackfill: existing.isBackfill && item.isBackfill,
                    createdAt: min(existing.createdAt, item.createdAt)
                )
            } else {
                byDate[item.date] = item
            }
        }
        return byDate.values.sorted { $0.date < $1.date }
    }

    /// 心里话按 id 合并，冲突取 `updatedAt` 较晚者。
    public static func mergeNotes(
        local: [ExportSnapshot.NoteDTO],
        remote: [ExportSnapshot.NoteDTO]
    ) -> [ExportSnapshot.NoteDTO] {
        var byID: [String: ExportSnapshot.NoteDTO] = [:]
        for item in local + remote {
            if let existing = byID[item.id] {
                byID[item.id] = item.updatedAt > existing.updatedAt ? item : existing
            } else {
                byID[item.id] = item
            }
        }
        return byID.values.sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }
    }

    /// 考试按 id 合并，冲突取 `updatedAt` 较晚者。
    ///
    /// 合并后**保证恰好一个 `isPrimary`**：两端各自把不同考试设为主考试时，
    /// 取 `updatedAt` 最新的那一个，其余置否。否则首页会不知道该展示哪一个。
    public static func mergeExams(
        local: [ExportSnapshot.ExamDTO],
        remote: [ExportSnapshot.ExamDTO]
    ) -> [ExportSnapshot.ExamDTO] {
        var byID: [String: ExportSnapshot.ExamDTO] = [:]
        for item in local + remote {
            if let existing = byID[item.id] {
                byID[item.id] = item.updatedAt > existing.updatedAt ? item : existing
            } else {
                byID[item.id] = item
            }
        }
        var merged = byID.values.sorted { $0.createdAt < $1.createdAt }
        guard !merged.isEmpty else { return merged }

        let winner = merged
            .filter(\.isPrimary)
            .max { $0.updatedAt < $1.updatedAt }
            ?? merged[0]

        for i in merged.indices {
            merged[i].isPrimary = (merged[i].id == winner.id)
        }
        return merged
    }

    /// 信件按 id 取并集。
    ///
    /// 两类信的合并规则不同（信件文案表第 0 节）：
    /// - **草稿**参与合并，冲突取 `updatedAt` 较晚者 —— 它还能改，和心里话一样。
    /// - **已封存**的信 append-only：内容不可修改，唯一会变的是「是否已开启」，
    ///   一旦在任一端开启过就是已开启。
    ///
    /// 关键不变量：**封存是不可逆的**。一端已封存、另一端还是草稿时，
    /// 结果必须是已封存 —— 否则同步会把一封已经"托付出去"的信变回可编辑，
    /// D-08 的全部重量就没了。
    public static func mergeLetters(
        local: [ExportSnapshot.LetterDTO],
        remote: [ExportSnapshot.LetterDTO]
    ) -> [ExportSnapshot.LetterDTO] {
        var byID: [String: ExportSnapshot.LetterDTO] = [:]
        for item in local + remote {
            guard let existing = byID[item.id] else {
                byID[item.id] = item
                continue
            }

            // 封存不可逆：任一端已封存即为已封存。
            if existing.isDraft != item.isDraft {
                var sealedSide = existing.isDraft ? item : existing
                let draftSide = existing.isDraft ? existing : item
                if sealedSide.isOpened || draftSide.isOpened {
                    sealedSide.isOpened = true
                    sealedSide.openedAt = [sealedSide.openedAt, draftSide.openedAt].compactMap { $0 }.min()
                    sealedSide.content = sealedSide.content ?? draftSide.content
                }
                byID[item.id] = sealedSide
                continue
            }

            // 两端都是草稿：后写入者胜。
            if existing.isDraft && item.isDraft {
                byID[item.id] = item.updatedAt > existing.updatedAt ? item : existing
                continue
            }

            var merged = existing
            if item.isOpened && !existing.isOpened {
                merged.isOpened = true
                merged.openedAt = item.openedAt
                merged.content = item.content
            } else if item.isOpened && existing.isOpened {
                merged.openedAt = [existing.openedAt, item.openedAt].compactMap { $0 }.min()
                merged.content = existing.content ?? item.content
            }
            merged.sealedContentBase64 = existing.sealedContentBase64 ?? item.sealedContentBase64
            byID[item.id] = merged
        }
        return byID.values.sorted { $0.writtenAt < $1.writtenAt }
    }

    public static func merge(local: ExportSnapshot, remote: ExportSnapshot, now: Date) -> ExportSnapshot {
        ExportSnapshot(
            exportedAt: now,
            exams: mergeExams(local: local.exams, remote: remote.exams),
            checkIns: mergeCheckIns(local: local.checkIns, remote: remote.checkIns),
            notes: mergeNotes(local: local.notes, remote: remote.notes),
            letters: mergeLetters(local: local.letters, remote: remote.letters)
        )
    }
}

private func < (lhs: (Date, Date), rhs: (Date, Date)) -> Bool {
    lhs.0 == rhs.0 ? lhs.1 < rhs.1 : lhs.0 < rhs.0
}
