import SwiftUI
import CountdownKit
import CountdownUI
import DesignTokens

/// 分享卡预览与导出（需求文档 5.8）。
///
/// 用户可随时在首页右上角手动生成任意类型卡片；节点日则由 `MilestonePromptView`
/// 主动递卡 —— **用户不会主动想到分享。**
///
/// 两个出口（分享 / 保存到相册）统一在 `ShareCardActions` 里，
/// 全屏递卡走的是同一个组件：两处各写一遍，迟早会有一处只剩保存。
struct ShareCardSheet: View {

    let cards: [ShareCardKind: ShareCardContent]
    let palette: Palette
    var initialKind: ShareCardKind = .milestone

    @Environment(\.dismiss) private var dismiss
    @State private var kind: ShareCardKind
    @State private var toast: String?

    private let cal = DayCalendar.current

    init(cards: [ShareCardKind: ShareCardContent], palette: Palette,
         initialKind: ShareCardKind = .milestone) {
        self.cards = cards
        self.palette = palette
        self.initialKind = initialKind
        _kind = State(initialValue: initialKind)
    }

    private var available: [ShareCardKind] {
        ShareCardKind.allCases.filter { cards[$0] != nil }
    }

    var body: some View {
        ZStack {
            palette.background.color.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(Strings.Common.close) { dismiss() }
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textSecondary.color)
                }
                .padding(.horizontal, DSSpacing.pageHorizontalWide)
                .padding(.top, DSSpacing.sm)

                Spacer()

                if available.count > 1 {
                    tabs.padding(.bottom, DSSpacing.lg)
                }

                if let content = cards[kind] {
                    ShareCardView(content: content, palette: palette)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card - 1))

                    ShareCardActions(
                        content: content,
                        palette: palette,
                        dateText: DateDisplay(cal: cal).dotted(.now),
                        onToast: { toast = $0 }
                    )
                    .padding(.top, DSSpacing.lg)
                }

                Text(Strings.ShareCard.noQRCodeHint)
                    .dsFont(DSFont.caption(DSType.captionSmall))
                    .foregroundStyle(palette.textTertiary.color)
                    .padding(.top, DSSpacing.md - 2)

                Spacer()
            }
        }
        .overlay(alignment: .top) { toastView }
    }

    private var tabs: some View {
        HStack(spacing: 7) {
            ForEach(available, id: \.rawValue) { item in
                Button { kind = item } label: {
                    Text(tabTitle(item))
                        .dsFont(DSFont.caption(11.5))
                        .foregroundStyle(item == kind ? palette.background.color
                                                      : palette.textSecondary.color)
                        .padding(.horizontal, DSSpacing.md - 1)
                        .padding(.vertical, 7)
                        .background {
                            if item == kind {
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

    private func tabTitle(_ kind: ShareCardKind) -> String {
        switch kind {
        case .milestone: return Strings.ShareCard.tabMilestone
        case .note:      return Strings.ShareCard.tabNote
        case .zero:      return Strings.ShareCard.tabZero
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(palette.textPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.lg - 4)
                .padding(.vertical, DSSpacing.sm + 2)
                .background(palette.surfaceRaised.color,
                            in: RoundedRectangle(cornerRadius: DSRadius.card - 1))
                .padding(.horizontal, DSSpacing.pageHorizontalWide)
                .padding(.top, DSSpacing.xl + 10)
                .task {
                    try? await Task.sleep(for: .seconds(DSMotion.toast.seconds))
                    self.toast = nil
                }
        }
    }
}
