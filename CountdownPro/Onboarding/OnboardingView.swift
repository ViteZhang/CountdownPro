import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens
import WidgetKit

/// 首次启动引导（需求文档 5.1）。
///
/// # 这个文件不 import 任何账号 / 登录模块，这是有意的
/// 设计决策 D-10：**首次启动引导中不得出现任何登录入口。**
/// 用户必须能在零成本下走完引导、看到那个数字、用上小组件。
/// 想在这里加登录，得先加一行 import —— 那一行在 review 里很显眼。
///
/// # 同样不做的事
/// 不请求任何权限（通知、相册）。不问年级、地区、目标院校。
struct OnboardingView: View {

    let onFinish: (Exam) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    private let model = OnboardingModel(cal: .current)
    private let cal = DayCalendar.current

    @State private var state: OnboardingState?
    @State private var today = Date()

    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        ZStack {
            palette.background.color.ignoresSafeArea()

            if let state {
                VStack(spacing: 0) {
                    if state.step.showsNavigation {
                        navigationBar(state)
                    }
                    stepContent(state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            if state == nil {
                today = Date()
                state = model.initial(today: today)
            }
        }
    }

    // MARK: - 顶部导航

    private func navigationBar(_ state: OnboardingState) -> some View {
        HStack {
            Button {
                withAnimation(.none) { self.state = model.back(state) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .buttonStyle(.plain)
            .opacity(state.step.showsBackButton ? 1 : 0)
            .disabled(!state.step.showsBackButton)
            .frame(width: 28, alignment: .leading)
            .accessibilityLabel("返回")

            Spacer()

            // 步骤指示器：前 n 个点亮
            HStack(spacing: 6) {
                ForEach(OnboardingState.Step.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= state.litStepCount
                              ? palette.textPrimary.color : palette.line.color)
                        .frame(width: 18, height: 2)
                }
            }

            Spacer()

            // 「跳过」= 按当前默认值走完全部三屏，但**仍进入第 4 屏** ——
            // 必须让用户看到那个数字。
            Button {
                self.state = model.skip(state, today: today)
            } label: {
                Text(Strings.Common.skip)
                    .dsFont(DSFont.caption(12.5))
                    .foregroundStyle(palette.textTertiary.color)
            }
            .buttonStyle(.plain)
            .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, DSSpacing.lg)
        .frame(height: 52)
    }

    // MARK: - 分屏

    @ViewBuilder
    private func stepContent(_ state: OnboardingState) -> some View {
        switch state.step {
        case .type:
            OnboardingTypeStep(palette: palette) { type in
                self.state = model.selectType(type, today: today)
            }
        case .target:
            OnboardingTargetStep(
                state: state, model: model, palette: palette, today: today,
                onChange: { self.state = $0 },
                onContinue: { self.state = model.next(state, today: today) }
            )
        case .start:
            OnboardingStartStep(
                state: state, model: model, palette: palette, today: today,
                onChange: { self.state = $0 },
                onFinish: { self.state = model.next(state, today: today) }
            )
        case .result:
            OnboardingResultStep(
                countdown: model.result(state, today: today),
                palette: palette
            ) {
                persist(state)
            }
        }
    }

    /// 引导结束时才落库。中途退出不留半成品数据。
    private func persist(_ state: OnboardingState) {
        let exam = Exam(
            type: state.examType,
            title: Strings.Onboarding.typeName(state.examType),
            startDate: state.startDate,
            targetDate: state.targetDate,
            isPrimary: true
        )
        context.insert(exam)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        onFinish(exam)
    }
}
