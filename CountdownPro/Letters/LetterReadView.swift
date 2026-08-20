import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 信件正文页（信件文案表 5.2）。
///
/// 设计决策 D-07 在这里有一个具体用途：基底不是纯黑，所以拆信时压到近黑
/// 还有"更深"的余地 —— 全屏戏剧化的空间是留出来的，不是碰巧有的。
struct LetterReadView: View {

    let letter: Letter
    let palette: Palette

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var content: String?

    private let cal = DayCalendar.current
    private var display: DateDisplay { DateDisplay(cal: cal) }

    var body: some View {
        ZStack {
            palette.background.color.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: DSSpacing.xl)

                Text(Strings.Letters.readHeader(display.long(letter.writtenAt)))
                    .dsFont(DSFont.caption(DSType.captionSmall))
                    .foregroundStyle(palette.textTertiary.color)

                ScrollView {
                    Text(content ?? "")
                        .dsFont(DSFont.userWritten(DSType.userLetter))
                        .foregroundStyle(palette.textPrimary.color)
                        // 行高 2.0
                        .lineSpacing(DSType.userLetter)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, DSSpacing.lg)

                // 落款天数是**写信到开启的实际间隔**，不是固定文案。
                Text(LetterPresentation.signature(
                    writtenAt: letter.writtenAt,
                    openedAt: letter.openedAt ?? .now,
                    cal: cal
                ))
                .dsFont(DSFont.caption(DSType.captionSmall))
                .foregroundStyle(palette.textTertiary.color)
                .padding(.top, DSSpacing.lg + 4)

                Spacer(minLength: 0)

                DSPrimaryButtonLike(title: Strings.Letters.readDone, palette: palette,
                                    enabled: true) { dismiss() }
                    .padding(.bottom, DSSpacing.xl + 6)
            }
            .padding(.horizontal, DSSpacing.pageHorizontalWide)
        }
        .task { open() }
    }

    private func open() {
        guard content == nil else { return }
        if letter.isOpened, let cached = letter.revealedContent {
            content = cached      // 开启后永久可重读
            return
        }
        let service = LetterService(context: context,
                                    vault: LetterVault(cipher: KeychainLetterCipher(), cal: cal),
                                    cal: cal)
        do {
            content = try service.open(letter)
        } catch {
            // 到期前不可能走到这里 —— 列表已经不让点了。
            // 真走到了说明状态判断和解密闸门不一致，宁可什么都不显示，也不泄露正文。
            dismiss()
        }
    }
}
