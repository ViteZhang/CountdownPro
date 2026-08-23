import Foundation
import CountdownKit
import DesignTokens
#if canImport(SwiftUI)
import SwiftUI

/// 分享卡渲染（需求文档 5.8）。
///
/// # 三类卡如何做到"明显不同"
/// 5.8.3 要求三类卡的配色与排版明显不同，避免"同一套模板"的廉价感。
/// 但 D-06 规定全界面灰阶、唯一彩色留给树 —— 不能靠加颜色来区分。
///
/// 所以差异化落在两处：**版式**（大数字主导 / 引文主导 / 终局对称）
/// 与**底色层级**（基底 / 卡片 / 升起卡片）。
/// 如果评审认为区分度还不够，解法仍然是在 DesignTokens 里做，不是在这里加彩色。
public struct ShareCardView: View {

    public let content: ShareCardContent
    public let palette: Palette

    public init(content: ShareCardContent, palette: Palette) {
        self.content = content
        self.palette = palette
    }

    private var size: CGSize {
        CGSize(width: ShareCardBuilder.designSize.width, height: ShareCardBuilder.designSize.height)
    }

    /// 底色按卡片类型取不同层级 —— 这是灰阶体系内可用的区分手段之一。
    private var cardBackground: DSColor {
        switch content.kind {
        case .milestone: return palette.background
        case .note:      return palette.surface
        case .zero:      return palette.surfaceRaised
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.label)
                .dsFont(DSFont.caption(11))
                .foregroundStyle(palette.textSecondary.color)

            Spacer(minLength: 0)

            switch content.kind {
            case .milestone: milestoneBody
            case .note:      noteBody
            case .zero:      zeroBody
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(DSSpacing.lg)
        .frame(width: size.width, height: size.height)
        .background(cardBackground.color)
        .overlay(alignment: .bottomTrailing) {
            // 仅一行淡色产品名。不含 Logo、不含二维码、不含下载引导（D-11）。
            Text(content.watermark)
                .dsFont(DSFont.caption(DSType.cardWatermark))
                .foregroundStyle(palette.textTertiary.color)
                .padding(.trailing, DSSpacing.lg)
                .padding(.bottom, DSSpacing.sm + 1)
        }
    }

    // MARK: - 版式一：大数字主导

    private var milestoneBody: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm - 1) {
            Text(content.bigNumber ?? "")
                .dsFont(DSFont.display(DSType.cardBigNumber))
                .foregroundStyle(palette.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(content.bigUnit ?? "")
                .dsFont(DSFont.caption(DSType.body))
                .foregroundStyle(palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 版式二：引文主导

    private var noteBody: some View {
        // 用户自己写的内容用衬线（设计系统 1.2）。
        // 这张卡上用户的话是主角，所以它占据整个中段。
        Text(content.quote ?? "")
            .dsFont(DSFont.userWritten(DSType.cardQuote))
            .foregroundStyle(palette.textPrimary.color)
            .lineSpacing(DSType.cardQuote * 0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - 版式三：终局

    private var zeroBody: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm - 1) {
            Text(content.bigNumber ?? "")
                .dsFont(DSFont.display(48))
                .foregroundStyle(palette.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(content.bigUnit ?? "")
                .dsFont(DSFont.body(19))
                .foregroundStyle(palette.textPrimary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 页脚：每张卡的必填项

    private var footer: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm + 1) {
            if content.showsBloomingTree {
                TreeView(stage: .blooming, color: palette.tree)
                    .frame(width: 34, height: 39)
            }

            // D-11：这条进度条是无二维码情况下全部的品牌识别，每张卡都必须有。
            DSProgressBar(progress: content.passedProgress, palette: palette)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(content.footnotes, id: \.self) { line in
                    Text(line)
                        .dsFont(DSFont.caption(DSType.footnote))
                        .foregroundStyle(palette.textTertiary.color)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
