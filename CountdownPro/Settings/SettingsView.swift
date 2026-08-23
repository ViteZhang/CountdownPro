import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CountdownKit
import CountdownStore
import DesignTokens

/// 设置页（需求文档 5.13 / 《V1 剩余页面》第二节）。
///
/// # 分组不加分组标题
/// 用间距分隔即可。加了标题这页会显得很"系统设置"，不符合产品调性。
///
/// # 心理支持资源为什么排在最后、且不加任何强调
/// 需求文档的措辞是「常驻但不显眼、可找到」。
/// 把它做成醒目入口，等于在用户还好好的时候反复暗示"你可能需要帮助"；
/// 做成弹窗或引导式提问，就成了没有资质的心理筛查。
/// 它该像图书馆书架上的一本书 —— 需要的人找得到，不需要的人不会被拦住。
///
/// **唯一的例外**：出分日前 3 天至后 14 天，它上移到第一项。
/// 那段时间要加强的是"找得到"，不是"显眼" —— 位置变了，样式一点没变，
/// 仍然不加红点、不推送、不弹窗。
struct SettingsView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme

    @Query private var accounts: [Account]
    @Query(filter: #Predicate<Exam> { $0.isPrimary }, sort: \Exam.createdAt)
    private var primaryExams: [Exam]

    @State private var exporting = false
    @State private var exportDocument: ExportDocument?
    @State private var toast: String?

    private let cal = DayCalendar.current
    private var flags: FlagStore { FlagStore(context: context, cal: cal) }
    private var palette: Palette { theme.palette }

    /// 出分日前后是否把心理支持提到第一项。
    private var mentalHealthFirst: Bool {
        guard let exam = primaryExams.first else { return false }
        let schedule = PostExamScheduleTable.schedule(
            examType: exam.type, province: exam.province, targetDate: exam.targetDate, cal: cal)
        return PostExamEngine(cal: cal).mentalHealthGoesFirst(
            resultDay: schedule.resultDay, today: .now)
    }

    private var notificationsSummary: String {
        flags.intValue(AppFlagKey.notificationsEnabled) == 1
            ? Strings.Settings.notificationsOn
            : Strings.Settings.notificationsOff
    }

    private var currentSkin: Skin {
        Skin(rawValue: flags.intValue(AppFlagKey.selectedSkin)) ?? .default
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                if mentalHealthFirst { mentalHealthGroup }

                SettingsGroup(palette: palette) {
                    NavigationLink { ExamListView() } label: {
                        SettingsRow(title: Strings.Settings.rowExams,
                                    value: primaryExams.first?.title, palette: palette)
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup(palette: palette) {
                    NavigationLink { AppearanceView() } label: {
                        SettingsRow(title: Strings.Settings.rowAppearance,
                                    value: currentSkin.displayName, palette: palette)
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup(palette: palette) {
                    NavigationLink { NotificationSettingsView() } label: {
                        SettingsRow(title: Strings.Settings.rowNotifications,
                                    value: notificationsSummary, palette: palette)
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup(palette: palette) {
                    // 账号。**未登录也必须能进** —— 账号是保险箱，不是入场券（D-10）。
                    NavigationLink { AccountView() } label: {
                        SettingsRow(title: Strings.Settings.rowAccount,
                                    value: accounts.isEmpty ? Strings.Settings.accountUnbound : nil,
                                    palette: palette)
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(palette.line.color)
                    Button(action: export) {
                        SettingsRow(title: Strings.Settings.rowExport, palette: palette)
                    }
                    .buttonStyle(.plain)
                }

                if !mentalHealthFirst { mentalHealthGroup }

                SettingsGroup(palette: palette) {
                    NavigationLink { AboutView() } label: {
                        SettingsRow(title: Strings.Settings.rowAbout, palette: palette)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSSpacing.pageHorizontalWide)
            .padding(.top, DSSpacing.md)
            .padding(.bottom, DSSpacing.xl)
        }
        .background(palette.background.color.ignoresSafeArea())
        .navigationTitle(Strings.Settings.title)
        .navigationBarTitleDisplayMode(.inline)
        .dsToast($toast, palette: palette)
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: SnapshotBuilder.fileName(cal: cal)
        ) { _ in
            // 成功与失败都不打断：导出失败时用户没有损失任何数据，本地记录仍在原处。
            // 「保存成功」在文案禁区里，所以这里也不冒充成功。
            exportDocument = nil
        }
    }

    /// 心理支持入口。**样式在两个位置上完全一致** ——
    /// 提到第一项时也不加图标、不加强调色、不加红点。
    private var mentalHealthGroup: some View {
        SettingsGroup(palette: palette) {
            NavigationLink { MentalHealthView() } label: {
                SettingsRow(title: Strings.Settings.rowMentalHealth, palette: palette)
            }
            .buttonStyle(.plain)
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
