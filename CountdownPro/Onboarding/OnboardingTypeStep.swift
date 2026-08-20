import SwiftUI
import CountdownKit
import DesignTokens

/// 第 1 屏：选择考试类型。
///
/// **选中即前进，不设「继续」按钮** —— 少一次点击。
/// 选中后停留 220ms 再切屏，让选中有反馈。
struct OnboardingTypeStep: View {

    let palette: Palette
    let onSelect: (ExamType) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlighted: ExamType?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Strings.Onboarding.step1Title)
                .dsFont(DSFont.title(DSType.question))
                .foregroundStyle(palette.textPrimary.color)

            Text(Strings.Onboarding.step1Subtitle)
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.cardGapWide)

            VStack(spacing: DSSpacing.cardGap) {
                // 五个固定选项，**顺序不随使用频率变化**。
                ForEach(ExamType.allCases, id: \.rawValue) { type in
                    option(type)
                }
            }
            .padding(.top, DSSpacing.xl)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
    }

    private func option(_ type: ExamType) -> some View {
        Button {
            highlighted = type
            let delay = reduceMotion ? 0 : DSMotion.optionSelectHold.seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { onSelect(type) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(Strings.Onboarding.typeName(type))
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.textPrimary.color)
                    Text(Strings.Onboarding.typeHint(type))
                        .dsFont(DSFont.caption(11.5))
                        .foregroundStyle(palette.textTertiary.color)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.textPrimary.color)
                    .opacity(highlighted == type ? 1 : 0)
            }
            .padding(.horizontal, DSSpacing.md + 4)
            .padding(.vertical, DSSpacing.md + 3)
            .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.card))
            .overlay {
                // 选中态用描边 + 勾，**不用填充色** ——
                // 全界面灰阶，唯一的彩色留给树（D-06）。
                RoundedRectangle(cornerRadius: DSRadius.card)
                    .stroke(highlighted == type ? palette.textPrimary.color : .clear,
                            lineWidth: DSStroke.hairline * 2)
            }
        }
        .buttonStyle(.plain)
        .animation(DSMotion.animation(DSMotion.stateChange, reduceMotion: reduceMotion), value: highlighted)
    }
}
