import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 考试编辑页（《V1 剩余页面》3.2 / 3.3）。
///
/// # 改日期必须把连带结果念出来
/// 改考试日期会同时牵动：进度、天数、以及所有**预设节点**信件的开启日。
/// 保存之后只说一句「保存成功」，等于让用户自己去发现那三封信被挪了 ——
/// 而信是这个 App 里唯一不可重建的东西，用户对它的任何意外都会转成不信任。
///
/// 「保存成功」本身也在文案禁区里（信件文案表第 9 节）。
struct ExamEditView: View {

    /// `nil` = 新增。
    let exam: Exam?
    /// 保存后把连带结果交给上一层用 Toast 念出来。
    let onSaved: (String?) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var title = ""
    @State private var type: ExamType = .gaokao
    @State private var targetDate = Date()
    @State private var startDate = Date()
    @State private var province = ""
    @State private var makePrimary = false
    @State private var loaded = false

    private let cal = DayCalendar.current
    private var palette: Palette { theme.palette }
    private var service: ExamService { ExamService(context: context, cal: cal) }
    private var defaults: DefaultDates { DefaultDates(cal: cal) }

    /// 起始必须早于目标。这是引导第 3 屏就有的硬校验，编辑页同样适用 ——
    /// 少了它，用户能在这里造出一个引导流程不允许存在的考试。
    private var startIssue: DefaultDates.StartIssue? {
        defaults.validateStart(startDate, target: targetDate, today: .now)
    }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && startIssue != .notBeforeTarget
    }

    var body: some View {
        SettingsPage(title: exam == nil ? Strings.Exams.addTitle : Strings.Exams.editTitle,
                     palette: palette) {
            SettingsGroup(palette: palette) {
                field(Strings.Exams.fieldName) {
                    TextField(Strings.Exams.fieldNamePlaceholder, text: $title)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textPrimary.color)
                        .multilineTextAlignment(.trailing)
                }
                Divider().overlay(palette.line.color)
                field(Strings.Exams.fieldTargetDate) {
                    DatePicker("", selection: $targetDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            SettingsGroup(palette: palette) {
                field(Strings.Exams.fieldStartDate, caption: Strings.Exams.fieldStartDateCaption) {
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            SettingsGroup(palette: palette) {
                field(Strings.Exams.fieldProvince, caption: Strings.Exams.fieldProvinceCaption) {
                    // 省份用于考后日程。**留空完全正常** —— 留空时走全国通用近似值，
                    // 没有近似值的项整段跳过，不会编一个日期出来。
                    TextField("", text: $province)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textPrimary.color)
                        .multilineTextAlignment(.trailing)
                }
            }

            if exam?.isPrimary != true {
                SettingsGroup(palette: palette) {
                    SettingsToggleRow(title: Strings.Exams.setPrimary,
                                      isOn: $makePrimary, palette: palette)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(Strings.Exams.save) { save() }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? palette.textPrimary.color
                                             : palette.textTertiary.color)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(Strings.Common.close) { dismiss() }
                    .foregroundStyle(palette.textSecondary.color)
            }
        }
        .task { load() }
        .onChange(of: type) { _, newValue in applyDefaults(for: newValue) }
    }

    // MARK: -

    private func field<Trailing: View>(
        _ label: String,
        caption: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.sm) {
                Text(label)
                    .dsFont(DSFont.body(DSType.bodyLarge))
                    .foregroundStyle(palette.textPrimary.color)
                Spacer(minLength: DSSpacing.sm)
                trailing()
            }
            if let caption {
                Text(caption)
                    .dsFont(DSFont.caption(DSType.captionSmall))
                    .foregroundStyle(palette.textSecondary.color)
            }
        }
        .padding(.horizontal, DSSpacing.md + 2)
        .padding(.vertical, DSSpacing.md - 2)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let exam {
            title = exam.title
            type = exam.type
            targetDate = exam.targetDate
            startDate = exam.startDate
            province = exam.province ?? ""
        } else {
            type = .gaokao
            title = Strings.Onboarding.typeName(.gaokao)
            applyDefaults(for: .gaokao)
        }
    }

    private func applyDefaults(for type: ExamType) {
        guard exam == nil else { return }
        let today = Date()
        let target = defaults.targetDate(for: type, today: today)
            ?? defaults.customPickerSeed(today: today)
        targetDate = target
        startDate = defaults.startDate(for: type, targetDate: target, today: today)
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespaces)
        let cleanProvince = province.trimmingCharacters(in: .whitespaces)

        guard let exam else {
            let created = Exam(type: type, title: name,
                               startDate: cal.startOfDay(startDate),
                               targetDate: cal.startOfDay(targetDate),
                               province: cleanProvince.isEmpty ? nil : cleanProvince,
                               isPrimary: false)
            context.insert(created)
            try? context.save()
            if makePrimary { service.setPrimary(created) }
            onSaved(nil)
            dismiss()
            return
        }

        exam.title = name
        exam.type = type
        exam.province = cleanProvince.isEmpty ? nil : cleanProvince

        // 两个日期分开处理：只有考试日期会牵动信件，起始日期不会。
        // 合成一次"保存全部"会让提示语说不清到底是哪一个改动带来了什么。
        var notice: String?
        if cal.startOfDay(targetDate) != cal.startOfDay(exam.targetDate) {
            let effect = service.updateTargetDate(exam, to: targetDate)
            notice = Strings.Exams.targetDateChanged(lettersShifted: effect.lettersShifted)
        }
        if cal.startOfDay(startDate) != cal.startOfDay(exam.startDate) {
            let effect = service.updateStartDate(exam, to: startDate)
            // 两个日期同时改时，把"已走过变成了 N 天"接在后面，
            // 而不是只报其中一个 —— 用户改了两样，就该听见两样。
            let line = Strings.Exams.startDateChanged(passed: effect.daysPassed)
            notice = notice.map { "\($0)\n\(line)" } ?? line
        }
        exam.updatedAt = .now
        try? context.save()
        if makePrimary { service.setPrimary(exam) }

        onSaved(notice)
        dismiss()
    }
}
