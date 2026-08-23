import SwiftUI
import UIKit
import SwiftData
import CountdownKit
import CountdownStore
import DesignTokens

/// 提醒二级页（《V1 剩余页面》2.2）。
///
/// # 只有两个开关，**没有每日提醒**
/// 不是"暂时没做"，是不做。这个人群的手机常被收走，每日提醒既是骚扰又无效
/// （和 D-03 不做连续打卡是同一条理由：不要惩罚一个正在认真备考的人）。
/// 加一个「每日提醒」开关，就等于承诺了一件我们不打算做、也不该做的事。
///
/// # 引导语是一份合同
/// 「我们一年只会打扰你几次。」这句话有测试盯着：
/// `NotificationPlanner.maxNonLetterNotificationsPerCycle` = 节点 5 条 + 考试当天 1 条。
/// 想加一个节点，先得去改那个上限，改的时候会看见理由。
struct NotificationSettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme

    @Query private var letters: [Letter]
    @Query(filter: #Predicate<Exam> { $0.isPrimary }, sort: \Exam.createdAt)
    private var primaryExams: [Exam]

    @State private var milestonesOn = true
    @State private var lettersOn = true
    @State private var systemDenied = false

    private let cal = DayCalendar.current
    private var palette: Palette { theme.palette }
    private var flags: FlagStore { FlagStore(context: context, cal: cal) }

    var body: some View {
        SettingsPage(title: Strings.Notifications.title, palette: palette) {
            Text(Strings.Notifications.intro)
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.textPrimary.color)
                .padding(.bottom, DSSpacing.xs)

            SettingsGroup(palette: palette) {
                SettingsToggleRow(title: Strings.Notifications.milestoneToggle,
                                  caption: Strings.Notifications.milestoneToggleCaption,
                                  isOn: $milestonesOn, palette: palette)
                Divider().overlay(palette.line.color)
                SettingsToggleRow(title: Strings.Notifications.letterToggle,
                                  caption: Strings.Notifications.letterToggleCaption,
                                  isOn: $lettersOn, palette: palette)
            }

            // 系统层面被关掉时，App 内的开关再打开也没用。
            // 这里只说明情况并给一条去路，**不反复弹窗、不拦住用户**。
            if systemDenied {
                Button {
                    openSystemSettings()
                } label: {
                    Text(Strings.Notifications.systemDenied)
                        .dsFont(DSFont.caption(DSType.caption))
                        .foregroundStyle(palette.textSecondary.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, DSSpacing.xs)
            }
        }
        .task { await load() }
        .onChange(of: milestonesOn) { _, _ in persistAndReschedule() }
        .onChange(of: lettersOn) { _, _ in persistAndReschedule() }
    }

    // MARK: -

    private func load() async {
        // 两个开关默认开：用户能走到这一页，说明通知已经被打开过。
        milestonesOn = flags.flag(AppFlagKey.notifyMilestones).map { $0.intValue == 1 } ?? true
        lettersOn = flags.flag(AppFlagKey.notifyLetters).map { $0.intValue == 1 } ?? true
        let status = await NotificationScheduler().authorizationStatus()
        systemDenied = (status == .denied)
    }

    private func persistAndReschedule() {
        flags.set(AppFlagKey.notifyMilestones, value: milestonesOn ? 1 : 0)
        flags.set(AppFlagKey.notifyLetters, value: lettersOn ? 1 : 0)
        // 两个都关掉等于关掉通知总开关 —— 让设置页首页那一行显示「已关闭」，
        // 而不是显示「已开启」但其实一条都不会来。
        flags.set(AppFlagKey.notificationsEnabled,
                  value: (milestonesOn || lettersOn) ? 1 : 0)

        guard let exam = primaryExams.first else { return }
        let inputs = letters.map {
            LetterNotificationInput(id: $0.id, writtenAt: $0.writtenAt, openAt: $0.openAt,
                                    trigger: $0.openTrigger, isOpened: $0.isOpened,
                                    isDraft: $0.isDraft)
        }
        let scheduler = NotificationScheduler()
        Task {
            await scheduler.reschedule(
                targetDate: exam.targetDate, letters: inputs,
                milestonesEnabled: milestonesOn, lettersEnabled: lettersOn, cal: cal
            )
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
