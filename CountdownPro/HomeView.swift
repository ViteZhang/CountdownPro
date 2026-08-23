import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import CountdownUI
import DesignTokens
import WidgetKit
import UIKit

/// 首页（需求文档 5.2）。
///
/// # 布局的唯一不可动摇之处
/// 环的**填充度 = progress（已走过比例）**，中心大数字是**剩余**天数，
/// 分割线之下必须有「你已走过 X 天」。
///
/// 设计决策 D-01：普通倒计时只给减法，数字每天变小，只有失去感 ——
/// 这是它既制造焦虑又留不住人的根本原因。同一块屏幕上必须同时存在加法。
/// 把填充改成打卡完成率，产品就退化成一个普通倒计时，其余设计全部失去意义。
struct HomeView: View {

    let exam: Exam
    var onOpenLetters: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var checkIns: [CheckIn]
    @Query private var notes: [Note]
    @Query private var letters: [Letter]

    @State private var showingNoteSheet = false
    @State private var toast: String?
    @State private var prompt: AppOpenPrompt?
    @State private var shareCards: [ShareCardKind: ShareCardContent]?
    @State private var shareInitialKind: ShareCardKind = .milestone
    @State private var readingLetter: Letter?
    @State private var resolvedPrompt = false
    @State private var showingSettings = false

    private var palette: Palette { theme.palette }

    private let cal = DayCalendar.current
    private var display: DateDisplay { DateDisplay(cal: cal) }
    private var flags: FlagStore { FlagStore(context: context, cal: cal) }
    private var cardBuilder: ShareCardBuilder { ShareCardBuilder(cal: cal) }

    private var summary: HomeSummary {
        HomeSummaryBuilder.build(
            examTitle: exam.title,
            startDate: exam.startDate,
            targetDate: exam.targetDate,
            today: .now,
            totalCheckIns: checkIns.count,
            totalNotes: notes.count,
            hasCheckedInToday: checkIns.contains { cal.isSameDay($0.date, .now) },
            letters: letters.map {
                LetterDigest(id: $0.id, writtenAt: $0.writtenAt, openAt: $0.openAt,
                             isOpened: $0.isOpened, isDraft: $0.isDraft)
            },
            censusCount: nil, // 由 CensusService 注入，未登录/无网络时保持 nil（D-09）
            shownMilestoneDays: flags.shownMilestoneDays(),
            previousTotalCheckIns: checkIns.count,
            cal: cal
        )
    }

    // MARK: - 考后接力（5.12）

    /// 考后日程。按省份内置，未填省份时走全国通用近似值。
    /// 拿不到的项**整段跳过**，不编日期 —— 见 `PostExamScheduleTable`。
    private var schedule: PostExamSchedule {
        PostExamScheduleTable.schedule(examType: exam.type, province: exam.province,
                                       targetDate: exam.targetDate, cal: cal)
    }

    /// 考后状态。`nil` = 还没考 / 或考后日程已全部走完。
    private var postExam: PostExamState? {
        PostExamEngine(cal: cal).state(targetDate: exam.targetDate,
                                       schedule: schedule, today: .now)
    }

    /// 打卡是否已冻结。
    ///
    /// **考试当天仍然可以打卡** —— 那一天正是最该说一句「今天也在」的日子。
    /// 冻结从考试次日开始：路走完了，这个动作就该停，
    /// 继续打卡会让它失去含义（6.4）。
    private var checkInFrozen: Bool { summary.countdown.isAfterExam }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                ring.padding(.top, DSSpacing.xs)
                treeCard.padding(.top, DSSpacing.sm - 2)
                statCards.padding(.top, DSSpacing.cardGap)
                if checkInFrozen {
                    frozenTotal.padding(.top, DSSpacing.md + 2)
                } else {
                    checkInButton.padding(.top, DSSpacing.md + 2)
                }
                letterHint
                census
            }
            .padding(.horizontal, DSSpacing.pageHorizontal)
            .padding(.bottom, DSSpacing.lg)
        }
        .background(palette.background.color.ignoresSafeArea())
        .sheet(isPresented: $showingNoteSheet) {
            NoteSheetView(palette: palette) { text in
                guard let note = CheckInService(context: context, cal: cal)
                    .addNote(text, examID: exam.id) else { return }
                // 5.3 第 5 步：写完保存 → 触发心里话分享卡入口（**不强制**）。
                openShareSheet(.note, note: note)
            }
            .presentationDetents([.height(320)])
        }
        .sheet(item: shareBinding) { box in
            ShareCardSheet(cards: box.cards, palette: palette, initialKind: shareInitialKind)
        }
        .fullScreenCover(item: $prompt) { prompt in
            promptView(prompt)
        }
        .fullScreenCover(item: $readingLetter) { letter in
            LetterReadView(letter: letter, palette: palette)
        }
        .task {
            resolvePrompt()
            showPostExamNoticeIfDue()
        }
        .overlay(alignment: .top) { toastView }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
    }

    // MARK: - 顶部栏

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(exam.title)
                    .dsFont(DSFont.title(DSType.navTitle))
                    .foregroundStyle(palette.textPrimary.color)
                Text(display.longWithWeekday(exam.targetDate))
                    .dsFont(DSFont.caption(DSType.navSubtitle))
                    .foregroundStyle(palette.textSecondary.color)
            }
            Spacer()
            HStack(spacing: DSSpacing.md) {
                // 5.8.2：用户可随时在首页右上角手动生成任意类型卡片。
                // 注：信息架构第 3 章把设置也放在右上角，两者并存于此。
                Button { openShareSheet(.milestone) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(palette.textSecondary.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.ShareCard.share)

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(palette.textSecondary.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Strings.Settings.title)
            }
        }
        .padding(.top, DSSpacing.sm + 2)
    }

    // MARK: - 进度环

    private var ring: some View {
        let c = summary.countdown
        // 考后每切换一个阶段，环**重新从 0 填充**（6.1）：
        // 这是新的一段路，不是旧进度的延续。
        // 铺成"从考试日到开学日的总进度"会让等出分那两周的环几乎不动，
        // 而那恰好是最需要看见"在走"的两周。
        let state = postExam
        let progress = state.map { $0.phase == .examDay ? 1 : $0.progress } ?? c.progress
        return DSRingView(progress: progress, palette: palette) {
            VStack(spacing: 0) {
                Text(centerNumber(c))
                    .dsFont(DSFont.display(DSType.ringNumber))
                    .foregroundStyle(palette.textPrimary.color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(ringSubtitle)
                    .dsFont(DSFont.caption(DSType.ringCaption))
                    .foregroundStyle(palette.textSecondary.color)
                    .padding(.top, 2)

                Rectangle()
                    .fill(palette.line.color)
                    .frame(width: 92, height: DSStroke.hairline)
                    .padding(.vertical, DSSpacing.md)

                // 这一行**必须存在**（5.2）。它是 D-01 在首页上的落点。
                Text(Strings.Home.passed(c.daysPassed))
                    .dsFont(DSFont.caption(DSType.ringCaption))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .padding(.horizontal, DSSpacing.xl)
        }
        .frame(width: 252, height: 252)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ringAccessibilityLabel)
    }

    /// 环内副文案。考前是「天后见分晓」，考后按阶段换成「天后出分」等。
    private var ringSubtitle: String {
        guard let state = postExam else { return Strings.Home.ringSubtitle }
        switch state.phase {
        case .examDay:
            return Strings.PostExam.examDayCaption(totalDays: summary.countdown.daysPassed)
        default:
            return state.caption ?? Strings.Home.ringSubtitle
        }
    }

    private var ringAccessibilityLabel: String {
        let c = summary.countdown
        guard let state = postExam, state.phase != .examDay else {
            return "\(Strings.Home.passed(c.daysPassed))，\(ringSubtitle)"
        }
        return "\(state.daysRemaining)\(Strings.Common.day)\(ringSubtitle)"
    }

    /// 提示条三选一，优先级：今天到期 > 草稿未完成 > 即将开启（信件文案表第 8 节）。
    private func hintText(_ hint: LetterHint) -> String {
        switch hint {
        case .dueToday:
            return Strings.Home.letterHintDueToday
        case .draftInProgress:
            return Strings.Home.letterHintDraft
        case .upcoming(let writtenDaysAgo, let inDays):
            return Strings.Home.letterHintUpcoming(writtenDaysAgo: writtenDaysAgo, inDays: inDays)
        }
    }

    /// 中心大数字。
    ///
    /// 考试当天显示「今天」（5.2 边界情况 / 6.1），**不显示 0** ——
    /// 0 会被读成"结束了"，而那一天恰恰什么都还没开始。
    /// 考后各阶段显示的是**本阶段**剩余天数，不是考试日的负数。
    private func centerNumber(_ c: Countdown) -> String {
        if c.isExamDay { return Strings.PostExam.examDayBigWord }
        if let state = postExam { return "\(state.daysRemaining)" }
        return "\(abs(c.daysRemaining))"
    }

    /// 考后取代打卡按钮的那一块。
    ///
    /// **累计数字冻结并永久保留。** 打卡的意义是"陪你走完这段路"，
    /// 路走完了就该停 —— 继续打卡会让这个动作失去含义（6.4）。
    ///
    /// 注意这里是一段陈述，不是一个禁用掉的按钮：
    /// 灰掉的按钮会让人一直想去点它，然后每点一次都被拒绝一次。
    private var frozenTotal: some View {
        VStack(spacing: DSSpacing.xs) {
            Text(Strings.PostExam.frozenTotal(summary.totalCheckIns))
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.textPrimary.color)
            Text(Strings.PostExam.frozenCaption)
                .dsFont(DSFont.caption(DSType.caption))
                .foregroundStyle(palette.textSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.md)
    }

    // MARK: - 成长物

    private var treeCard: some View {
        DSCard(palette: palette) {
            HStack(spacing: DSSpacing.md - 1) {
                TreeView(stage: summary.countdown.growthStage, color: palette.tree)
                    .frame(width: 40, height: 46)
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(Strings.Home.treeCaption)
                        .dsFont(DSFont.body(13))
                        .foregroundStyle(palette.textPrimary.color)
                    // 已确认：只展示阶段名，不带序号。
                    Text(summary.countdown.growthStage.displayName)
                        .dsFont(DSFont.caption(DSType.captionSmall))
                        .foregroundStyle(palette.textSecondary.color)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - 数据卡

    /// 需求文档 5.2 明确：**「累计投入 X 小时」V1 不做** ——
    /// 它需要用户记录学习时长，与「不做计划管理」原则冲突，且高中生无法准确记录。
    private var statCards: some View {
        HStack(spacing: DSSpacing.cardGap) {
            statCard(label: Strings.Home.statDaysLabel,
                     value: summary.totalCheckIns, unit: Strings.Home.statDaysUnit)
            statCard(label: Strings.Home.statNotesLabel,
                     value: summary.totalNotes, unit: Strings.Home.statNotesUnit)
        }
    }

    private func statCard(label: String, value: Int, unit: String) -> some View {
        DSCard(palette: palette) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .dsFont(DSFont.caption(DSType.statLabel))
                    .foregroundStyle(palette.textSecondary.color)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(value)")
                        .dsFont(DSFont.title(DSType.statNumber))
                        .foregroundStyle(palette.textPrimary.color)
                    Text(unit)
                        .dsFont(DSFont.caption(DSType.caption))
                        .foregroundStyle(palette.textSecondary.color)
                }
            }
        }
    }

    // MARK: - 主 CTA

    /// 设计决策 D-02：叫「今天也在」，不叫「打卡」。
    /// 打卡是任务，会制造"又欠了一天"的负债感；「今天也在」是陪伴的口吻。
    private var checkInButton: some View {
        DSPrimaryButton(
            title: Strings.Home.checkIn,
            palette: palette,
            isDone: summary.hasCheckedInToday
        ) {
            handleCheckIn()
        }
    }

    private func handleCheckIn() {
        let service = CheckInService(context: context, cal: cal)
        switch service.checkInToday(examID: exam.id) {
        case .recorded:
            WidgetCenter.shared.reloadAllTimelines()
            requestNotificationPermissionIfDue()
            // 打卡后**立即**弹心里话输入（5.3 第 3 步），不是另一个流程。
            DispatchQueue.main.asyncAfter(deadline: .now() + DSMotion.stateChange.seconds) {
                showingNoteSheet = true
            }
        case .alreadyRecorded:
            // 不是错误。温和地说一句就够了。
            toast = Strings.Home.alreadyCheckedIn
        case .outsideBackfillWindow:
            break
        }
    }

    /// 通知权限的请求时机（5.11）：**第一次打卡之后**，绝不在首次启动时。
    ///
    /// 引导里问权限，用户还没体会到通知有什么用，拒绝率高 ——
    /// 而 iOS 的系统弹窗一生只出现一次，拒了就再没有第二次机会。
    /// 刚打完卡的那一刻，用户刚做了一件和这个 App 有关的事，这时问才有依据。
    private func requestNotificationPermissionIfDue() {
        let flags = FlagStore(context: context, cal: cal)
        guard NotificationPermissionPolicy.shouldRequest(
            hasCheckedInAtLeastOnce: true,
            alreadyAsked: flags.isSet(AppFlagKey.notificationPermissionAsked)
        ) else { return }

        flags.set(AppFlagKey.notificationPermissionAsked)
        let inputs = letters.map {
            LetterNotificationInput(id: $0.id, writtenAt: $0.writtenAt, openAt: $0.openAt,
                                    trigger: $0.openTrigger, isOpened: $0.isOpened,
                                    isDraft: $0.isDraft)
        }
        let targetDate = exam.targetDate
        Task {
            let scheduler = NotificationScheduler()
            guard await scheduler.requestAuthorization() else { return }
            flags.set(AppFlagKey.notificationsEnabled, value: 1)
            await scheduler.reschedule(targetDate: targetDate, letters: inputs, cal: cal)
        }
    }

    // MARK: - 底部

    @ViewBuilder
    private var letterHint: some View {
        if let hint = summary.letterHint {
            DSHintBar(text: hintText(hint), systemImage: "envelope", palette: palette) {
                onOpenLetters()
            }
            .padding(.top, DSSpacing.cardGapWide)
        }
    }

    /// 同考人数。**拉不到时整块隐藏**，不显示错误态、不显示占位骨架（5.7 / D-09）。
    /// `censusDisplay` 对「不足 1 万」和「拉不到」返回同一个 nil，这里也就无从区分。
    @ViewBuilder
    private var census: some View {
        if let census = summary.censusDisplay {
            Text(Strings.Home.together(census))
                .dsFont(DSFont.caption(11.5))
                .foregroundStyle(palette.textTertiary.color)
                .padding(.top, DSSpacing.cardGapWide)
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            // 胶囊改成圆角卡：保存失败那几句要说清"怎么办"，一行放不下，
            // 胶囊里换行会挤成一坨。
            Text(toast)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(palette.textPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.lg - 4)
                .padding(.vertical, DSSpacing.sm + 2)
                .background(palette.surfaceRaised.color,
                            in: RoundedRectangle(cornerRadius: DSRadius.card - 1))
                .padding(.horizontal, DSSpacing.pageHorizontalWide)
                .padding(.top, DSSpacing.xl)
                .transition(.opacity)
                .task {
                    try? await Task.sleep(for: .seconds(DSMotion.toast.seconds))
                    withAnimation(DSMotion.animation(DSMotion.stateChange, reduceMotion: reduceMotion)) {
                        self.toast = nil
                    }
                }
        }
    }

    // MARK: - 分享卡

    /// `sheet(item:)` 需要一个 Identifiable 包装。
    private struct ShareBox: Identifiable {
        let id = UUID()
        let cards: [ShareCardKind: ShareCardContent]
    }

    private var shareBinding: Binding<ShareBox?> {
        Binding(
            get: { shareCards.map(ShareBox.init(cards:)) },
            set: { if $0 == nil { shareCards = nil } }
        )
    }

    private func openShareSheet(_ kind: ShareCardKind, note: Note? = nil) {
        let c = summary.countdown
        var cards: [ShareCardKind: ShareCardContent] = [
            .milestone: cardBuilder.milestone(examTitle: exam.title, countdown: c)
        ]
        if let note {
            cards[.note] = cardBuilder.note(
                content: note.content, date: note.date,
                nthCheckInDay: summary.totalCheckIns, countdown: c,
                censusDisplay: summary.censusDisplay
            )
        }
        if c.isExamDay || c.isAfterExam {
            cards[.zero] = cardBuilder.zero(
                examDate: exam.targetDate, countdown: c,
                totalCheckIns: summary.totalCheckIns, totalNotes: summary.totalNotes
            )
        }
        shareInitialKind = cards[kind] != nil ? kind : .milestone
        shareCards = cards
    }

    // MARK: - 开屏全屏提示

    /// 打开 App 时最多弹一个。**信件优先于分享卡** —— 信是不可重建的。
    private func resolvePrompt() {
        guard !resolvedPrompt else { return }
        resolvedPrompt = true
        prompt = AppOpenPromptResolver.resolve(
            countdown: summary.countdown,
            letters: letters.map {
                LetterDigest(id: $0.id, writtenAt: $0.writtenAt, openAt: $0.openAt,
                             isOpened: $0.isOpened, isDraft: $0.isDraft)
            },
            deferredLetterIDs: flags.lettersDeferredToday(letterIDs: letters.map(\.id)),
            shownMilestoneDays: flags.shownMilestoneDays(),
            today: .now,
            cal: cal
        )
    }

    @ViewBuilder
    private func promptView(_ prompt: AppOpenPrompt) -> some View {
        switch prompt {
        case .letterDue(let letterID, let writtenDaysAgo):
            LetterDuePromptView(writtenDaysAgo: writtenDaysAgo, palette: palette) {
                self.prompt = nil
                readingLetter = letters.first { $0.id == letterID }
            } onLater: {
                // 当天不再弹，次日再触发，直到被拆开。
                flags.deferLetterPrompt(letterID: letterID)
                self.prompt = nil
            }

        case .milestoneCard(let daysRemaining):
            let content = cardBuilder.milestone(examTitle: exam.title, countdown: summary.countdown)
            MilestonePromptView(
                content: content,
                palette: palette,
                dateText: display.dotted(.now),
                onToast: { toast = $0 }
            ) {
                // 每个节点只触发一次，用户关闭后不再重复弹出。
                // 保存成功后也走这里 —— 这一屏已经没有别的事可做了。
                markMilestoneShown(daysRemaining)
                self.prompt = nil
            }
        }
    }

    private func markMilestoneShown(_ daysRemaining: Int) {
        flags.set(Milestone(daysRemaining: daysRemaining).flagKey)
    }

    /// 阶段切换提示（6.2）。每条一生只出现一次，且只用 Toast ——
    /// **不做全屏**。开屏最多弹一个全屏提示，那一个已经被信件和节点卡占着了，
    /// 再加一个，用户会在同一天连吃两个全屏。
    private func showPostExamNoticeIfDue() {
        guard let state = postExam,
              let notice = state.notice,
              let key = state.noticeFlagKey,
              !flags.isSet(key)
        else { return }
        flags.set(key)
        toast = notice.text
    }
}
