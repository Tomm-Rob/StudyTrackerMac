import SwiftUI
import Charts

struct PeriodComparisonPanel: View {
    let comparison: PeriodComparison

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                comparisonHeader
                Spacer()
                comparisonValues
            }

            VStack(alignment: .leading, spacing: 10) {
                comparisonHeader
                comparisonValues
            }
        }
        .padding(12)
        .appPanel()
    }

    private var comparisonHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: comparison.numericalDifference >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.title2)
                .foregroundStyle(comparison.numericalDifference >= 0 ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text("Previous Period Comparison")
                    .font(.headline)
                Text(previousRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var comparisonValues: some View {
        HStack(spacing: 12) {
            comparisonValue("Previous", comparison.previousDuration.compactDuration)
            comparisonValue("Difference", signedDuration(comparison.numericalDifference))
            comparisonValue("Change", percentageText)
        }
    }

    private var previousRange: String {
        let start = comparison.previousInterval.start.formatted(date: .abbreviated, time: .omitted)
        let end = comparison.previousInterval.end.addingTimeInterval(-0.001)
            .formatted(date: .abbreviated, time: .omitted)
        return "\(start) - \(end)"
    }

    private var percentageText: String {
        guard let change = comparison.percentageChange else { return "No baseline" }
        let value = Int((change * 100).rounded())
        return value > 0 ? "+\(value)%" : "\(value)%"
    }

    private func signedDuration(_ duration: TimeInterval) -> String {
        let prefix = duration > 0 ? "+" : duration < 0 ? "-" : ""
        return prefix + abs(duration).compactDuration
    }

    private func comparisonValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .frame(minWidth: 78, alignment: .trailing)
    }
}

struct CourseAnalyticsDetailsPanel: View {
    let totals: [CourseInsightTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Course Details")
                .font(.headline)

            ForEach(totals) { total in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Circle()
                            .fill(Color(hex: total.colorHex))
                            .frame(width: 9, height: 9)
                        Text(total.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        if total.receivesLessAttention {
                            Label("Below Priority", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Spacer()
                        Text(total.seconds.compactDuration)
                            .font(.body.weight(.medium))
                            .monospacedDigit()
                        Text(percent(total.percentageOfTotal))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 18) {
                            detail("Sessions", "\(total.sessionCount)")
                            detail("Average", total.averageSessionDuration.compactDuration)
                            detail(
                                "Last Studied",
                                total.lastStudiedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Never"
                            )
                            if let priority = total.priority {
                                detail("Priority", priority.title)
                            }
                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            detail("Sessions", "\(total.sessionCount)")
                            detail("Average", total.averageSessionDuration.compactDuration)
                            detail(
                                "Last Studied",
                                total.lastStudiedDate?.formatted(date: .abbreviated, time: .omitted) ?? "Never"
                            )
                        }
                    }

                    if let planned = total.plannedStudyHours,
                       let progress = total.plannedProgressFraction {
                        progressRow(
                            title: "Planned Hours",
                            detail: "\(total.seconds.hours.formatted(.number.precision(.fractionLength(0...1)))) / \(planned.formatted(.number.precision(.fractionLength(0...1))))h",
                            progress: progress
                        )
                    }

                    if let target = total.weeklyTargetHours,
                       let progress = total.weeklyTargetProgressFraction {
                        progressRow(
                            title: "Weekly Target",
                            detail: "\((target * progress).formatted(.number.precision(.fractionLength(0...1)))) / \(target.formatted(.number.precision(.fractionLength(0...1))))h",
                            progress: progress
                        )
                    }
                }
                .padding(.vertical, 7)

                if total.id != totals.last?.id {
                    Divider()
                }
            }
        }
        .padding(12)
        .appPanel()
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
    }

    private func progressRow(title: String, detail: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(detail)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: min(max(progress, 0), 1))
        }
    }

    private func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }
}

struct TimeWindowAnalyticsPanel: View {
    let totals: [TimeWindowInsight]
    let mostProductive: TimeWindowInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Time of Day")
                    .font(.headline)
                Spacer()
                if let mostProductive {
                    Label(mostProductive.window.title, systemImage: "star")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }

            ForEach(totals) { total in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(total.window.title)
                            .font(.callout.weight(.medium))
                        Text(total.window.hourRange)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 115, alignment: .leading)

                    Spacer()
                    analyticsValue("Time", total.seconds.compactDuration)
                    analyticsValue("Average", total.averageSessionDuration.compactDuration)
                    analyticsValue(
                        "Focus",
                        total.averageFocusRating.map { String(format: "%.1f", $0) } ?? "N/A"
                    )
                }
                .padding(.vertical, 6)

                if total.id != totals.last?.id {
                    Divider()
                }
            }
        }
        .padding(12)
        .appPanel()
    }

    private func analyticsValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .frame(minWidth: 58, alignment: .trailing)
    }
}

struct FocusByWeekdayPanel: View {
    let totals: [WeekdayInsightTotal]
    let mostProductive: WeekdayInsightTotal?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Focus by Day")
                    .font(.headline)
                Spacer()
                if let mostProductive {
                    Text("Most productive: \(mostProductive.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart(totals) { total in
                BarMark(
                    x: .value("Day", total.label),
                    y: .value("Focus", total.averageFocusRating ?? 0)
                )
                .foregroundStyle(total.averageFocusRating == nil ? Color.secondary.opacity(0.2) : Color.green)
                .cornerRadius(3)
            }
            .chartYScale(domain: 0...5)
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3, 4, 5])
            }
            .frame(minHeight: 210)
        }
        .padding(12)
        .appPanel()
    }
}

struct ConsistencySummaryPanel: View {
    let snapshot: InsightsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Consistency")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                value("Days Studied", "\(snapshot.activeDayCount) of \(snapshot.selectedDayCount)")
                value("Days Active", "\(Int((snapshot.studiedDayPercentage * 100).rounded()))%")
                value("Current Streak", "\(snapshot.currentStreak) days")
                value("Longest Streak", "\(snapshot.longestStreak) days")
            }
        }
        .padding(12)
        .appPanel()
    }

    private func value(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct StudyHeatmapPanel: View {
    let days: [StudyHeatmapDay]

    private var maximum: TimeInterval {
        days.map(\.seconds).max() ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar Heatmap")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 14, maximum: 14), spacing: 4)],
                alignment: .leading,
                spacing: 4
            ) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color(for: day.seconds))
                        .frame(width: 14, height: 14)
                        .help(
                            "\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.seconds.compactDuration)"
                        )
                }
            }
        }
        .padding(12)
        .appPanel()
    }

    private func color(for seconds: TimeInterval) -> Color {
        guard seconds > 0, maximum > 0 else {
            return AppTheme.separator.opacity(0.35)
        }
        return Color.green.opacity(0.25 + 0.75 * min(seconds / maximum, 1))
    }
}

struct WeeklyTrendPanel: View {
    let totals: [WeeklyStudyTrend]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Study-Time Trend")
                .font(.headline)

            Chart(totals) { total in
                LineMark(
                    x: .value("Week", total.weekStart),
                    y: .value("Hours", total.seconds.hours)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Week", total.weekStart),
                    y: .value("Hours", total.seconds.hours)
                )
                .foregroundStyle(Color.blue)
            }
            .chartYAxisLabel("Hours")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(minHeight: 220)
        }
        .padding(12)
        .appPanel()
    }
}
