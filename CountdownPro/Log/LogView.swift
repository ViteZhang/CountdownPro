import SwiftUI
import SwiftData
import CountdownKit
import CountdownStore
import CountdownUI
import DesignTokens

/// 记录页（需求文档 5.5）。日历 / 心里话两个视图，顶部切换。
struct LogView: View {

    let exam: Exam

    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme

    @Query(sort: \CheckIn.date) private var checkIns: [CheckIn]
    @Query(sort: [SortDescriptor(\Note.date, order: .reverse),
                  SortDescriptor(\Note.createdAt, order: .reverse)]) private var notes: [Note]

    @State private var showingCalendar = true
    @State private var anchor = Date()
    @State private var toast: String?
    @State private var pendingBackfill: CalendarMonth.Day?
    @State private var pendingDelete: Note?
    /// 长按 →「做成卡片」。5.8.1 把记录页长按列为心里话卡的入口之一，
    /// 之前这句文案定义了却没有任何地方用到 —— 入口是缺的。
    @State private var cardForNote: ShareCardContent?

    private let cal = DayCalendar.current
    private var display: DateDisplay { DateDisplay(cal: cal) }
    /// 皮肤走环境。这里曾经写死 `.default` —— 于是换了皮肤，记录页是唯一不跟着变的一页。
    private var palette: Palette { theme.palette }

    private var countdown: Countdown {
        CountdownEngine(cal: cal).countdown(
            startDate: exam.startDate, targetDate: exam.targetDate, today: .now
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            segmented
            summaryBar

            if showingCalendar {
                ScrollView { calendarView.padding(.bottom, DSSpacing.lg) }
            } else {
                timelineView
            }
        }
        .padding(.horizontal, DSSpacing.pageHorizontal)
        .background(palette.background.color.ignoresSafeArea())
        .overlay(alignment: .top) { toastView }
        .confirmationDialog(
            pendingBackfill.map { Strings.Log.backfillConfirmTitle(display.short($0.date)) } ?? "",
            isPresented: backfillDialogBinding, titleVisibility: .visible
        ) {
            Button(Strings.Log.backfillConfirmAction) {
                if let day = pendingBackfill { backfill(day) }
                pendingBackfill = nil
            }
            Button(Strings.Common.cancel, role: .cancel) { pendingBackfill = nil }
        } message: {
            Text(Strings.Log.backfillConfirmBody)
        }
        .sheet(item: cardBinding) { box in
            ShareCardSheet(cards: [.note: box.content], palette: palette, initialKind: .note)
        }
        .confirmationDialog(
            Strings.Log.deleteNoteTitle,
            isPresented: deleteDialogBinding, titleVisibility: .visible
        ) {
            Button(Strings.Log.deleteNoteConfirm, role: .destructive) {
                if let note = pendingDelete {
                    CheckInService(context: context, cal: cal).deleteNote(note)
                }
                pendingDelete = nil
            }
            Button(Strings.Log.deleteNoteCancel, role: .cancel) { pendingDelete = nil }
        } message: {
            Text(Strings.Log.deleteNoteBody)
        }
    }

    private var backfillDialogBinding: Binding<Bool> {
        Binding(get: { pendingBackfill != nil }, set: { if !$0 { pendingBackfill = nil } })
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    /// `sheet(item:)` 要一个 Identifiable 包装。
    private struct CardBox: Identifiable {
        let id = UUID()
        let content: ShareCardContent
    }

    private var cardBinding: Binding<CardBox?> {
        Binding(get: { cardForNote.map(CardBox.init(content:)) },
                set: { if $0 == nil { cardForNote = nil } })
    }

    /// 心里话卡。
    ///
    /// 全部数字取**那句话写下的那天**，不是今天：时间线上可以给三个月前的一句话做卡，
    /// 用今天的天数配那天的话，卡上就是一句对不上的记录。
    ///
    /// `censusDisplay` 传 nil：同考人数只有首页在拉，记录页手里没有。
    /// 与其为了这一行补一次请求，不如整行不出现 —— D-09 的规则本来就是
    /// 「拿不到就整块隐藏」，而分享出去的图更不能带一个来路不明的数字。
    private func makeCard(for note: Note) -> ShareCardContent {
        let day = cal.startOfDay(note.date)
        return ShareCardBuilder(cal: cal).note(
            content: note.content,
            date: note.date,
            nthCheckInDay: checkIns.filter { $0.date <= day }.count,
            countdown: CountdownEngine(cal: cal).countdown(
                startDate: exam.startDate, targetDate: exam.targetDate, today: note.date),
            censusDisplay: nil
        )
    }

    private var header: some View {
        HStack {
            Text(Strings.Log.title)
                .dsFont(DSFont.title(DSType.navTitle))
                .foregroundStyle(palette.textPrimary.color)
            Spacer()
        }
        .padding(.top, DSSpacing.sm + 2)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            segment(Strings.Log.segmentCalendar, active: showingCalendar) { showingCalendar = true }
            segment(Strings.Log.segmentNotes, active: !showingCalendar) { showingCalendar = false }
        }
        .padding(3)
        .background(palette.surface.color, in: RoundedRectangle(cornerRadius: DSRadius.segmentTrack))
        .padding(.top, DSSpacing.md)
    }

    private func segment(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(active ? palette.textPrimary.color : palette.textSecondary.color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.sm)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: DSRadius.segmentThumb)
                            .fill(palette.surfaceRaised.color)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// 顶部固定统计条：累计坚持 X 天 · 写下 X 句话 · 已走过 X 天。
    /// 注意三个数字里没有"连续"，也永远不会有（D-03）。
    private var summaryBar: some View {
        HStack {
            Text(Strings.Log.summaryDays(checkIns.count))
            Spacer()
            Text(Strings.Log.summaryNotes(notes.count))
            Spacer()
            Text(Strings.Log.summaryPassed(countdown.daysPassed))
        }
        .dsFont(DSFont.caption(11.5))
        .foregroundStyle(palette.textSecondary.color)
        .padding(.top, DSSpacing.lg - 4)
        .padding(.bottom, DSSpacing.md + 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.line.color).frame(height: DSStroke.hairline)
        }
    }

    // MARK: - 日历

    private var month: CalendarMonth {
        CalendarMonth.build(
            year: cal.year(of: anchor), month: cal.month(of: anchor), today: .now,
            checkInDates: Set(checkIns.filter { !$0.isBackfill }.map(\.date)),
            backfillDates: Set(checkIns.filter(\.isBackfill).map(\.date)),
            noteDates: Set(notes.map(\.date)),
            cal: cal
        )
    }

    private var calendarView: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayRow
            grid
            legend
            Text(Strings.Log.backfillFootnote)
                .dsFont(DSFont.caption(DSType.captionSmall))
                .foregroundStyle(palette.textTertiary.color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DSSpacing.lg - 4)
        }
        .padding(.top, DSSpacing.md + 4)
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { chevron("chevron.left") }
            Spacer()
            Text(display.monthTitle(anchor))
                .dsFont(DSFont.body(DSType.body))
                .foregroundStyle(palette.textPrimary.color)
            Spacer()
            Button { shiftMonth(1) } label: { chevron("chevron.right") }
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
        }
        .padding(.bottom, DSSpacing.md)
    }

    private func chevron(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .light))
            .foregroundStyle(palette.textSecondary.color)
            .padding(.horizontal, DSSpacing.sm)
    }

    private var isCurrentMonth: Bool {
        cal.year(of: anchor) == cal.year(of: .now) && cal.month(of: anchor) == cal.month(of: .now)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = cal.calendar.date(byAdding: .month, value: delta, to: anchor) else { return }
        anchor = next
    }

    private var weekdayRow: some View {
        HStack(spacing: 7) {
            ForEach(CalendarMonth.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .dsFont(DSFont.caption(DSType.footnote))
                    .foregroundStyle(palette.textTertiary.color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 5)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
            ForEach(0..<month.leadingBlanks, id: \.self) { _ in Color.clear.aspectRatio(1, contentMode: .fit) }
            ForEach(month.days) { day in dayCell(day) }
        }
    }

    private func dayCell(_ day: CalendarMonth.Day) -> some View {
        // 补记走二次确认。今天的打卡是"点击即完成、零门槛"（5.3），
        // 但那是一个每天都做、点错了明天还能再点的动作；
        // 日历格子只有 30 多像素见方，点错的是**哪一天**，而记上之后没有撤销。
        Button {
            pendingBackfill = day
        } label: {
            ZStack {
                Circle().fill(cellFill(day))
                if day.isToday && !day.isCheckedIn && !day.isBackfill {
                    Circle().stroke(palette.textSecondary.color, lineWidth: 1)
                }
                Text("\(day.dayOfMonth)")
                    .dsFont(DSFont.caption(DSType.caption))
                    .foregroundStyle(cellText(day))
                if day.hasNote {
                    // 唯一的彩色留给树，心里话点也用树色 —— 它是同一套"生长"的语汇。
                    Circle().fill(palette.tree.color)
                        .frame(width: 3.5, height: 3.5)
                        .offset(x: 9, y: -9)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(!day.canBackfill || day.isCheckedIn || day.isBackfill)
    }

    private func cellFill(_ day: CalendarMonth.Day) -> Color {
        if day.isCheckedIn { return palette.textPrimary.color }
        if day.isBackfill { return palette.line.color }   // 补签用浅色，但一样计入累计
        return .clear
    }

    private func cellText(_ day: CalendarMonth.Day) -> Color {
        if day.isCheckedIn { return palette.background.color }
        if day.isBackfill || day.isToday { return palette.textPrimary.color }
        return palette.textTertiary.color
    }

    private func backfill(_ day: CalendarMonth.Day) {
        let service = CheckInService(context: context, cal: cal)
        switch service.backfill(date: day.date, examID: exam.id) {
        case .recorded:              toast = Strings.Log.backfillDone(display.short(day.date))
        case .alreadyRecorded:       break
        case .outsideBackfillWindow: toast = Strings.Log.backfillOutOfWindow
        }
    }

    private var legend: some View {
        HStack(spacing: DSSpacing.md + 2) {
            legendItem(palette.textPrimary.color, Strings.Log.legendCheckedIn)
            legendItem(palette.line.color, Strings.Log.legendBackfill)
            legendItem(palette.tree.color, Strings.Log.legendHasNote)
            Spacer()
        }
        .padding(.top, DSSpacing.lg - 2)
    }

    private func legendItem(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(title)
                .dsFont(DSFont.caption(DSType.footnote))
                .foregroundStyle(palette.textTertiary.color)
        }
    }

    // MARK: - 心里话时间线

    /// 500 条心里话下滚动流畅无卡顿（5.5 验收标准）→ 用 LazyVStack，不一次性建视图。
    private var timelineView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(notes) { note in
                    noteRow(note)
                }
            }
            // 长按没有任何视觉提示，不说一句就等于没做这个功能。
            Text(Strings.Log.noteActionHint)
                .dsFont(DSFont.caption(DSType.captionSmall))
                .foregroundStyle(palette.textTertiary.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DSSpacing.md)
                .padding(.bottom, DSSpacing.lg)
        }
    }

    private func noteRow(_ note: Note) -> some View {
        let remaining = CountdownEngine(cal: cal)
            .countdown(startDate: exam.startDate, targetDate: exam.targetDate, today: note.date)
            .daysRemaining

        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(Strings.Log.timelineMeta(date: display.short(note.date), remaining: remaining))
                .dsFont(DSFont.caption(DSType.footnote))
                .foregroundStyle(palette.textTertiary.color)

            // 用户自己写的内容用衬线 —— 产品说话用无衬线，用户说话用衬线。
            Text(note.content)
                .dsFont(DSFont.userWritten(DSType.userNote))
                .foregroundStyle(palette.textPrimary.color)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSSpacing.md + 2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.line.color).frame(height: DSStroke.hairline)
        }
        // 两个动作都藏在长按里：时间线是用来读的，不是用来操作的，
        // 每行挂一排按钮会把"自己写的话"变成一份待办清单。
        .contentShape(Rectangle())
        .contextMenu {
            Button(Strings.Log.makeCard) { cardForNote = makeCard(for: note) }
            Button(Strings.Log.deleteNoteConfirm, role: .destructive) { pendingDelete = note }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            // 超窗那句要把"累计不会因此减少"说完整，一行放不下。
            Text(toast)
                .dsFont(DSFont.caption(12.5))
                .foregroundStyle(palette.textPrimary.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSSpacing.lg - 4)
                .padding(.vertical, DSSpacing.sm + 2)
                .background(palette.surfaceRaised.color,
                            in: RoundedRectangle(cornerRadius: DSRadius.card - 1))
                .task {
                    try? await Task.sleep(for: .seconds(DSMotion.toast.seconds))
                    self.toast = nil
                }
        }
    }
}
