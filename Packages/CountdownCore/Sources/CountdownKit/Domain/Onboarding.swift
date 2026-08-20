import Foundation

/// 首次启动引导的状态（需求文档 5.1）。
///
/// # 验收标准
/// 全流程 ≤ 4 屏，可在 30 秒内完成；跳过任何可选项后仍能进入首页。
///
/// # 这个流程里绝对不做的事
/// - **不出现任何登录入口**（D-10）。注册墙出现在用户还没获得任何价值的那一刻，
///   会砍掉大量首启转化，而这个人群对"要注册"格外反感。
/// - 不请求任何权限（通知、相册）。权限在实际需要时才请求。
/// - 不问年级、地区、目标院校 —— 每多一问，流失一截。
public struct OnboardingState: Equatable, Sendable {

    public enum Step: Int, CaseIterable, Sendable {
        case type = 1
        case target
        case start
        case result

        /// 第 4 屏隐藏顶部导航：无返回、无跳过。
        /// 「不可跳过 —— 全产品唯一一次允许强制观看」。
        public var showsNavigation: Bool { self != .result }
        /// 第 1 屏无处可返回；第 4 屏不允许回头。
        public var showsBackButton: Bool { self != .type && self != .result }
    }

    public var step: Step
    public var examType: ExamType
    public var targetDate: Date
    public var startDate: Date
    /// 起始日期是用户主动选的还是默认带出来的。仅用于埋点
    /// （`onboard_start_source`：改动比例高说明默认值不准）。
    public var startSource: StartSource

    public enum StartSource: String, Sendable {
        case `default`
        case quick
        case manual
    }

    /// 步骤指示器：前 n 个点亮。
    public var litStepCount: Int { step.rawValue }
}

public struct OnboardingModel: Sendable {

    public let cal: DayCalendar
    public let dates: DefaultDates

    public init(cal: DayCalendar = .current) {
        self.cal = cal
        self.dates = DefaultDates(cal: cal)
    }

    /// 初始状态。默认选中高考 —— 主用户是高三在读学生。
    public func initial(today: Date) -> OnboardingState {
        state(for: .gaokao, today: today, step: .type)
    }

    private func state(for type: ExamType, today: Date, step: OnboardingState.Step) -> OnboardingState {
        let target = dates.targetDate(for: type, today: today) ?? dates.customPickerSeed(today: today)
        return OnboardingState(
            step: step,
            examType: type,
            targetDate: target,
            startDate: dates.startDate(for: type, targetDate: target, today: today),
            startSource: .default
        )
    }

    // MARK: - 第 1 屏

    /// 选中考试类型。
    ///
    /// **选中即前进，不设「继续」按钮** —— 少一次点击。
    /// 同时重算后面两屏的默认值：一步定型。
    public func selectType(_ type: ExamType, today: Date) -> OnboardingState {
        state(for: type, today: today, step: .target)
    }

    // MARK: - 第 2 屏

    /// 修改目标日期。
    ///
    /// 注意**不联动重算起始日期** —— 用户改考试日期不代表他想改起点。
    /// 若因此造成 起始 ≥ 目标，第 3 屏的校验会拦下来。
    public func setTarget(_ date: Date, in state: OnboardingState) -> OnboardingState {
        var next = state
        next.targetDate = cal.startOfDay(date)
        return next
    }

    /// 一键「改成 N 年」。保留月日，年份 +1。
    public func rollTargetToNextYear(in state: OnboardingState) -> OnboardingState {
        var next = state
        next.targetDate = dates.rollTargetToNextYear(state.targetDate)
        return next
    }

    public func targetIssue(in state: OnboardingState, today: Date) -> DefaultDates.TargetIssue? {
        dates.validateTarget(state.targetDate, today: today)
    }

    /// 日期已过期时「继续」置灰。
    public func canLeaveTargetStep(_ state: OnboardingState, today: Date) -> Bool {
        targetIssue(in: state, today: today) == nil
    }

    // MARK: - 第 3 屏

    public func setStart(_ date: Date, source: OnboardingState.StartSource, in state: OnboardingState) -> OnboardingState {
        var next = state
        next.startDate = cal.startOfDay(date)
        next.startSource = source
        return next
    }

    public func quickStarts(in state: OnboardingState, today: Date) -> [DefaultDates.QuickStart] {
        dates.quickStarts(for: state.examType, targetDate: state.targetDate, today: today)
    }

    public func startIssue(in state: OnboardingState, today: Date) -> DefaultDates.StartIssue? {
        dates.validateStart(state.startDate, target: state.targetDate, today: today)
    }

    /// 「好了」是否可点。
    ///
    /// - 起始 ≥ 目标 → **阻断**，按钮置灰。
    /// - 起始 > 今天 → 提醒「已走过会是 0 天」，但**允许继续**。
    ///   不强制用开学日 —— 复读生、在职考生的起点不一样。
    public func canFinish(_ state: OnboardingState, today: Date) -> Bool {
        startIssue(in: state, today: today) != .notBeforeTarget
    }

    // MARK: - 流程

    public func next(_ state: OnboardingState, today: Date) -> OnboardingState {
        var next = state
        switch state.step {
        case .type:   next.step = .target
        case .target: next.step = canLeaveTargetStep(state, today: today) ? .start : .target
        case .start:  next.step = canFinish(state, today: today) ? .result : .start
        case .result: break
        }
        return next
    }

    public func back(_ state: OnboardingState) -> OnboardingState {
        var next = state
        switch state.step {
        case .type, .result: break          // 第 1 屏无处可返回；第 4 屏不允许回头
        case .target:        next.step = .type
        case .start:         next.step = .target
        }
        return next
    }

    /// 跳过。
    ///
    /// 交付标注：「跳过」= 直接按当前（默认）值走完全部三屏，
    /// **跳过后仍进入第 4 屏 —— 必须让用户看到那个数字。**
    ///
    /// 注：onboarding 原型的 `skip()` 是一次只前进一屏，与标注文字不符。
    /// 这里按标注实现（跳过即直达第 4 屏），因为标注表达的是意图，
    /// 而"少问一句就少流失一截"正是这一屏的设计理由。
    ///
    /// 跳过时若默认值不合法（例如自定义考试没有默认目标日期），
    /// 则停在第一个不合法的那一屏，而不是带着坏数据进首页。
    public func skip(_ state: OnboardingState, today: Date) -> OnboardingState {
        var next = state
        guard canLeaveTargetStep(state, today: today) else {
            next.step = .target
            return next
        }
        guard canFinish(state, today: today) else {
            next.step = .start
            return next
        }
        next.step = .result
        return next
    }

    /// 第 4 屏要展示的数字。
    public func result(_ state: OnboardingState, today: Date) -> Countdown {
        CountdownEngine(cal: cal).countdown(
            startDate: state.startDate,
            targetDate: state.targetDate,
            today: today
        )
    }
}
