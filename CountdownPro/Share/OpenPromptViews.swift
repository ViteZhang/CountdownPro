import SwiftUI
import CountdownKit
import CountdownUI
import DesignTokens

/// 节点日的全屏递卡（需求文档 5.8.2）。
///
/// # 为什么必须主动递
/// **用户不会主动想到分享，必须由产品在情绪峰值主动递卡。**
/// 但只递一次 —— 每个节点关闭后不再重复弹出，否则就从"递"变成"催"。
///
/// # 这里的按钮必须当场把事办了
/// 原来的实现里，「保存图片」点下去是**再打开一个页面**，那个页面上还有一个
/// 一模一样的「保存图片」。递卡的全部意义是趁情绪峰值一步完成，
/// 中间插一屏，峰值就过去了 —— 而且用户会以为自己第一次没点中。
struct MilestonePromptView: View {

    let content: ShareCardContent
    let palette: Palette
    let dateText: String
    /// 只用于提示保存结果。关闭由 `onDecline` 负责。
    let onToast: (String) -> Void
    let onDecline: () -> Void

    var body: some View {
        ZStack {
            palette.background.color.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // 全屏展示**已经生成好的卡片**，用户看到的就是将要保存/分享的那张。
                ShareCardView(content: content, palette: palette)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.card - 1))

                ShareCardActions(
                    content: content,
                    palette: palette,
                    dateText: dateText,
                    // 「不了」在前 —— 拒绝不该藏起来。
                    leading: AnyView(declineButton),
                    onToast: onToast,
                    // 存完就走：这一屏已经没有别的事可做了。
                    onSaved: onDecline
                )
                .padding(.top, DSSpacing.xl + 10)

                Spacer()
            }
            .padding(.horizontal, DSSpacing.pageHorizontalWide)
        }
    }

    private var declineButton: some View {
        Button(action: onDecline) {
            Text(Strings.ShareCard.decline)
                .dsFont(DSFont.body(DSType.body))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.horizontal, DSSpacing.md + 2)
                .padding(.vertical, DSSpacing.md - 1)
                .background { Capsule().dsHairline(palette.line) }
        }
        .buttonStyle(.plain)
    }
}

/// 信件到期的全屏提示（信件文案表 5.1）。
///
/// **优先级高于分享卡节点触发** —— 信是不可重建的，卡片随时可以手动生成。
struct LetterDuePromptView: View {

    let writtenDaysAgo: Int
    let palette: Palette
    let onOpen: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            palette.background.color.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text(Strings.Letters.dueTitle)
                    .dsFont(DSFont.title(21))
                    .foregroundStyle(palette.textPrimary.color)

                Text(Strings.Letters.dueSubtitle(daysAgo: writtenDaysAgo))
                    .dsFont(DSFont.caption(13))
                    .foregroundStyle(palette.textSecondary.color)
                    .padding(.top, DSSpacing.md)

                Spacer()

                VStack(spacing: DSSpacing.cardGap) {
                    DSPrimaryButtonLike(title: Strings.Letters.dueOpen, palette: palette,
                                        enabled: true, action: onOpen)
                    // 「待会儿」当天不再弹，次日再触发，直到被拆开。
                    Button(action: onLater) {
                        Text(Strings.Letters.dueLater)
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
        }
    }
}
