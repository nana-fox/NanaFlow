import AppKit
import SwiftUI
import UniformTypeIdentifiers

func filteredSessionHistory(
    _ sessions: [FocusSession],
    showIncomplete: Bool,
    tag: String?
) -> [FocusSession] {
    sessions.filter { session in
        (showIncomplete || session.completed) && (tag == nil || session.tag == tag)
    }
}

func statisticsBucketTooltipText(_ bucket: StatisticsBucket) -> String {
    "\(bucket.sessionCount)"
}

func statisticsCanMoveForward(
    period: StatisticsPeriod,
    anchor: Date,
    now: Date = Date(),
    calendar: Calendar = flowStatisticsCalendar
) -> Bool {
    guard let anchorInterval = calendar.dateInterval(of: period.calendarComponent, for: anchor),
          let currentInterval = calendar.dateInterval(of: period.calendarComponent, for: now) else {
        return false
    }
    return anchorInterval.start < currentInterval.start
}

func statisticsShowsLabel(
    at index: Int,
    bucketCount: Int,
    period: StatisticsPeriod
) -> Bool {
    switch period {
    case .day:
        return index.isMultiple(of: 6) || index == bucketCount - 1
    case .week, .year:
        return true
    case .month:
        return index == 0 || (index + 1).isMultiple(of: 5) || index == bucketCount - 1
    }
}

enum StatisticsVisualMetrics {
    static let windowWidth: CGFloat = 380
    static let contentHeight: CGFloat = 272
    static let headerHeight: CGFloat = 49
    static let periodSwitcherHeight: CGFloat = 42
    static let periodPickerWidth: CGFloat = 300
    static let periodPickerHeight: CGFloat = 32
    static let periodPickerCornerRadius: CGFloat = 10
    static let selectedPeriodOpacity = 1.0
    static let chartHeight: CGFloat = 181
    static let chartTrackHeight: CGFloat = 137
    static let navigationButtonDiameter: CGFloat = 31
    static let periodTitleWidth: CGFloat = 258
    static let sessionListHorizontalInset: CGFloat = 8
}

enum SessionListMenuVisualMetrics {
    static var filterTitle: String { String(localized: "按标签过滤") }
    static var clearFilterTitle: String { String(localized: "清除过滤") }
    static let clearFilterIcon = "minus.circle"
    static let addIcon = "plus"
    static let incompleteIcon = "eye"
    static let exportIcon = "square.and.arrow.up"
    static let resetIcon = "trash"
    static var resetTitle: String { String(localized: "重置统计数据") }
    static let csvTitle = "CSV..."
    static let textTitle = "Text..."
}

enum SessionListPagination {
    static let batchSize = 100

    static func nextLimit(current: Int, total: Int) -> Int {
        min(current + batchSize, total)
    }
}

struct StatisticsView: View {
    let controller: TimerController
    let onBack: () -> Void

    @State private var period: StatisticsPeriod = .week
    @State private var anchor = Date()

    init(controller: TimerController, onBack: @escaping () -> Void = {}) {
        self.controller = controller
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .medium))
                        .frame(
                            width: StatisticsVisualMetrics.navigationButtonDiameter,
                            height: StatisticsVisualMetrics.navigationButtonDiameter
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回计时器")
                .padding(.leading, 13)

                StatisticsPeriodPicker(selection: $period)
                    .position(x: 214, y: StatisticsVisualMetrics.headerHeight / 2)
            }
            .frame(height: StatisticsVisualMetrics.headerHeight)

            HStack(spacing: 0) {
                navigationButton(systemName: "chevron.left", disabled: false) {
                    moveAnchor(by: -1)
                }
                Text("\(periodTitle) · \(statistics.totalCount)次")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: StatisticsVisualMetrics.periodTitleWidth)
                navigationButton(systemName: "chevron.right", disabled: !canMoveForward) {
                    moveAnchor(by: 1)
                }
            }
            .padding(.horizontal, 15)
            .frame(height: StatisticsVisualMetrics.periodSwitcherHeight)

            StatisticsBars(buckets: statistics.buckets, period: period)
                .frame(height: StatisticsVisualMetrics.chartHeight)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("统计图表")
        }
        .frame(width: StatisticsVisualMetrics.windowWidth, height: StatisticsVisualMetrics.contentHeight)
        .background(Color(red: 249 / 255, green: 251 / 255, blue: 250 / 255))
    }

    private var statistics: SessionStatistics {
        SessionStatistics(
            sessions: controller.sessions,
            period: period,
            anchor: anchor,
            calendar: flowStatisticsCalendar
        )
    }

    private var periodTitle: String {
        let calendar = flowStatisticsCalendar
        switch period {
        case .day:
            return compactDate(anchor, format: "M月d日")
        case .week:
            guard let first = statistics.buckets.first?.start,
                  let last = statistics.buckets.last?.start else { return "" }
            let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
            let visibleEnd = calendar.date(byAdding: .second, value: -1, to: end) ?? last
            if calendar.component(.month, from: first) == calendar.component(.month, from: visibleEnd) {
                return "\(compactDate(first, format: "M月d日"))至\(compactDate(visibleEnd, format: "d日"))"
            }
            return "\(compactDate(first, format: "M月d日"))至\(compactDate(visibleEnd, format: "M月d日"))"
        case .month:
            return compactDate(anchor, format: "yyyy年M月")
        case .year:
            return compactDate(anchor, format: "yyyy年")
        }
    }

    private func compactDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = flowStatisticsCalendar
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    private func navigationButton(
        systemName: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(
                    width: 32,
                    height: 32
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var canMoveForward: Bool {
        statisticsCanMoveForward(period: period, anchor: anchor)
    }

    private func moveAnchor(by value: Int) {
        anchor = flowStatisticsCalendar.date(
            byAdding: period.calendarComponent,
            value: value,
            to: anchor
        ) ?? anchor
    }

}

private struct StatisticsPeriodPicker: View {
    @Binding var selection: StatisticsPeriod

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StatisticsPeriod.allCases) { period in
                Button { selection = period } label: {
                    Text(period.compactTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            selection == period
                                ? Color.white.opacity(StatisticsVisualMetrics.selectedPeriodOpacity)
                                : Color.clear,
                            in: RoundedRectangle(
                                cornerRadius: StatisticsVisualMetrics.periodPickerCornerRadius - 2,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityValue(selection == period ? "1" : "0")
            }
        }
        .padding(2)
        .frame(
            width: StatisticsVisualMetrics.periodPickerWidth,
            height: StatisticsVisualMetrics.periodPickerHeight
        )
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(
                cornerRadius: StatisticsVisualMetrics.periodPickerCornerRadius,
                style: .continuous
            )
        )
    }
}

private struct StatisticsBars: View {
    let buckets: [StatisticsBucket]
    let period: StatisticsPeriod
    @State private var hoveredBucketID: Date?

    var body: some View {
        GeometryReader { proxy in
            let spacing = barSpacing
            let usableWidth = proxy.size.width - horizontalInset * 2
            let width = max(2, (usableWidth - spacing * CGFloat(max(0, buckets.count - 1))) / CGFloat(max(1, buckets.count)))
            let maxValue = max(1, buckets.map(\.sessionCount).max() ?? 0)

            ZStack(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                        VStack(spacing: 7) {
                            ZStack(alignment: .bottom) {
                                Capsule().fill(FlowPalette.compactAccent.opacity(0.12))
                                if bucket.sessionCount > 0 {
                                    Capsule()
                                        .fill(FlowPalette.compactAccent)
                                        .frame(height: max(8, StatisticsVisualMetrics.chartTrackHeight * CGFloat(bucket.sessionCount) / CGFloat(maxValue)))
                                }
                            }
                            .frame(width: min(trackWidth, width), height: StatisticsVisualMetrics.chartTrackHeight)

                            Text(statisticsShowsLabel(at: index, bucketCount: buckets.count, period: period) ? label(for: bucket.start) : " ")
                                .font(.system(size: labelFontSize, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.primary.opacity(0.86))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .frame(width: width)
                        .contentShape(Rectangle())
                        .onHover { isHovered in
                            if isHovered {
                                hoveredBucketID = bucket.id
                            } else if hoveredBucketID == bucket.id {
                                hoveredBucketID = nil
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(for: bucket.start))
                        .accessibilityValue("\(bucket.sessionCount)次")
                    }
                }
                .padding(.horizontal, horizontalInset)
                .padding(.top, 5)
                .padding(.bottom, 13)

                if let bucket = activeBucket,
                   let index = buckets.firstIndex(where: { $0.id == bucket.id }) {
                    Text(statisticsBucketTooltipText(bucket))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(width: 32)
                        .padding(.vertical, 4)
                        .background(FlowPalette.compactAccent, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        .position(
                            x: tooltipCenterX(
                                at: index,
                                barWidth: width,
                                spacing: spacing,
                                availableWidth: proxy.size.width
                            ),
                            y: 17
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .onChange(of: buckets.map(\.id)) { _, _ in
            hoveredBucketID = nil
        }
    }

    private var activeBucket: StatisticsBucket? {
        guard let id = hoveredBucketID else { return nil }
        return buckets.first { $0.id == id }
    }

    private func tooltipCenterX(
        at index: Int,
        barWidth: CGFloat,
        spacing: CGFloat,
        availableWidth: CGFloat
    ) -> CGFloat {
        let naturalCenter = horizontalInset + barWidth / 2 + CGFloat(index) * (barWidth + spacing)
        return min(max(16, naturalCenter), availableWidth - 16)
    }

    private var barSpacing: CGFloat {
        switch period {
        case .day: 3
        case .week: 8
        case .month: 2
        case .year: 5
        }
    }

    private var horizontalInset: CGFloat {
        switch period {
        case .day, .year: 18
        case .week: 20
        case .month: 16
        }
    }

    private var trackWidth: CGFloat {
        switch period {
        case .day: 11
        case .week: 28
        case .month: 7
        case .year: 17
        }
    }

    private var labelFontSize: CGFloat {
        switch period {
        case .day, .month: 8
        case .week: 11
        case .year: 9
        }
    }

    private func label(for date: Date) -> String {
        switch period {
        case .day:
            return "\(flowStatisticsCalendar.component(.hour, from: date))"
        case .month:
            return "\(flowStatisticsCalendar.component(.day, from: date))"
        case .year:
            return "\(flowStatisticsCalendar.component(.month, from: date))"
        case .week:
            break
        }

        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.calendar = flowStatisticsCalendar
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    private func accessibilityLabel(for date: Date) -> String {
        switch period {
        case .day: "\(label(for: date))时"
        case .week: label(for: date)
        case .month: "\(label(for: date))日"
        case .year: "\(label(for: date))月"
        }
    }
}

private extension StatisticsPeriod {
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    var compactTitle: String {
        switch self {
        case .day: "D"
        case .week: "W"
        case .month: "M"
        case .year: "Y"
        }
    }
}

struct AllSessionsView: View {
    let controller: TimerController
    let onBack: () -> Void
    let onSelect: (FocusSession) -> Void

    @State private var exportError: String?
    @AppStorage("showIncompleteSessions") private var showIncomplete = false
    @State private var selectedTag: String?
    @State private var confirmsDeleteAll = false
    @State private var showsAddSession = false
    @State private var visibleSessionCount = SessionListPagination.batchSize

    init(
        controller: TimerController,
        onBack: @escaping () -> Void = {},
        onSelect: @escaping (FocusSession) -> Void = { _ in }
    ) {
        self.controller = controller
        self.onBack = onBack
        self.onSelect = onSelect
    }

    var body: some View {
        Group {
            if filteredSessions.isEmpty {
                ContentUnavailableView {
                    Label("未找到会话", systemImage: "clock.badge.questionmark")
                } description: {
                    Text(controller.sessions.isEmpty
                        ? String(localized: "完成你的第一次会话，在这里查看详细概览。")
                        : String(localized: "没有符合当前筛选条件的会话。"))
                } actions: {
                    if !controller.sessions.isEmpty {
                        Button("清除过滤") {
                            selectedTag = nil
                            showIncomplete = true
                        }
                    }
                }
            } else {
                List {
                    ForEach(visibleSessions) { session in
                        Button { onSelect(session) } label: {
                            HStack {
                                SessionRow(session: session)
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 5)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.025))
                                .padding(.vertical, 3)
                        )
                    }

                    if visibleSessions.count < filteredSessions.count {
                        Button("载入更多") {
                            visibleSessionCount = SessionListPagination.nextLimit(
                                current: visibleSessionCount,
                                total: filteredSessions.count
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .scrollContentBackground(.hidden)
                .contentMargins(
                    .horizontal,
                    StatisticsVisualMetrics.sessionListHorizontalInset,
                    for: .scrollContent
                )
            }
        }
        .navigationTitle("所有会话")
        .background(FlowPalette.window)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .help("返回统计")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Section(SessionListMenuVisualMetrics.filterTitle) {
                        ForEach(controller.tagSettings.tags, id: \.self) { tag in
                            Toggle(tag, isOn: filterSelectionBinding(for: tag))
                        }
                    }
                    if selectedTag != nil {
                        Divider()
                        Button(SessionListMenuVisualMetrics.clearFilterTitle, systemImage: SessionListMenuVisualMetrics.clearFilterIcon) {
                            selectedTag = nil
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .menuIndicator(.hidden)
                .help("筛选")

                Menu {
                    Button { showsAddSession = true } label: {
                        Label("添加", systemImage: SessionListMenuVisualMetrics.addIcon)
                    }
                    Toggle(isOn: $showIncomplete) {
                        Label("显示未完成", systemImage: SessionListMenuVisualMetrics.incompleteIcon)
                    }
                    Menu {
                        Button(SessionListMenuVisualMetrics.csvTitle) { beginExport(.csv) }
                        Button(SessionListMenuVisualMetrics.textTitle) { beginExport(.text) }
                    } label: {
                        Label("导出", systemImage: SessionListMenuVisualMetrics.exportIcon)
                    }
                    Divider()
                    Button(role: .destructive) { confirmsDeleteAll = true } label: {
                        Label(
                            SessionListMenuVisualMetrics.resetTitle,
                            systemImage: SessionListMenuVisualMetrics.resetIcon
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
                .help("更多")
            }
        }
        .sheet(isPresented: $showsAddSession) {
            SessionEditSheet(controller: controller)
        }
        .onChange(of: showIncomplete) { _, _ in resetPagination() }
        .onChange(of: selectedTag) { _, _ in resetPagination() }
        .alert("您确定要重置您的统计数据吗？", isPresented: $confirmsDeleteAll) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { controller.deleteAllSessions() }
        } message: {
            Text("此操作不能撤销。")
        }
        .alert("无法导出", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("好") { exportError = nil }
        } message: {
            Text(exportError ?? String(localized: "未知错误"))
        }
    }

    private var filteredSessions: [FocusSession] {
        filteredSessionHistory(controller.sessions, showIncomplete: showIncomplete, tag: selectedTag)
    }

    private var visibleSessions: ArraySlice<FocusSession> {
        filteredSessions.prefix(visibleSessionCount)
    }

    private func resetPagination() {
        visibleSessionCount = SessionListPagination.batchSize
    }

    private func filterSelectionBinding(for tag: String) -> Binding<Bool> {
        Binding(
            get: { selectedTag == tag },
            set: { if $0 { selectedTag = tag } }
        )
    }

    private func beginExport(_ format: SessionExportFormat) {
        let contents = format.content(for: controller.sessions)
        exportError = nil
        DispatchQueue.main.async {
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
                exportError = String(localized: "无法打开导出窗口。")
                return
            }

            let panel = NSSavePanel()
            panel.nameFieldStringValue = String(
                format: String(localized: "NanaFlow 会话.%@"),
                format.fileExtension
            )
            panel.allowedContentTypes = [format.contentType]
            panel.canCreateDirectories = true
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try contents.write(to: url, atomically: true, encoding: .utf8)
                } catch {
                    exportError = error.localizedDescription
                }
            }
        }
    }
}

struct SessionDetailView: View {
    let controller: TimerController
    let session: FocusSession
    let dismiss: () -> Void

    @State private var showsEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 0) {
                    SessionDetailRow("类型", value: session.type.displayName)
                    SessionDetailRow("时长", value: sessionDurationText(session.duration))
                    if shouldShowSessionInterruptionDuration(session) {
                        SessionDetailRow(
                            "时长（含中断）",
                            value: sessionDurationText(session.durationWithInterruptions)
                        )
                    }
                    SessionDetailRow("已启动", value: dateText(session.startedAt))
                    SessionDetailRow("已完成", value: session.completedAt.map(dateText) ?? "-")
                }
                .sessionCard()

                if !session.interruptions.isEmpty {
                    Text("打断")
                        .font(.headline)
                        .padding(.leading, 16)

                    VStack(spacing: 0) {
                        ForEach(Array(session.interruptions.enumerated()), id: \.offset) { index, interruption in
                            SessionDetailRow("已停止", value: dateText(interruption.stoppedAt))
                            SessionDetailRow("已恢复", value: interruption.resumedAt.map(dateText) ?? "-")
                            if index < session.interruptions.count - 1 { Divider() }
                        }
                    }
                    .sessionCard()
                }
            }
            .padding(12)
        }
        .navigationTitle("会话详情")
        .background(FlowPalette.window)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: dismiss) { Image(systemName: "chevron.left") }
                    .help("返回所有会话")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showsEditor = true } label: { Image(systemName: "pencil") }
                    .disabled(!session.completed)
                    .help(session.completed ? "编辑" : "未完成会话不能编辑")
            }
        }
        .sheet(isPresented: $showsEditor) {
            SessionEditSheet(controller: controller, session: session) { dismiss() }
        }
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale.autoupdatingCurrent)
                .year().month().day().hour().minute().second()
        )
    }
}

private struct SessionDetailRow: View {
    let title: String
    let value: String

    init(_ title: String, value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
    }
}

enum SessionEditVisualMetrics {
    static let width: CGFloat = 470
    static let height: CGFloat = 410
}

private struct SessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let controller: TimerController
    let session: FocusSession?
    let onDelete: () -> Void

    @State private var type: RecordedSessionType
    @State private var title: String
    @State private var tag: String
    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var confirmsDelete = false

    init(
        controller: TimerController,
        session: FocusSession? = nil,
        onDelete: @escaping () -> Void = {}
    ) {
        self.controller = controller
        self.session = session
        self.onDelete = onDelete
        let end = session?.endedAt ?? Date()
        _type = State(initialValue: session?.type ?? .focus)
        _title = State(initialValue: session?.title ?? "NanaFlow")
        _tag = State(initialValue: session?.tag ?? "")
        _startedAt = State(initialValue: session?.startedAt ?? end.addingTimeInterval(-25 * 60))
        _endedAt = State(initialValue: end)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("类型", selection: $type) {
                    ForEach(RecordedSessionType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                TextField("标题", text: $title)
                Picker("标签", selection: $tag) {
                    Text("无标签").tag("")
                    ForEach(controller.tagSettings.tags, id: \.self) { Text($0).tag($0) }
                }
                .disabled(type != .focus)

                Section {
                    DatePicker("已启动", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("已完成", selection: $endedAt, displayedComponents: [.date, .hourAndMinute])
                    if session.map(shouldShowSessionInterruptionDuration) == true {
                        LabeledContent("打断", value: localizedMinutes(Int(interruptionDuration / 60)))
                    }
                    LabeledContent("时长", value: localizedMinutes(Int(activeDuration / 60)))
                }

                if session != nil {
                    Section {
                        Button("删除会话", role: .destructive) { confirmsDelete = true }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(session == nil ? String(localized: "添加") : String(localized: "编辑")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .tint(FlowPalette.focus)
                    .disabled(endedAt < startedAt)
            }
            .padding(14)
        }
        .frame(width: SessionEditVisualMetrics.width, height: SessionEditVisualMetrics.height)
        .alert("你确定要删除此会话吗？", isPresented: $confirmsDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                guard let session else { return }
                controller.deleteSession(id: session.id)
                dismiss()
                onDelete()
            }
        } message: {
            Text("此操作不能撤销。")
        }
    }

    private var interruptionDuration: TimeInterval {
        session?.interruptions.reduce(0) { total, interruption in
            guard let resumedAt = interruption.resumedAt else { return total }
            return total + max(0, resumedAt.timeIntervalSince(interruption.stoppedAt))
        } ?? 0
    }

    private var activeDuration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt) - interruptionDuration)
    }

    private func save() {
        if let session {
            controller.updateSession(
                id: session.id,
                type: type,
                title: title,
                tag: tag,
                startedAt: startedAt,
                endedAt: endedAt
            )
        } else {
            controller.addSession(
                type: type,
                title: title,
                tag: tag,
                startedAt: startedAt,
                endedAt: endedAt
            )
        }
        dismiss()
    }
}

private extension View {
    func sessionCard() -> some View {
        background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum SessionExportFormat {
    case csv
    case text

    var fileExtension: String { self == .csv ? "csv" : "txt" }
    var contentType: UTType { self == .csv ? .commaSeparatedText : .plainText }

    func content(for sessions: [FocusSession]) -> String {
        self == .csv
            ? SessionExporter.csv(sessions: sessions)
            : SessionExporter.plainText(sessions: sessions)
    }
}

struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(session.type.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(FlowPalette.focus)
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text("\(Int(session.duration / 60))")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text("分钟").foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(sessionRowDateText(session.startedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !session.completed {
                    Text("未完成")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                if let tag = session.tag {
                    Text(tag)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(FlowPalette.focus)
                }
            }
        }
    }
}

func sessionRowDateText(
    _ date: Date,
    calendar: Calendar = .current,
    locale: Locale = .autoupdatingCurrent
) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.setLocalizedDateFormatFromTemplate("yMdjm")
    return formatter.string(from: date)
}

func shouldShowSessionInterruptionDuration(_ session: FocusSession) -> Bool {
    !session.interruptions.isEmpty || session.durationWithInterruptions - session.duration > 0.5
}

func sessionDurationText(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(duration.rounded()))
    return String(
        format: String(localized: "duration_hms_format"),
        seconds / 3600,
        (seconds % 3600) / 60,
        seconds % 60
    )
}

func localizedMinutes(_ minutes: Int) -> String {
    String.localizedStringWithFormat(
        NSLocalizedString("%lld 分钟", comment: "Duration in minutes"),
        minutes
    )
}

private extension RecordedSessionType {
    var displayName: String {
        switch self {
        case .focus: "NanaFlow"
        case .shortBreak: String(localized: "休息")
        case .longBreak: String(localized: "长时间停顿")
        }
    }
}

extension StatisticsPeriod {
    var shortTitle: String {
        switch self {
        case .day: String(localized: "天")
        case .week: String(localized: "周")
        case .month: String(localized: "月")
        case .year: String(localized: "年")
        }
    }
}

enum FlowPalette {
    static let windowRed = 248.0 / 255.0
    static let windowGreen = 249.0 / 255.0
    static let windowBlue = 250.0 / 255.0
    static let window = Color(red: windowRed, green: windowGreen, blue: windowBlue)
    static let focusRed = 62.0 / 255.0
    static let focusGreen = 146.0 / 255.0
    static let focusBlue = 122.0 / 255.0
    static let focus = Color(red: focusRed, green: focusGreen, blue: focusBlue)
    static let compactAccentRed = 47.0 / 255.0
    static let compactAccentGreen = 123.0 / 255.0
    static let compactAccentBlue = 103.0 / 255.0
    static let compactAccent = Color(
        red: compactAccentRed,
        green: compactAccentGreen,
        blue: compactAccentBlue
    )
    static let primaryButtonRed = 223.0 / 255.0
    static let primaryButtonGreen = 236.0 / 255.0
    static let primaryButtonBlue = 232.0 / 255.0
    static let primaryButtonBackground = Color(
        red: primaryButtonRed,
        green: primaryButtonGreen,
        blue: primaryButtonBlue
    )
    static let breakRed = 51.0 / 255.0
    static let breakGreen = 124.0 / 255.0
    static let breakBlue = 104.0 / 255.0
    static let breakBackground = Color(red: breakRed, green: breakGreen, blue: breakBlue)

    static func tag(_ argbHex: String) -> Color {
        let digits = argbHex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 8, let value = UInt64(digits, radix: 16) else { return focus }
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: Double((value >> 24) & 0xFF) / 255
        )
    }
}
