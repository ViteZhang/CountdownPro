import SwiftUI
import CountdownKit
import CountdownStore
import DesignTokens

/// 选择开启时机（信件文案表第 3 节）。
struct TriggerPickerView: View {

    let exam: Exam
    let palette: Palette
    let onPick: (LetterTrigger, Date) -> Void
    let onBack: () -> Void

    @State private var showingCustom = false
    @State private var customDate = Date()

    private let cal = DayCalendar.current
    private var engine: CountdownEngine { CountdownEngine(cal: cal) }
    private var display: DateDisplay { DateDisplay(cal: cal) }

    /// 出分日依赖考后日程表（5.12），暂无数据 → 该选项不出现。
    private let resultDay: Date? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            navBar

            Text(Strings.Letters.triggerTitle)
                .dsFont(DSFont.title(DSType.question))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Letters.triggerSubtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.cardGapWide)

            ScrollView {
                VStack(spacing: DSSpacing.cardGap) {
                    ForEach(availableTriggers, id: \.rawValue) { option($0) }
                }
                .padding(.top, DSSpacing.xl)
                .padding(.bottom, DSSpacing.lg)
            }
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        .sheet(isPresented: $showingCustom) {
            CustomDatePicker(exam: exam, palette: palette, date: $customDate) { date in
                showingCustom = false
                onPick(.custom, date)
            }
        }
    }

    private var navBar: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .buttonStyle(.plain)
            Text(Strings.Letters.triggerNavTitle)
                .dsFont(DSFont.body(DSType.body))
                .foregroundStyle(palette.textPrimary.color)
            Spacer()
        }
        .frame(height: 52)
    }

    /// **已经过去的节点不显示该选项，不要显示成置灰。**
    /// 一个永远点不动的选项只会让人疑惑"为什么不能选"。
    private var availableTriggers: [LetterTrigger] {
        LetterTrigger.allCases.filter { trigger in
            guard trigger != .custom else { return true }
            return engine.isTriggerSelectable(trigger, targetDate: exam.targetDate,
                                              today: .now, resultDay: resultDay)
        }
    }

    private func option(_ trigger: LetterTrigger) -> some View {
        Button {
            if trigger == .custom {
                customDate = cal.adding(days: 1, to: .now)
                showingCustom = true
            } else if let openAt = engine.letterOpenDate(trigger: trigger,
                                                         targetDate: exam.targetDate,
                                                         resultDay: resultDay) {
                onPick(trigger, openAt)
            }
        } label: {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(Strings.Letters.triggerLabel(trigger))
                    .dsFont(DSFont.body(DSType.bodyLarge))
                    .foregroundStyle(palette.textPrimary.color)
                if let sub = subtitle(trigger) {
                    Text(sub)
                        .dsFont(DSFont.caption(11.5))
                        .foregroundStyle(palette.textTertiary.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.md + 4)
            .padding(.vertical, DSSpacing.md + 3)
            .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.card))
        }
        .buttonStyle(.plain)
    }

    /// 预设节点的副文案是**换算出来的实际日期**，让用户知道到底是哪天。
    /// 「出分那天」例外 —— 它的副文案是一句刻意中性的话。
    private func subtitle(_ trigger: LetterTrigger) -> String? {
        switch trigger {
        case .custom:
            return nil
        case .resultDay:
            // 出分日会把用户分成截然不同的两群，提前用一句中性的话打个底。
            return Strings.Letters.resultDayHint
        default:
            return engine.letterOpenDate(trigger: trigger, targetDate: exam.targetDate)
                .map(display.long)
        }
    }
}

/// 自定义开启日期（信件文案表 3.2）。
struct CustomDatePicker: View {

    let exam: Exam
    let palette: Palette
    @Binding var date: Date
    let onConfirm: (Date) -> Void

    private let cal = DayCalendar.current

    private var issue: LetterPresentation.CustomDateIssue? {
        LetterPresentation.validateCustomDate(date, today: .now,
                                              targetDate: exam.targetDate, cal: cal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Letters.customDateTitle)
                .dsFont(DSFont.title(19))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Letters.customDateBody)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.sm)

            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.top, DSSpacing.md)

            if let message = issueMessage {
                Text(message)
                    .dsFont(DSFont.caption(DSType.caption))
                    .foregroundStyle(palette.warning.color)
                    .padding(.top, DSSpacing.sm)
            }

            Spacer(minLength: 0)

            // 只有「已过去」阻断。晚于考试日**允许** ——
            // 有人就是想写给考完的自己。只提示，不阻拦。
            DSPrimaryButtonLike(
                title: Strings.Letters.composeNext,
                palette: palette,
                enabled: LetterPresentation.canUseCustomDate(date, today: .now,
                                                             targetDate: exam.targetDate, cal: cal)
            ) {
                onConfirm(cal.startOfDay(date))
            }
            .padding(.bottom, DSSpacing.lg)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        .padding(.top, DSSpacing.lg)
        .background(palette.background.color)
    }

    private var issueMessage: String? {
        switch issue {
        case .inPast:    return Strings.Letters.customDateInPast
        case .isToday:   return Strings.Letters.customDateIsToday
        case .afterExam: return Strings.Letters.customDateAfterExam
        case nil:        return nil
        }
    }
}
