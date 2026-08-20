import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import CountdownUI
import DesignTokens

/// 信箱（需求文档 5.6 / 信件文案表第 1 节）。
struct LettersView: View {

    let exam: Exam

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Letter.writtenAt, order: .reverse) private var letters: [Letter]

    @State private var composing = false
    @State private var editingDraft: Letter?
    @State private var reading: Letter?
    @State private var deleting: Letter?
    @State private var toast: String?

    private let cal = DayCalendar.current
    private var display: DateDisplay { DateDisplay(cal: cal) }
    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            if letters.isEmpty { emptyState } else { list }
        }
        .padding(.horizontal, DSSpacing.pageHorizontal)
        .background(palette.background.color.ignoresSafeArea())
        .fullScreenCover(isPresented: $composing) {
            ComposeLetterFlow(exam: exam, draft: nil) { toast = $0 }
        }
        .fullScreenCover(item: $editingDraft) { draft in
            ComposeLetterFlow(exam: exam, draft: draft) { toast = $0 }
        }
        .fullScreenCover(item: $reading) { letter in
            LetterReadView(letter: letter, palette: palette)
        }
        .confirmationDialog(deleteTitle, isPresented: deleteBinding, titleVisibility: .visible) {
            Button(Strings.Letters.deleteConfirm, role: .destructive) { confirmDelete() }
            // 「留着」是有立场的动词，比「取消」好。
            Button(Strings.Letters.deleteCancel, role: .cancel) { deleting = nil }
        } message: {
            Text(deleteBody)
        }
        .overlay(alignment: .top) { toastView }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Strings.Letters.title)
                    .dsFont(DSFont.title(DSType.navTitle))
                    .foregroundStyle(palette.textPrimary.color)
                Text(Strings.Letters.subtitle)
                    .dsFont(DSFont.caption(DSType.navSubtitle))
                    .foregroundStyle(palette.textSecondary.color)
            }
            Spacer()
        }
        .padding(.top, DSSpacing.sm + 2)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(Strings.Letters.emptyTitle)
                .dsFont(DSFont.title(19))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.Letters.emptySubtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.top, DSSpacing.cardGapWide)
            Button { composing = true } label: {
                Text(Strings.Letters.emptyAction)
                    .dsFont(DSFont.body(DSType.bodyLarge))
                    .foregroundStyle(palette.background.color)
                    .padding(.horizontal, DSSpacing.xl)
                    .padding(.vertical, DSSpacing.md)
                    .background(palette.textPrimary.color, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, DSSpacing.xl)
            Spacer()
            Spacer()
        }
    }

    // MARK: - 列表

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: DSSpacing.cardGapWide) {
                ForEach(letters) { row($0) }

                Button { composing = true } label: {
                    Text(Strings.Letters.writeNew)
                        .dsFont(DSFont.body(13))
                        .foregroundStyle(palette.textSecondary.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md)
                        .background {
                            RoundedRectangle(cornerRadius: DSRadius.card)
                                .strokeBorder(palette.line.color,
                                              style: StrokeStyle(lineWidth: DSStroke.hairline, dash: [4, 3]))
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, DSSpacing.xs)

                Text(Strings.Letters.sealedFootnote)
                    .dsFont(DSFont.caption(DSType.captionSmall))
                    .foregroundStyle(palette.textTertiary.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, DSSpacing.md)
            }
            .padding(.vertical, DSSpacing.md)
        }
    }

    private func state(_ letter: Letter) -> LetterState {
        LetterPresentation.state(
            isDraft: letter.isDraft, isOpened: letter.isOpened, openedAt: letter.openedAt,
            openAt: letter.openAt, today: .now, cal: cal
        )
    }

    private func row(_ letter: Letter) -> some View {
        let st = state(letter)
        return Button {
            switch st {
            case .draft:    editingDraft = letter
            case .openable: reading = letter
            case .opened, .sealed: break
            }
        } label: {
            VStack(alignment: .leading, spacing: DSSpacing.sm + 1) {
                HStack {
                    Text(leadingLabel(st, letter))
                    Spacer()
                    Text(trailingLabel(st, letter))
                }
                .dsFont(DSFont.caption(DSType.footnote))
                .foregroundStyle(st == .openable ? palette.tree.color : palette.textTertiary.color)

                rowBody(st, letter)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.md + 3)
            .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.card))
            .overlay {
                if st == .openable {
                    RoundedRectangle(cornerRadius: DSRadius.card).dsHairline(palette.tree)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isSealed(st))
        .contextMenu {
            Button(Strings.Letters.deleteConfirm, role: .destructive) { deleting = letter }
        }
    }

    private func isSealed(_ st: LetterState) -> Bool {
        if case .sealed = st { return true }
        return false
    }

    private func leadingLabel(_ st: LetterState, _ letter: Letter) -> String {
        switch st {
        case .draft:            return Strings.Letters.stateDraft
        case .sealed(let days): return Strings.Letters.sealedRemaining(days)
        case .openable:         return Strings.Letters.readyToOpen
        case .opened(let at):   return Strings.Letters.openedOn(display.long(at))
        }
    }

    private func trailingLabel(_ st: LetterState, _ letter: Letter) -> String {
        switch st {
        case .draft:    return Strings.Letters.lastEdited(display.short(letter.updatedAt))
        case .sealed:   return Strings.Letters.triggerLabel(letter.openTrigger)
        case .openable: return Strings.Letters.writtenDaysAgo(max(cal.days(from: letter.writtenAt, to: .now), 0))
        case .opened:   return Strings.Letters.writtenOn(display.long(letter.writtenAt))
        }
    }

    @ViewBuilder
    private func rowBody(_ st: LetterState, _ letter: Letter) -> some View {
        switch st {
        case .draft:
            // 草稿显示前两行，末尾加「…」
            Text(draftPreview(letter))
                .dsFont(DSFont.userWritten(DSType.body))
                .foregroundStyle(palette.textPrimary.color)
                .lineLimit(2)
                .lineSpacing(4)

        case .sealed:
            // 实心方块，**不用模糊或马赛克** ——
            // 模糊暗示"看得到但看不清"，会诱发用户去试；实心方块是彻底的不可见，反而更安静。
            Text(LetterPresentation.sealedPlaceholder(contentLength: letter.sealedContent.count))
                .dsFont(DSFont.userWritten(DSType.body))
                .foregroundStyle(palette.textTertiary.color)
                .tracking(4)

        case .openable:
            Text(Strings.Letters.tapToOpen)
                .dsFont(DSFont.userWritten(DSType.body))
                .foregroundStyle(palette.textPrimary.color)

        case .opened:
            // 已开启的信直接展开显示全文，不需要再次点击，也没有按钮。
            Text(letter.revealedContent ?? "")
                .dsFont(DSFont.userWritten(DSType.body))
                .foregroundStyle(palette.textPrimary.color)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func draftPreview(_ letter: Letter) -> String {
        guard let text = try? makeService().draftContent(of: letter) else { return "" }
        return text.count > 60 ? String(text.prefix(60)) + "…" : text
    }

    // MARK: - 删除

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }

    private func confirmDelete() {
        guard let deleting else { return }
        makeService().delete(deleting)
        // **不做撤销** —— 撤销会削弱"删除是认真的"这件事，
        // 而这个功能的全部价值就建立在不可逆之上。
        toast = Strings.Letters.deletedToast
        self.deleting = nil
    }

    private var deleteTitle: String {
        guard let deleting else { return "" }
        switch state(deleting) {
        case .draft:  return Strings.Letters.deleteDraftTitle
        case .opened: return Strings.Letters.deleteOpenedTitle
        default:      return Strings.Letters.deleteSealedTitle
        }
    }

    private var deleteBody: String {
        guard let deleting else { return "" }
        switch state(deleting) {
        case .draft:  return Strings.Letters.deleteDraftBody
        case .opened: return Strings.Letters.deleteOpenedBody
        default:      return Strings.Letters.deleteSealedBody
        }
    }

    private func makeService() -> LetterService {
        LetterService(context: context,
                      vault: LetterVault(cipher: KeychainLetterCipher(), cal: cal),
                      cal: cal)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(palette.textPrimary.color)
                .padding(.horizontal, DSSpacing.lg - 4)
                .padding(.vertical, DSSpacing.sm + 2)
                .background(palette.surfaceRaised.color, in: Capsule())
                .task {
                    try? await Task.sleep(for: .seconds(DSMotion.toast.seconds))
                    self.toast = nil
                }
        }
    }
}
