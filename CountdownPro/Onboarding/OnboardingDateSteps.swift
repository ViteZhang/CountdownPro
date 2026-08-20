import SwiftUI
import CountdownKit
import DesignTokens

/// 年 / 月 / 日三个滚轮。
///
/// 日的可选范围随年月收敛（如 31 日切到 2 月变 28 日）——
/// 收敛由 `DayCalendar.day(_:_:_:)` 统一处理，这里不重复实现。
struct DateWheels: View {

    @Binding var date: Date
    let yearRange: ClosedRange<Int>
    let palette: Palette
    let cal: DayCalendar

    var body: some View {
        HStack(spacing: 0) {
            wheel(selection: yearBinding, values: Array(yearRange), suffix: "年")
            wheel(selection: monthBinding, values: Array(1...12), suffix: "月")
            wheel(selection: dayBinding, values: Array(1...cal.daysInMonth(date)), suffix: "日")
        }
        .frame(height: 132)
    }

    private func wheel(selection: Binding<Int>, values: [Int], suffix: String) -> some View {
        Picker("", selection: selection) {
            ForEach(values, id: \.self) { value in
                Text("\(value)\(suffix)")
                    .dsFont(DSFont.body(DSType.body))
                    .foregroundStyle(palette.textPrimary.color)
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { cal.year(of: date) },
                set: { date = cal.day($0, cal.month(of: date), cal.dayOfMonth(of: date)) })
    }
    private var monthBinding: Binding<Int> {
        Binding(get: { cal.month(of: date) },
                set: { date = cal.day(cal.year(of: date), $0, cal.dayOfMonth(of: date)) })
    }
    private var dayBinding: Binding<Int> {
        Binding(get: { cal.dayOfMonth(of: date) },
                set: { date = cal.day(cal.year(of: date), cal.month(of: date), $0) })
    }
}

/// 大字日期 + 星期。
struct BigDateDisplay: View {
    let date: Date
    let palette: Palette
    let cal: DayCalendar

    private var display: DateDisplay { DateDisplay(cal: cal) }

    var body: some View {
        VStack(spacing: DSSpacing.sm + 1) {
            Text(display.long(date))
                .dsFont(DSFont.display(DSType.onboardingDate))
                .foregroundStyle(palette.textPrimary.color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(display.weekday(date))
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
        }
    }
}

/// 提示条 / 错误条。
///
/// 需求文档第 7 章：**错误文案说明发生了什么 + 怎么修，不道歉。**
struct OnboardingNotice: View {
    enum Kind { case tip, warning }
    let kind: Kind
    let text: String
    let palette: Palette
    var action: (title: String, run: () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm + 1) {
            Text(text)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(kind == .tip ? palette.textSecondary.color : palette.warning.color)
                .fixedSize(horizontal: false, vertical: true)

            if let action {
                Button(action: action.run) {
                    Text(action.title)
                        .dsFont(DSFont.caption(DSType.caption))
                        .foregroundStyle(palette.textPrimary.color)
                        .padding(.horizontal, DSSpacing.md - 1)
                        .padding(.vertical, 7)
                        .background { Capsule().dsHairline(palette.line) }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DSSpacing.md + 1)
        .padding(.vertical, DSSpacing.md - 1)
        .background {
            switch kind {
            case .tip:
                RoundedRectangle(cornerRadius: DSRadius.field).fill(palette.surface.color)
            case .warning:
                RoundedRectangle(cornerRadius: DSRadius.field).dsHairline(palette.warning)
            }
        }
    }
}

// MARK: - 第 2 屏：目标日期

/// **确认而非输入。默认值必须已经填好。**
struct OnboardingTargetStep: View {

    let state: OnboardingState
    let model: OnboardingModel
    let palette: Palette
    let today: Date
    let onChange: (OnboardingState) -> Void
    let onContinue: () -> Void

    private var cal: DayCalendar { model.cal }

    private var dateBinding: Binding<Date> {
        Binding(get: { state.targetDate }, set: { onChange(model.setTarget($0, in: state)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Onboarding.step2Title)
                .dsFont(DSFont.title(DSType.question))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Onboarding.step2Subtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.cardGapWide)

            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    BigDateDisplay(date: state.targetDate, palette: palette, cal: cal)
                    DateWheels(date: dateBinding,
                               yearRange: cal.year(of: today)...(cal.year(of: today) + 6),
                               palette: palette, cal: cal)

                    if let issue = model.targetIssue(in: state, today: today) {
                        if case .inPast(let suggestedYear) = issue {
                            OnboardingNotice(
                                kind: .warning,
                                text: Strings.Onboarding.targetInPast(nextYear: suggestedYear),
                                palette: palette,
                                action: (Strings.Onboarding.rollToYear(suggestedYear), {
                                    onChange(model.rollTargetToNextYear(in: state))
                                })
                            )
                        }
                    } else {
                        OnboardingNotice(kind: .tip,
                                         text: Strings.Onboarding.step2Tip(state.examType),
                                         palette: palette)
                    }
                }
                .padding(.top, DSSpacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)

            Spacer(minLength: 0)

            // 报错期间「继续」置灰
            DSPrimaryButtonLike(title: Strings.Onboarding.step2Continue,
                                palette: palette,
                                enabled: model.canLeaveTargetStep(state, today: today),
                                action: onContinue)
                .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }
}

// MARK: - 第 3 屏：起始日期

/// **全流程最关键的一屏。**
/// 没有起点就没有「已走过」，整个产品的内核不成立。
struct OnboardingStartStep: View {

    let state: OnboardingState
    let model: OnboardingModel
    let palette: Palette
    let today: Date
    let onChange: (OnboardingState) -> Void
    let onFinish: () -> Void

    private var cal: DayCalendar { model.cal }

    private var dateBinding: Binding<Date> {
        Binding(get: { state.startDate },
                set: { onChange(model.setStart($0, source: .manual, in: state)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Onboarding.step3Title)
                .dsFont(DSFont.title(DSType.question))
                .foregroundStyle(palette.textPrimary.color)
            // 副标题必须解释这个日期是干什么用的。
            Text(Strings.Onboarding.step3Subtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.cardGapWide)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(spacing: DSSpacing.lg) {
                    BigDateDisplay(date: state.startDate, palette: palette, cal: cal)
                    quickStarts
                    DateWheels(date: dateBinding,
                               yearRange: (cal.year(of: today) - 6)...cal.year(of: today),
                               palette: palette, cal: cal)

                    if let issue = model.startIssue(in: state, today: today) {
                        OnboardingNotice(
                            kind: .warning,
                            text: issue == .notBeforeTarget
                                ? Strings.Onboarding.startNotBeforeTarget
                                : Strings.Onboarding.startInFuture,
                            palette: palette
                        )
                    } else {
                        OnboardingNotice(kind: .tip,
                                         text: Strings.Onboarding.step3Tip(state.examType),
                                         palette: palette)
                    }
                }
                .padding(.top, DSSpacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)

            Spacer(minLength: 0)

            DSPrimaryButtonLike(title: Strings.Onboarding.step3Done,
                                palette: palette,
                                enabled: model.canFinish(state, today: today),
                                action: onFinish)
                .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }

    /// 快捷选项优先于选择器。命中当前值时高亮。
    ///
    /// **不强制用开学日** —— 复读生、在职考生的起点不一样。
    private var quickStarts: some View {
        let options = model.quickStarts(in: state, today: today)
        return HStack(spacing: DSSpacing.sm) {
            ForEach(options, id: \.title) { option in
                let selected = cal.isSameDay(option.date, state.startDate)
                Button {
                    onChange(model.setStart(option.date, source: .quick, in: state))
                } label: {
                    Text(option.title)
                        .dsFont(DSFont.caption(DSType.caption))
                        .foregroundStyle(selected ? palette.background.color : palette.textSecondary.color)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, DSSpacing.sm)
                        .background {
                            if selected {
                                Capsule().fill(palette.textPrimary.color)
                            } else {
                                Capsule().dsHairline(palette.line)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 底部主按钮，带禁用态。
struct DSPrimaryButtonLike: View {
    let title: String
    let palette: Palette
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.background.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.md + 2)
                .background(palette.textPrimary.color,
                            in: RoundedRectangle(cornerRadius: DSRadius.button))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.3)
        .disabled(!enabled)
    }
}
