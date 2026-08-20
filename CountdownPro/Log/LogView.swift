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
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \CheckIn.date) private var checkIns: [CheckIn]
    @Query(sort: [SortDescriptor(\Note.date, order: .reverse),
                  SortDescriptor(\Note.createdAt, order: .reverse)]) private var notes: [Note]

    @State private var showingCalendar = true
    @State private var anchor = Date()
    @State private var toast: String?

    private let cal = DayCalendar.current
    private var display: DateDisplay { DateDisplay(cal: cal) }
    private var palette: Palette {
        Theme(skin: .default, scheme: colorScheme == .dark ? .dark : .light).palette
    }

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
        Button {
            backfill(day)
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
        case .recorded:              toast = Strings.Log.backfillDone
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
                .task {
                    try? await Task.sleep(for: .seconds(DSMotion.toast.seconds))
                    self.toast = nil
                }
        }
    }
}
