import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CountdownKit
import CountdownStore
import DesignTokens

/// 设置页（需求文档 5.13）。
///
/// # 这一页几乎全部文案待补
/// 资料没有给设置页的任何一行字，所以这里每一行都走 `Strings.missing(_:)`，
/// 跑起来会是刺眼的 `⟪待补文案：…⟫`。**这是有意的** ——
/// 自拟一套看起来合理的设置项文案，会让这一页悄悄变成"已完成"，
/// 而它其实从没被产品确认过。清单见 DOCS/待补文案清单.md。
///
/// # 心理支持资源为什么排在最后、且不加任何强调
/// 需求文档的措辞是「常驻但不显眼、可找到」。
/// 把它做成醒目入口，等于在用户还好好的时候反复暗示"你可能需要帮助"；
/// 做成弹窗或引导式提问，就成了没有资质的心理筛查。
/// 它该像图书馆书架上的一本书 —— 需要的人找得到，不需要的人不会被拦住。
struct SettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @Query private var accounts: [Account]
    @Query private var letters: [Letter]
    @Query(filter: #Predicate<Exam> { $0.isPrimary }, sort: \Exam.createdAt)
    private var primaryExams: [Exam]

    @State private var notificationsOn = false
    @State private var exporting = false
    @State private var exportDocument: ExportDocument?
    @State private var toast: String?

    private let cal = DayCalendar.current
    private var flags: FlagStore { FlagStore(context: context, cal: cal) }
    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(Strings.Settings.title)
                    .dsFont(DSFont.title(DSType.screenTitle))
                    .foregroundStyle(palette.textPrimary.color)
                    .padding(.top, DSSpacing.sm + 2)

                VStack(spacing: DSSpacing.cardGap) {
                    row(Strings.Settings.rowExams) { toast = Strings.missing("考试管理页") }
                    row(Strings.Settings.rowSkins) { toast = Strings.missing("皮肤页") }
                    toggleRow(Strings.Settings.rowNotifications, isOn: $notificationsOn)
                    row(Strings.Settings.rowExport, action: export)
                }
                .padding(.top, DSSpacing.lg)

                // 账号。**未登录也必须能进** —— 账号是保险箱，不是入场券（D-10）。
                VStack(spacing: DSSpacing.cardGap) {
                    NavigationLink {
                        AccountView()
                    } label: {
                        rowLabel(accounts.isEmpty ? Strings.Settings.rowAccount
                                                  : Strings.Auth.accountTitle)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, DSSpacing.md)

                VStack(spacing: DSSpacing.cardGap) {
                    row(Strings.Settings.rowAbout) { toast = Strings.missing("关于页") }
                    row(Strings.Settings.rowPrivacy) { toast = Strings.missing("隐私政策页") }
                }
                .padding(.top, DSSpacing.md)

                // 不加图标、不加强调色、不置顶。见类型注释。
                Button {
                    toast = Strings.Settings.mentalHealthContent
                } label: {
                    Text(Strings.Settings.rowMentalHealth)
                        .dsFont(DSFont.body(DSType.caption))
                        .foregroundStyle(palette.textTertiary.color)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, DSSpacing.xl)

                Spacer(minLength: DSSpacing.xl)
            }
            .padding(.horizontal, DSSpacing.pageHorizontalWide)
        }
        .background(palette.background.color.ignoresSafeArea())
        .overlay(alignment: .top) { toastView }
        .task { notificationsOn = flags.isSet(AppFlagKey.notificationsEnabled) }
        .onChange(of: notificationsOn) { _, on in applyNotificationSetting(on) }
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: SnapshotBuilder.fileName(cal: cal)
        ) { _ in
            // 成功与失败都不打断：导出失败时用户没有损失任何数据，
            // 本地记录仍在原处。文案待补，暂不冒充成功。
            exportDocument = nil
        }
    }

    // MARK: - 导出

    /// 数据导出（5.13）。**即使有账号也必须提供** —— 用户应能把自己的记录带走。
    private func export() {
        guard let data = try? SnapshotBuilder(context: context).exportJSON() else {
            toast = Strings.missing("数据导出失败提示")
            return
        }
        exportDocument = ExportDocument(data: data)
        exporting = true
        // 登录价值时刻之一：主动导出说明用户在意这份数据，此时提"存一份到云端"才成立。
        flags.set(AppFlagKey.didRequestExport)
    }

    // MARK: - 通知

    private func applyNotificationSetting(_ on: Bool) {
        flags.set(AppFlagKey.notificationsEnabled, value: on ? 1 : 0)
        guard let exam = primaryExams.first else { return }

        let scheduler = NotificationScheduler()
        guard on else {
            scheduler.cancelAll()
            return
        }
        let inputs = letters.map {
            LetterNotificationInput(id: $0.id, writtenAt: $0.writtenAt, openAt: $0.openAt,
                                    trigger: $0.openTrigger, isOpened: $0.isOpened,
                                    isDraft: $0.isDraft)
        }
        Task {
            // 权限未决时在这里问是合理的 —— 用户刚刚**主动**打开了开关。
            // 与 5.11 禁止的"首次启动就问"是两回事。
            if await scheduler.authorizationStatus() == .notDetermined {
                await scheduler.requestAuthorization()
                flags.set(AppFlagKey.notificationPermissionAsked)
            }
            await scheduler.reschedule(targetDate: exam.targetDate, letters: inputs, cal: cal)
        }
    }

    // MARK: - 行

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { rowLabel(title) }.buttonStyle(.plain)
    }

    private func rowLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.textPrimary.color)
            Spacer()
            Text("›")
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.textTertiary.color)
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .fill(palette.surface.color)
        )
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .dsFont(DSFont.body(DSType.bodyLarge))
                .foregroundStyle(palette.textPrimary.color)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .fill(palette.surface.color)
        )
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .dsFont(DSFont.body(DSType.caption))
                .foregroundStyle(palette.background.color)
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
                .background(
                    Capsule().fill(palette.textPrimary.color.opacity(0.92))
                )
                .padding(.top, DSSpacing.lg)
                .transition(.opacity)
                .task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { self.toast = nil }
                }
        }
    }
}

/// 导出文件。只读取已经生成好的 JSON，不参与任何序列化决策 ——
/// 快照的构造只有 `SnapshotBuilder` 一个入口（导出与同步共用）。
struct ExportDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
