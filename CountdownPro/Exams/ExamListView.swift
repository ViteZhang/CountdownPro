import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 考试管理页（《V1 剩余页面》3.1）。
///
/// # 首页只显示一场，长按可以换
/// V1 支持多考试，但首页永远只有一个主角。同时显示两场倒计时，
/// 两个数字会互相削弱 —— 这个产品的全部张力来自"一个数字"。
struct ExamListView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme

    @Query(sort: \Exam.createdAt) private var exams: [Exam]

    @State private var editing: Exam?
    @State private var adding = false
    @State private var pendingDeletion: Exam?
    @State private var toast: String?

    private let cal = DayCalendar.current
    private var palette: Palette { theme.palette }
    private var service: ExamService { ExamService(context: context, cal: cal) }
    private var engine: CountdownEngine { CountdownEngine(cal: cal) }

    var body: some View {
        SettingsPage(title: Strings.Exams.listTitle, palette: palette) {
            VStack(spacing: DSSpacing.cardGap) {
                ForEach(exams) { exam in
                    examRow(exam)
                }
            }

            Button { adding = true } label: {
                Text(Strings.Exams.add)
                    .dsFont(DSFont.body(DSType.bodyLarge))
                    .foregroundStyle(palette.textPrimary.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSSpacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                            .dsHairline(palette.line)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, DSSpacing.xs)

            Text(Strings.Exams.listFootnote)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(palette.textTertiary.color)
                .padding(.top, DSSpacing.xs)
                .padding(.horizontal, DSSpacing.xs)
        }
        .dsToast($toast, palette: palette)
        .sheet(item: $editing) { exam in
            NavigationStack { ExamEditView(exam: exam) { toast = $0 } }
        }
        .sheet(isPresented: $adding) {
            NavigationStack { ExamEditView(exam: nil) { toast = $0 } }
        }
        .confirmationDialog(
            Strings.Exams.deleteTitle,
            isPresented: Binding(get: { pendingDeletion != nil },
                                 set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { exam in
            Button(Strings.Exams.deleteConfirm, role: .destructive) { delete(exam) }
            Button(Strings.Exams.deleteCancel, role: .cancel) { pendingDeletion = nil }
        } message: { exam in
            // 必须报出具体数字。「相关数据将被删除」是一句让人无法判断的话，
            // 而这个操作不可撤销。
            let impact = service.deletionImpact(of: exam)
            Text(Strings.Exams.deleteBody(checkInDays: impact.checkInDays,
                                          notes: impact.notes,
                                          letters: impact.letters))
        }
    }

    // MARK: -

    private func examRow(_ exam: Exam) -> some View {
        let c = engine.countdown(startDate: exam.startDate,
                                 targetDate: exam.targetDate, today: .now)
        return Button {
            editing = exam
        } label: {
            HStack(spacing: DSSpacing.sm) {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    HStack(spacing: DSSpacing.sm) {
                        Text(exam.title)
                            .dsFont(DSFont.body(DSType.bodyLarge))
                            .foregroundStyle(palette.textPrimary.color)
                        if exam.isPrimary {
                            Text(Strings.Exams.primaryBadge)
                                .dsFont(DSFont.caption(DSType.footnote))
                                .foregroundStyle(palette.textSecondary.color)
                                .padding(.horizontal, DSSpacing.sm)
                                .padding(.vertical, DSSpacing.xs / 2)
                                .background(palette.surfaceRaised.color, in: Capsule())
                        }
                    }
                    Text(Strings.Exams.rowCaption(remaining: max(c.daysRemaining, 0),
                                                  passed: c.daysPassed))
                        .dsFont(DSFont.caption(DSType.caption))
                        .foregroundStyle(palette.textSecondary.color)
                }
                Spacer(minLength: DSSpacing.sm)
                Text("›")
                    .dsFont(DSFont.body(DSType.bodyLarge))
                    .foregroundStyle(palette.textTertiary.color)
            }
            .padding(.horizontal, DSSpacing.md + 2)
            .padding(.vertical, DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface.color,
                        in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // 长按换主考试（3.1 底部说明）。删除也放在这里 ——
        // 不做左滑删除：这一页每一行背后是几百天的记录，误触的代价太大。
        .contextMenu {
            if !exam.isPrimary {
                Button(Strings.Exams.setPrimary) { service.setPrimary(exam) }
            }
            Button(Strings.Exams.deleteConfirm, role: .destructive) {
                if exams.count > 1 {
                    pendingDeletion = exam
                } else {
                    // 最后一场直接拦下并给替代方案，连确认框都不弹 ——
                    // 弹了也只能告诉他不行。
                    toast = Strings.Exams.deleteLastBlocked
                }
            }
        }
    }

    private func delete(_ exam: Exam) {
        pendingDeletion = nil
        switch service.delete(exam) {
        case .blockedLastExam:
            toast = Strings.Exams.deleteLastBlocked
        case .deleted(let handedTo):
            if let handedTo { toast = Strings.Exams.primaryHandedOver(to: handedTo) }
        }
    }
}
