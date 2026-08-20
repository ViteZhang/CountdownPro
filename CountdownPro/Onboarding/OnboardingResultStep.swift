import SwiftUI
import CountdownKit
import CountdownUI
import DesignTokens

/// 第 4 屏：第一次看见那个数字。
///
/// # 这不是结果页，是一场演出
/// **全产品的第一个情绪触点。**
///
/// 时序（需求文档 5.1 / ONBOARD-04）：
/// - `0ms` 数字从 0 滚到实际天数，`1400ms` 结束
/// - `260ms` 进度条开始填充，`1500ms` 走完
/// - `1200 / 1700 / 2200ms` 依次淡入：剩余天数 → 树 → 按钮
/// - 总时长约 `2500ms`，**不可跳过 —— 全产品唯一一次允许强制观看**
///
/// # 顺序不可颠倒
/// 设计决策 D-14：先说「已经走过」，再说「还剩」。这是全产品的第一个情绪触点，
/// **顺序即立场**。颠倒过来，产品在用户心里就被归类为"又一个倒计时"。
///
/// `prefers-reduced-motion` 时直接显示终值，不做过渡。
struct OnboardingResultStep: View {

    let countdown: Countdown
    let palette: Palette
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rolledDays = 0
    @State private var barProgress: Double = 0
    @State private var showRest = false
    @State private var showTree = false
    @State private var showFoot = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // 先是「已经走过」——
            Text("\(rolledDays)")
                .dsFont(DSFont.display(DSType.onboardingResult))
                .foregroundStyle(palette.textPrimary.color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(Strings.Onboarding.resultLabel)
                .dsFont(DSFont.caption(DSType.body))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.md)

            DSProgressBar(progress: barProgress, palette: palette)
                .frame(width: 190)
                .padding(.top, DSSpacing.xl + 10)

            // —— 之后才是「还剩」。
            Text(Strings.Onboarding.resultRemaining(max(countdown.daysRemaining, 0)))
                .dsFont(DSFont.caption(13))
                .foregroundStyle(palette.textSecondary.color)
                .padding(.top, DSSpacing.md)
                .opacity(showRest ? 1 : 0)

            VStack(spacing: DSSpacing.md - 2) {
                TreeView(stage: countdown.growthStage, color: palette.tree,
                         lineWidth: DSStroke.treeMin)
                    .frame(width: 52, height: 60)
                Text(Strings.Onboarding.treeCaption)
                    .dsFont(DSFont.caption(DSType.caption))
                    .foregroundStyle(palette.textTertiary.color)
            }
            .padding(.top, DSSpacing.xl + 6)
            .opacity(showTree ? 1 : 0)

            Spacer(minLength: 0)

            VStack(spacing: DSSpacing.md) {
                Button(action: onStart) {
                    Text(Strings.Onboarding.resultStart)
                        .dsFont(DSFont.body(DSType.bodyLarge))
                        .foregroundStyle(palette.background.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSSpacing.md + 2)
                        .background(palette.textPrimary.color,
                                    in: RoundedRectangle(cornerRadius: DSRadius.button))
                }
                .buttonStyle(.plain)

                // D-10 在引导终点的最后一次兑现：不需要注册。
                Text(Strings.Onboarding.resultFootnote)
                    .dsFont(DSFont.caption(DSType.captionSmall))
                    .foregroundStyle(palette.textTertiary.color)
            }
            .padding(.bottom, DSSpacing.xl + 6)
            .opacity(showFoot ? 1 : 0)
        }
        .padding(.horizontal, DSSpacing.pageHorizontalWide)
        .task { await perform() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(Strings.Home.passed(countdown.daysPassed))，\(Strings.Onboarding.resultRemaining(max(countdown.daysRemaining, 0)))"
        )
    }

    private func perform() async {
        guard !reduceMotion else {
            // 直接显示终值，不做过渡。
            rolledDays = countdown.daysPassed
            barProgress = countdown.progress
            showRest = true; showTree = true; showFoot = true
            return
        }

        async let roll: Void = rollNumber()
        async let bar: Void = fillBar()
        async let fades: Void = fadeInSequence()
        _ = await (roll, bar, fades)
    }

    /// 数字从 0 滚到实际天数，1400ms，cubic ease-out。
    private func rollNumber() async {
        let target = countdown.daysPassed
        guard target > 0 else { return }
        let duration = DSMotion.Onboarding.counterRoll.seconds
        let start = Date()

        while true {
            let t = min(Date().timeIntervalSince(start) / duration, 1)
            let eased = 1 - pow(1 - t, 3)
            rolledDays = Int((Double(target) * eased).rounded())
            if t >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
        rolledDays = target
    }

    private func fillBar() async {
        try? await Task.sleep(for: .seconds(DSMotion.Onboarding.barDelay.seconds))
        withAnimation(DSMotion.animation(DSMotion.Onboarding.barFill, reduceMotion: false)) {
            barProgress = countdown.progress
        }
    }

    private func fadeInSequence() async {
        let steps: [(Double, () -> Void)] = [
            (DSMotion.Onboarding.restFadeAt.seconds, { showRest = true }),
            (DSMotion.Onboarding.treeFadeAt.seconds, { showTree = true }),
            (DSMotion.Onboarding.footFadeAt.seconds, { showFoot = true }),
        ]
        var previous: Double = 0
        for (at, apply) in steps {
            try? await Task.sleep(for: .seconds(at - previous))
            previous = at
            withAnimation(DSMotion.animation(DSMotion.Onboarding.fadeIn, reduceMotion: false)) {
                apply()
            }
        }
    }
}
