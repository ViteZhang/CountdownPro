import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 写信 → 选开启时机 → 封存确认 → 封好了。
///
/// # 这条流程的重量来自哪里
/// 写信页副标题第二句「封存之后，你也看不到了」是关键 —— **提前建立预期**。
/// 到了封存确认那一屏，用户才会真的停顿一下。少了这句，封存就只是一次保存。
struct ComposeLetterFlow: View {

    let exam: Exam
    let draft: Letter?
    let onToast: (String) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private enum Stage: Equatable {
        case compose
        case pickTrigger
        case confirmSeal(trigger: LetterTrigger, openAt: Date)
        case done(days: Int)
    }

    @State private var stage: Stage = .compose
    @State private var text = ""
    @State private var loadedDraft = false
    @State private var showDraftPrompt = false

    private let cal = DayCalendar.current
    private var display: DateDisplay { DateDisplay(cal: cal) }
    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        ZStack {
            palette.background.color.ignoresSafeArea()
            switch stage {
            case .compose:
                composeStage
            case .pickTrigger:
                TriggerPickerView(exam: exam, palette: palette) { trigger, openAt in
                    stage = .confirmSeal(trigger: trigger, openAt: openAt)
                } onBack: {
                    stage = .compose
                }
            case .confirmSeal(let trigger, let openAt):
                SealConfirmView(openDate: display.long(openAt), palette: palette) {
                    seal(trigger: trigger, openAt: openAt)
                } onCancel: {
                    stage = .pickTrigger
                }
            case .done(let days):
                SealedDoneView(days: days, palette: palette) { dismiss() }
            }
        }
        .task {
            guard !loadedDraft, let draft else { return }
            loadedDraft = true
            text = (try? makeService().draftContent(of: draft)) ?? ""
        }
        .confirmationDialog(Strings.Letters.draftPromptTitle,
                            isPresented: $showDraftPrompt, titleVisibility: .visible) {
            Button(Strings.Letters.draftPromptSave) { saveDraftAndClose() }
            // 「不要了」直接丢弃，**不再二次确认** —— 用户已经明确表达了。
            Button(Strings.Letters.draftPromptDiscard, role: .destructive) { dismiss() }
        } message: {
            Text(Strings.Letters.draftPromptBody)
        }
    }

    // MARK: - 写信

    private var composeStage: some View {
        VStack(alignment: .leading, spacing: 0) {
            navBar(title: Strings.Letters.composeNavTitle) { attemptClose() }

            Text(Strings.Letters.composeTitle)
                .dsFont(DSFont.title(DSType.question))
                .foregroundStyle(palette.textPrimary.color)

            // 第二句提前建立预期，封存的重量来自这里。
            Text(Strings.Letters.composeSubtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .lineSpacing(4)
                .padding(.top, DSSpacing.cardGapWide)

            editor.padding(.top, DSSpacing.lg)

            // 剩余 > 100 字时不显示 —— 计数器会让人分心，
            // 而这一屏的全部目的是降低门槛、不制造表达压力。
            if let hint = LetterPresentation.remainingHint(contentLength: text.count) {
                Text(hint)
                    .dsFont(DSFont.caption(DSType.captionSmall))
                    .foregroundStyle(palette.textTertiary.color)
                    .padding(.top, DSSpacing.sm)
            }

            Spacer(minLength: 0)

            // 无内容时置灰，**文案不变，不弹错误提示**。
            DSPrimaryButtonLike(title: Strings.Letters.composeNext,
                                palette: palette,
                                enabled: !trimmed.isEmpty) {
                stage = .pickTrigger
            }
            .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            // 用户自己写的内容用衬线（设计系统 1.2）。
            TextEditor(text: $text)
                .dsFont(DSFont.userWritten(DSType.userLetter))
                .foregroundStyle(palette.textPrimary.color)
                .lineSpacing(7)
                .scrollContentBackground(.hidden)
                .onChange(of: text) { _, new in
                    if new.count > Strings.Letters.maxLength {
                        text = String(new.prefix(Strings.Letters.maxLength))
                    }
                }

            if text.isEmpty {
                // **降低门槛，不制造表达压力。**
                Text(Strings.Letters.composePlaceholder)
                    .dsFont(DSFont.userWritten(DSType.userLetter))
                    .foregroundStyle(palette.textTertiary.color)
                    .lineSpacing(7)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func navBar(title: String, onBack: @escaping () -> Void) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .buttonStyle(.plain)
            Text(title)
                .dsFont(DSFont.body(DSType.body))
                .foregroundStyle(palette.textPrimary.color)
            Spacer()
        }
        .frame(height: 52)
    }

    // MARK: - 动作

    private func attemptClose() {
        // 触发：内容非空且未封存时点返回。
        if trimmed.isEmpty { dismiss() } else { showDraftPrompt = true }
    }

    private func saveDraftAndClose() {
        try? makeService().saveDraft(trimmed, existing: draft)
        dismiss()
    }

    private func seal(trigger: LetterTrigger, openAt: Date) {
        let service = makeService()
        guard let letter = try? service.saveDraft(trimmed, existing: draft,
                                                  openAt: openAt, trigger: trigger) else { return }
        service.seal(letter, openAt: openAt, trigger: trigger)
        stage = .done(days: max(cal.days(from: .now, to: openAt), 0))
    }

    private func makeService() -> LetterService {
        LetterService(context: context,
                      vault: LetterVault(cipher: KeychainLetterCipher(), cal: cal),
                      cal: cal)
    }
}

// MARK: - 封存确认

/// **这一屏是整个功能的重量所在。必须是全屏，不能是 Alert 或小浮层。**
struct SealConfirmView: View {
    let openDate: String
    let palette: Palette
    let onSeal: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(Strings.Letters.sealTitle)
                .dsFont(DSFont.title(DSType.question))
                .foregroundStyle(palette.textPrimary.color)

            Text(Strings.Letters.sealBody(openDate: openDate))
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, DSSpacing.lg)

            Spacer()

            VStack(spacing: DSSpacing.cardGap) {
                // 主按钮不加「确认」二字 ——「封起来」本身就是动作。
                DSPrimaryButtonLike(title: Strings.Letters.sealConfirm, palette: palette,
                                    enabled: true, action: onSeal)
                // 次按钮用「再看看」，不用「取消」。
                Button(action: onCancel) {
                    Text(Strings.Letters.sealCancel)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md + 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        // 不做勾选确认 —— 那是注销账号的重量级别，这里过重。
        // 不做动画特效，安静地完成。
    }
}

// MARK: - 封好了

/// **不做庆祝动效** —— 这不是成就，是一次托付。
struct SealedDoneView: View {
    let days: Int
    let palette: Palette
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(Strings.Letters.sealedDoneTitle)
                .dsFont(DSFont.title(21))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Letters.sealedDoneSubtitle(days: days))
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.md)
            Spacer()
            DSPrimaryButtonLike(title: Strings.Letters.sealedDoneBack, palette: palette,
                                enabled: true, action: onBack)
                .padding(.bottom, DSSpacing.xl + 6)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }
}
