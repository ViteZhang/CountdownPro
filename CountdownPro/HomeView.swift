import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import CountdownUI
import DesignTokens
import WidgetKit

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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var checkIns: [CheckIn]
    @Query private var notes: [Note]
    @Query private var letters: [Letter]

    @State private var showingNoteSheet = false
    @State private var toast: String?

    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    private let cal = DayCalendar.current
    private var display: DateDisplay { DateDisplay(cal: cal) }

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
            shownMilestoneDays: [],
            previousTotalCheckIns: checkIns.count,
            cal: cal
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                ring.padding(.top, DSSpacing.xs)
                treeCard.padding(.top, DSSpacing.sm - 2)
                statCards.padding(.top, DSSpacing.cardGap)
                checkInButton.padding(.top, DSSpacing.md + 2)
                letterHint
                census
            }
            .padding(.horizontal, DSSpacing.pageHorizontal)
            .padding(.bottom, DSSpacing.lg)
        }
        .background(palette.background.color.ignoresSafeArea())
        .sheet(isPresented: $showingNoteSheet) {
            NoteSheetView(palette: palette) { text in
                CheckInService(context: context, cal: cal).addNote(text)
            }
            .presentationDetents([.height(320)])
        }
        .overlay(alignment: .top) { toastView }
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
            // 设置放首页右上角（信息架构第 3 章）
            Button {
                toast = Strings.missing("设置页（开发顺序后续接入）")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .light))
                    .foregroundStyle(palette.textSecondary.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Strings.Settings.title)
        }
        .padding(.top, DSSpacing.sm + 2)
    }

    // MARK: - 进度环

    private var ring: some View {
        let c = summary.countdown
        return DSRingView(progress: c.progress, palette: palette) {
            VStack(spacing: 0) {
                Text(centerNumber(c))
                    .dsFont(DSFont.display(DSType.ringNumber))
                    .foregroundStyle(palette.textPrimary.color)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(Strings.Home.ringSubtitle)
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
        .accessibilityLabel(
            "\(Strings.Home.passed(c.daysPassed))，\(Strings.Onboarding.resultRemaining(c.daysRemaining))"
        )
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

    /// 考试当天中心显示「今天」（5.2 边界情况），不显示 0。
    private func centerNumber(_ c: Countdown) -> String {
        c.isExamDay ? Strings.Home.today : "\(abs(c.daysRemaining))"
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
            Text(toast)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(palette.textPrimary.color)
                .padding(.horizontal, DSSpacing.lg - 4)
                .padding(.vertical, DSSpacing.sm + 2)
                .background(palette.surfaceRaised.color, in: Capsule())
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
}
