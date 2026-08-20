import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 根视图。
///
/// # 引导路径不得 import 任何账号 / 登录模块
/// 设计决策 D-10：**首次启动引导中不得出现任何登录入口。**
/// 注册墙出现在用户还没获得任何价值的那一刻，会砍掉大量首启转化，
/// 而这个人群对"要注册"格外反感。
///
/// 这里的分支结构就是那道物理隔离：`OnboardingView` 这一支下面挂不到任何 Auth 视图。
struct RootView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Query(filter: #Predicate<Exam> { $0.isPrimary }, sort: \Exam.createdAt)
    private var primaryExams: [Exam]

    var body: some View {
        Group {
            if let exam = primaryExams.first {
                MainTabView(exam: exam)
            } else {
                // 引导。这一支下面没有、也不会有任何登录入口。
                OnboardingView { _ in }
            }
        }
        .dsTheme(skin: .default, colorScheme: colorScheme)
    }
}

/// 已完成引导后的主界面。底部 Tab 三项（信息架构第 3 章）。
struct MainTabView: View {

    let exam: Exam

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Query private var checkIns: [CheckIn]
    @Query private var notes: [Note]
    @Query private var letters: [Letter]
    @Query private var accounts: [Account]

    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @State private var authPrompt: AuthPromptTrigger?
    @State private var showingAuthFlow = false

    private let cal = DayCalendar.current
    private var flags: FlagStore { FlagStore(context: context, cal: cal) }
    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(exam: exam) { selectedTab = 2 }
                .tabItem { Label(Strings.Tab.home, systemImage: "clock") }
                .tag(0)
            LogView(exam: exam)
                .tabItem { Label(Strings.Tab.log, systemImage: "calendar") }
                .tag(1)
            LettersView(exam: exam)
                .tabItem { Label(Strings.Tab.letters, systemImage: "envelope") }
                .tag(2)
        }
        // 价值时刻引导用**底部浮层**，不是全屏页 —— 不打断当前场景。
        .sheet(item: $authPrompt) { trigger in
            AuthPromptSheet(trigger: trigger, letterDays: nearestLetterDays, palette: palette) {
                markPromptShown(trigger)
                authPrompt = nil
                showingAuthFlow = true
            } onLater: {
                // 每个触发点一生只弹一次，关闭后不再重复。
                markPromptShown(trigger)
                authPrompt = nil
            }
            .presentationDetents([.height(260)])
        }
        .fullScreenCover(isPresented: $showingAuthFlow) {
            AuthFlowView(stats: .init(days: checkIns.count,
                                      notes: notes.count,
                                      sealedLetters: sealedLetterCount)) { account, isOver14 in
                persist(account, isOver14: isOver14)
            }
        }
        // 价值时刻由数据变化触发，而不是由某个按钮触发 ——
        // 这样"写完第一封信""累计满 7 天"在任何入口完成都能被捕捉到。
        .onChange(of: checkIns.count) { _, _ in evaluateAuthPrompt() }
        .onChange(of: sealedLetterCount) { _, _ in evaluateAuthPrompt() }
        // 导出发生在设置页里，回到主界面时才有机会弹 —— 不在导出当场打断分享面板。
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { evaluateAuthPrompt() }
        }
    }

    private var sealedLetterCount: Int {
        letters.filter { !$0.isDraft }.count
    }

    /// 最近一封未拆的信还要存多少天 —— `.firstLetter` 的定制文案要用。
    private var nearestLetterDays: Int {
        let pending = letters.filter { !$0.isDraft && !$0.isOpened }
        guard let nearest = pending.map(\.openAt).min() else { return 0 }
        return max(cal.days(from: .now, to: nearest), 0)
    }

    private func evaluateAuthPrompt() {
        guard authPrompt == nil, !showingAuthFlow else { return }
        let satisfied = AuthPromptResolver.satisfiedTriggers(
            sealedLetterCount: sealedLetterCount,
            totalCheckIns: checkIns.count,
            didRequestExport: flags.isSet(AppFlagKey.didRequestExport),
            isAfterExam: false
        )
        let shown = Set(AuthPromptTrigger.allCases.filter { flags.isSet($0.flagKey) })
        authPrompt = AuthPromptResolver.resolve(
            isSignedIn: !accounts.isEmpty,
            satisfied: satisfied,
            shownFlags: shown
        )
    }

    private func markPromptShown(_ trigger: AuthPromptTrigger) {
        flags.set(trigger.flagKey)
    }

    private func persist(_ account: AuthAccount, isOver14: Bool) {
        // 本地不存手机号明文，只保留后四位用于展示（需求文档 4.0 / 5.14.3）。
        let record = Account(uid: account.uid, bindType: account.bindType,
                             boundAt: account.boundAt,
                             phoneLastFour: account.phoneLastFour,
                             isOver14: isOver14)
        context.insert(record)
        try? context.save()
    }
}
