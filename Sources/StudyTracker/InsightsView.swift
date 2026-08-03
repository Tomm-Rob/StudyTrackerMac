import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var selectedFilter: InsightsDateFilter = .last30Days
    @State private var customStart = Calendar.current.date(
        byAdding: .day,
        value: -29,
        to: Date()
    ) ?? Date()
    @State private var customEnd = Date()

    private let service = InsightsService()
    private let metricColumns = [
        GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 10)
    ]

    private var selectedInterval: DateInterval? {
        selectedFilter.dateInterval(
            asOf: Date(),
            calendar: .current,
            customStart: customStart,
            customEnd: customEnd
        )
    }

    private var snapshot: InsightsSnapshot {
        service.snapshot(
            classes: store.data.classes,
            sessions: store.data.sessions,
            interval: selectedInterval,
            comparisonInterval: selectedFilter.comparisonInterval(
                asOf: Date(),
                calendar: .current,
                customStart: customStart,
                customEnd: customEnd
            )
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if selectedFilter == .custom {
                        customRangeControls
                    }

                    summaryMetrics
                        .id(GeneratedInsightDestination.overview.rawValue)

                    if snapshot.isEmpty {
                        emptyState
                    } else {
                        InsightsMessagesPanel(
                            insights: snapshot.generatedInsights,
                            onOpen: { destination in
                                withAnimation {
                                    proxy.scrollTo(destination.rawValue, anchor: .top)
                                }
                            }
                        )
                        if let comparison = snapshot.comparison {
                            PeriodComparisonPanel(comparison: comparison)
                        }
                        CourseAnalyticsPanel(totals: snapshot.courseTotals)
                            .id(GeneratedInsightDestination.courses.rawValue)
                        CourseAnalyticsDetailsPanel(totals: snapshot.courseTotals)

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 10) {
                                WeekdayPatternPanel(totals: snapshot.weekdayTotals)
                                    .frame(minWidth: 300, maxWidth: .infinity, minHeight: 220)
                                HourlyPatternPanel(totals: snapshot.hourlyTotals)
                                    .frame(minWidth: 300, maxWidth: .infinity, minHeight: 220)
                            }

                            VStack(spacing: 10) {
                                WeekdayPatternPanel(totals: snapshot.weekdayTotals)
                                    .frame(minHeight: 220)
                                HourlyPatternPanel(totals: snapshot.hourlyTotals)
                                    .frame(minHeight: 220)
                            }
                        }
                        .id(GeneratedInsightDestination.timePatterns.rawValue)

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 10) {
                                TimeWindowAnalyticsPanel(
                                    totals: snapshot.timeWindowTotals,
                                    mostProductive: snapshot.mostProductiveTimeWindow
                                )
                                .frame(minWidth: 310, maxWidth: .infinity)
                                FocusByWeekdayPanel(
                                    totals: snapshot.weekdayTotals,
                                    mostProductive: snapshot.mostProductiveDay
                                )
                                .frame(minWidth: 300, maxWidth: .infinity)
                            }

                            VStack(spacing: 10) {
                                TimeWindowAnalyticsPanel(
                                    totals: snapshot.timeWindowTotals,
                                    mostProductive: snapshot.mostProductiveTimeWindow
                                )
                                FocusByWeekdayPanel(
                                    totals: snapshot.weekdayTotals,
                                    mostProductive: snapshot.mostProductiveDay
                                )
                            }
                        }

                        ConsistencySummaryPanel(snapshot: snapshot)
                            .id(GeneratedInsightDestination.consistency.rawValue)
                        StudyHeatmapPanel(days: snapshot.heatmapDays)
                        WeeklyTrendPanel(totals: snapshot.weeklyTrend)
                    }
                }
                .padding(16)
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                titleBlock
                Spacer()
                rangePicker
            }

            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                rangePicker
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Insights")
                .font(.system(size: 26, weight: .semibold, design: .default))
            Text(rangeDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var rangePicker: some View {
        Picker("Date range", selection: $selectedFilter) {
            ForEach(InsightsDateFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 170)
    }

    private var rangeDescription: String {
        guard let selectedInterval else { return "All recorded study time" }
        let start = selectedInterval.start.formatted(date: .abbreviated, time: .omitted)
        let inclusiveEnd = selectedInterval.end.addingTimeInterval(-1)
            .formatted(date: .abbreviated, time: .omitted)
        return start == inclusiveEnd ? start : "\(start) - \(inclusiveEnd)"
    }

    private var customRangeControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                customDatePicker("From", selection: $customStart)
                customDatePicker("Through", selection: $customEnd)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                customDatePicker("From", selection: $customStart)
                customDatePicker("Through", selection: $customEnd)
            }
        }
        .padding(12)
        .appPanel()
    }

    private func customDatePicker(_ title: String, selection: Binding<Date>) -> some View {
        DatePicker(title, selection: selection, displayedComponents: .date)
            .datePickerStyle(.compact)
            .frame(maxWidth: 250)
    }

    private var summaryMetrics: some View {
        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
            InsightsMetricTile(
                title: "Total Time",
                value: snapshot.totalStudyTime.compactDuration,
                systemImage: "clock"
            )
            InsightsMetricTile(
                title: "Avg per Day",
                value: snapshot.averageStudyTimePerActiveDay.compactDuration,
                systemImage: "calendar"
            )
            InsightsMetricTile(
                title: "Sessions",
                value: "\(snapshot.sessionCount)",
                systemImage: "list.bullet.rectangle"
            )
            InsightsMetricTile(
                title: "Active Days",
                value: "\(snapshot.activeDayCount)",
                systemImage: "calendar.badge.checkmark"
            )
            InsightsMetricTile(
                title: "Average Session",
                value: snapshot.averageSessionDuration.compactDuration,
                systemImage: "timer"
            )
            InsightsMetricTile(
                title: "Longest Session",
                value: snapshot.longestSessionDuration.compactDuration,
                systemImage: "arrow.left.and.right"
            )
            InsightsMetricTile(
                title: "Pomodoros",
                value: "\(snapshot.pomodoroIntervalCount)",
                systemImage: "checkmark.circle"
            )
            InsightsMetricTile(
                title: "Current Streak",
                value: "\(snapshot.currentStreak) days",
                systemImage: "flame"
            )
            InsightsMetricTile(
                title: "Longest Streak",
                value: "\(snapshot.longestStreak) days",
                systemImage: "trophy"
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No study time in this range",
            systemImage: "chart.xyaxis.line",
            description: Text("Choose another date range or log a study session.")
        )
        .frame(maxWidth: .infinity, minHeight: 200)
        .appPanel()
    }
}

private struct InsightsMetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel()
    }
}

private struct InsightsMessagesPanel: View {
    let insights: [GeneratedInsight]
    let onOpen: (GeneratedInsightDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Local Insights", systemImage: "sparkles")
                .font(.headline)

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.tint)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title)
                            .font(.callout.weight(.semibold))
                        Text(insight.explanation)
                            .font(.callout)
                        Text(insight.dateRangeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let destination = insight.destination,
                       destination != .overview {
                        Button {
                            onOpen(destination)
                        } label: {
                            Image(systemName: "arrow.down.right")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("View related analytics")
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel()
    }
}

private struct CourseAnalyticsPanel: View {
    let totals: [CourseInsightTotal]
    @State private var tooltip: InsightsChartTooltip?

    private var chartHeight: CGFloat {
        max(190, CGFloat(totals.count) * 28)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study Time by Course")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                Chart(totals) { total in
                    BarMark(
                        x: .value("Hours", total.seconds.hours),
                        y: .value("Course", total.courseID.uuidString)
                    )
                    .foregroundStyle(Color(hex: total.colorHex))
                    .cornerRadius(4)
                }
                .chartXAxisLabel("Hours")
                .chartYScale(domain: totals.map { $0.courseID.uuidString }.reversed())
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        if let id = value.as(String.self),
                           let total = totals.first(where: { $0.courseID.uuidString == id }) {
                            AxisValueLabel {
                                Text(total.name)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                updateHover(phase, proxy: proxy, geometry: geometry)
                            }
                    }
                }

                if let tooltip {
                    InsightsHoverTooltip(tooltip: tooltip)
                }
            }
            .frame(height: chartHeight)
        }
        .padding(12)
        .appPanel()
    }

    private func updateHover(_ phase: HoverPhase, proxy: ChartProxy, geometry: GeometryProxy) {
        switch phase {
        case .active(let location):
            guard let plotFrameAnchor = proxy.plotFrame else {
                tooltip = nil
                return
            }
            let plotFrame = geometry[plotFrameAnchor]
            guard plotFrame.contains(location) else {
                tooltip = nil
                return
            }
            let plotY = location.y - plotFrame.origin.y
            guard let id = proxy.value(atY: plotY, as: String.self),
                  let total = totals.first(where: { $0.courseID.uuidString == id }) else {
                tooltip = nil
                return
            }
            tooltip = InsightsChartTooltip(
                title: total.name,
                value: total.seconds.hhMMDuration,
                location: location
            )
        case .ended:
            tooltip = nil
        }
    }
}

private struct WeekdayPatternPanel: View {
    let totals: [WeekdayInsightTotal]
    @State private var tooltip: InsightsChartTooltip?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study by Weekday")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                Chart(totals) { total in
                    BarMark(
                        x: .value("Day", total.label),
                        y: .value("Hours", total.seconds.hours)
                    )
                    .foregroundStyle(Color(hex: "#0891B2"))
                    .cornerRadius(4)
                }
                .chartYAxisLabel("Hours")
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                updateHover(phase, proxy: proxy, geometry: geometry)
                            }
                    }
                }

                if let tooltip {
                    InsightsHoverTooltip(tooltip: tooltip)
                }
            }
        }
        .padding(12)
        .appPanel()
    }

    private func updateHover(_ phase: HoverPhase, proxy: ChartProxy, geometry: GeometryProxy) {
        switch phase {
        case .active(let location):
            guard let plotFrameAnchor = proxy.plotFrame else {
                tooltip = nil
                return
            }
            let plotFrame = geometry[plotFrameAnchor]
            guard plotFrame.contains(location) else {
                tooltip = nil
                return
            }
            let plotX = location.x - plotFrame.origin.x
            guard let label = proxy.value(atX: plotX, as: String.self),
                  let total = totals.first(where: { $0.label == label }),
                  total.seconds > 0 else {
                tooltip = nil
                return
            }
            tooltip = InsightsChartTooltip(
                title: total.label,
                value: total.seconds.hhMMDuration,
                location: location
            )
        case .ended:
            tooltip = nil
        }
    }
}

private struct HourlyPatternPanel: View {
    let totals: [HourlyInsightTotal]
    @State private var tooltip: InsightsChartTooltip?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study by Start Time")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                Chart(totals) { total in
                    LineMark(
                        x: .value("Hour", total.hour),
                        y: .value("Hours", total.seconds.hours)
                    )
                    .foregroundStyle(Color(hex: "#DB2777"))
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Hour", total.hour),
                        y: .value("Hours", total.seconds.hours)
                    )
                    .foregroundStyle(Color(hex: "#DB2777"))
                }
                .chartXScale(domain: 0...23)
                .chartYAxisLabel("Hours")
                .chartXAxis {
                    AxisMarks(values: [0, 4, 8, 12, 16, 20, 23]) { value in
                        AxisGridLine()
                        AxisTick()
                        if let hour = value.as(Int.self) {
                            AxisValueLabel(hourAxisLabel(hour))
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                updateHover(phase, proxy: proxy, geometry: geometry)
                            }
                    }
                }

                if let tooltip {
                    InsightsHoverTooltip(tooltip: tooltip)
                }
            }
        }
        .padding(12)
        .appPanel()
    }

    private func updateHover(_ phase: HoverPhase, proxy: ChartProxy, geometry: GeometryProxy) {
        switch phase {
        case .active(let location):
            guard let plotFrameAnchor = proxy.plotFrame else {
                tooltip = nil
                return
            }
            let plotFrame = geometry[plotFrameAnchor]
            guard plotFrame.contains(location) else {
                tooltip = nil
                return
            }
            let plotX = location.x - plotFrame.origin.x
            guard let hoveredHour = proxy.value(atX: plotX, as: Int.self),
                  let total = totals.min(by: { abs($0.hour - hoveredHour) < abs($1.hour - hoveredHour) }),
                  abs(total.hour - hoveredHour) <= 1 else {
                tooltip = nil
                return
            }
            tooltip = InsightsChartTooltip(
                title: total.label,
                value: total.seconds.hhMMDuration,
                location: location
            )
        case .ended:
            tooltip = nil
        }
    }

    private func hourAxisLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12a"
        case 1..<12: "\(hour)a"
        case 12: "12p"
        default: "\(hour - 12)p"
        }
    }
}

private struct InsightsChartTooltip {
    let title: String
    let value: String
    let location: CGPoint
}

private struct InsightsHoverTooltip: View {
    let tooltip: InsightsChartTooltip

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tooltip.title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Text(tooltip.value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.8), lineWidth: 0.5)
        )
        .offset(x: tooltip.location.x + 12, y: max(0, tooltip.location.y - 42))
        .allowsHitTesting(false)
    }
}
