import WidgetKit
import SwiftUI
import CountdownKit
import CountdownUI
import DesignTokens

// MARK: - 桌面小号 2×2

/// 需求文档 5.10：**小号用横条不用环** —— 2×2 内环会把数字压得过小。
struct SmallWidgetView: View {
    let entry: CountdownEntry
    @Environment(\.colorScheme) private var colorScheme

    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(data.examTitle)
                    .dsFont(DSFont.caption(11))
                    .foregroundStyle(palette.textSecondary.color)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(remainingText(data.countdown))
                        .dsFont(DSFont.display(38))
                        .foregroundStyle(palette.textPrimary.color)
                    if !data.countdown.isExamDay && !data.countdown.isAfterExam {
                        Text(Strings.Common.day)
                            .dsFont(DSFont.caption(12))
                            .foregroundStyle(palette.textSecondary.color)
                    }
                }

                DSProgressBar(progress: data.countdown.progress, palette: palette,
                              height: DSStroke.barWidget)

                // D-01：有"剩余"的地方必须同时有"已走过"。小组件也不例外。
                Text(Strings.Home.passed(data.countdown.daysPassed))
                    .dsFont(DSFont.caption(11))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            PlaceholderView(palette: palette)
        }
    }
}

// MARK: - 桌面中号 4×2

/// 进度环 + 成长物 + 同考人数（5.10）。
struct MediumWidgetView: View {
    let entry: CountdownEntry
    @Environment(\.colorScheme) private var colorScheme

    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        if let data = entry.data {
            HStack(spacing: DSSpacing.lg) {
                // 环。小组件里不做入场动画。
                DSRingView(progress: data.countdown.progress, palette: palette,
                           lineWidth: DSStroke.ring * 0.7, animated: false) {
                    VStack(spacing: 0) {
                        Text(remainingText(data.countdown))
                            .dsFont(DSFont.display(32))
                            .foregroundStyle(palette.textPrimary.color)
                        Text(Strings.Home.passed(data.countdown.daysPassed))
                            .dsFont(DSFont.caption(9))
                            .foregroundStyle(palette.textSecondary.color)
                    }
                }
                .frame(width: 88, height: 88)

                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(data.examTitle)
                        .dsFont(DSFont.body(15))
                        .foregroundStyle(palette.textPrimary.color)

                    HStack(spacing: DSSpacing.sm) {
                        TreeView(stage: data.countdown.growthStage, color: palette.tree)
                            .frame(width: 26, height: 30)
                        Text(data.countdown.growthStage.displayName)
                            .dsFont(DSFont.caption(11))
                            .foregroundStyle(palette.textSecondary.color)
                    }

                    // 同考人数需要网络。**无数据时该行隐藏，其余正常显示**（5.10）。
                    // 注意 censusDisplay 只在"今天"那条 entry 上有值 ——
                    // 拿昨天的数字说「今天有 X 万人」就是造假（D-09）。
                    if let census = data.censusDisplay {
                        Text(Strings.Home.together(census))
                            .dsFont(DSFont.caption(11))
                            .foregroundStyle(palette.textTertiary.color)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            PlaceholderView(palette: palette)
        }
    }
}

// MARK: - 共用

/// 考试当天中心显示「今天」（5.2 / 5.12），不显示 0。
func remainingText(_ c: Countdown) -> String {
    if c.isExamDay { return Strings.Home.today }
    if c.isAfterExam { return "\(abs(c.daysRemaining))" }
    return "\(c.daysRemaining)"
}

struct PlaceholderView: View {
    let palette: Palette
    var body: some View {
        Text(Strings.Widget.notConfigured)
            .dsFont(DSFont.caption(12))
            .foregroundStyle(palette.textSecondary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
