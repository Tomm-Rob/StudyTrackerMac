import SwiftUI

struct WeeklyReviewView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var selectedWeekStart = Calendar.current.dateInterval(
        of: .weekOfYear,
        for: Date()
    )?.start ?? Date().startOfDay

    private let service = WeeklyReviewService()
    private let metricColumns = [
        GridItem(.adaptive(minimum: 130, maximum: 220), spacing: 10)
    ]

    private var currentWeekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date().startOfDay
    }

    private var snapshot: WeeklyReviewSnapshot {
        service.review(
            classes: store.data.classes,
            goals: store.data.goals,
            sessions: store.data.sessions,
            weekContaining: selectedWeekStart
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                summaryMetrics

                if snapshot.isEmpty {
                    emptyState
                }

                highlights

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        WeeklyInsightsPanel(messages: snapshot.insights)
                            .frame(minWidth: 320, maxWidth: .infinity)
                        WeeklyTargetPanel(suggestion: snapshot.targetSuggestion)
                            .frame(minWidth: 280, maxWidth: 380)
                    }

                    VStack(spacing: 12) {
                        WeeklyInsightsPanel(messages: snapshot.insights)
                        WeeklyTargetPanel(suggestion: snapshot.targetSuggestion)
                    }
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                titleBlock
                Spacer()
                weekControls
            }

            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                weekControls
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Weekly Review")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text(weekRangeDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var weekControls: some View {
        HStack(spacing: 8) {
            Button {
                moveWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("Previous week")

            DatePicker(
                "Week",
                selection: Binding(
                    get: { selectedWeekStart },
                    set: { selectedWeekStart = normalizedWeekStart(for: $0) }
                ),
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(width: 120)

            Button {
                moveWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .help("Next week")
            .disabled(selectedWeekStart >= currentWeekStart)

            Button("This Week") {
                selectedWeekStart = currentWeekStart
            }
            .disabled(selectedWeekStart == currentWeekStart)
        }
    }

    private var weekRangeDescription: String {
        let start = snapshot.weekInterval.start.formatted(date: .abbreviated, time: .omitted)
        let end = snapshot.weekInterval.end.addingTimeInterval(-1)
            .formatted(date: .abbreviated, time: .omitted)
        return "\(start) - \(end)"
    }

    private var summaryMetrics: some View {
        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
            WeeklyMetricTile(
                title: "Total Time",
                value: snapshot.totalStudyTime.compactDuration,
                systemImage: "clock"
            )
            WeeklyMetricTile(
                title: "From Last Week",
                value: changeText,
                systemImage: changeIcon
            )
            WeeklyMetricTile(
                title: "Active Days",
                value: "\(snapshot.activeStudyDays)",
                systemImage: "calendar.badge.checkmark"
            )
            WeeklyMetricTile(
                title: "Current Streak",
                value: "\(snapshot.currentStreak) days",
                systemImage: "flame"
            )
            WeeklyMetricTile(
                title: "Average Session",
                value: snapshot.averageSessionDuration.compactDuration,
                systemImage: "timer"
            )
            WeeklyMetricTile(
                title: "Focus Rating",
                value: focusRatingText,
                systemImage: "scope"
            )
            WeeklyMetricTile(
                title: "Pomodoros",
                value: "\(snapshot.pomodoroIntervalsCompleted)",
                systemImage: "checkmark.circle"
            )
            WeeklyMetricTile(
                title: "Goals Completed",
                value: "\(snapshot.goalsCompleted)",
                systemImage: "checkmark.seal"
            )
            WeeklyMetricTile(
                title: "Goals Behind",
                value: "\(snapshot.goalsBehind)",
                systemImage: "exclamationmark.triangle"
            )
        }
    }

    private var highlights: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                mostStudiedHighlight
                leastStudiedHighlight
                bestDayHighlight
            }

            VStack(spacing: 10) {
                mostStudiedHighlight
                leastStudiedHighlight
                bestDayHighlight
            }
        }
    }

    private var mostStudiedHighlight: some View {
        WeeklyHighlightTile(
            title: "Most Studied Course",
            value: snapshot.mostStudiedCourse?.name ?? "N/A",
            detail: snapshot.mostStudiedCourse?.seconds.compactDuration ?? "No study time",
            systemImage: "arrow.up.right",
            colorHex: snapshot.mostStudiedCourse?.colorHex
        )
    }

    private var leastStudiedHighlight: some View {
        WeeklyHighlightTile(
            title: "Least Studied Active Course",
            value: snapshot.leastStudiedActiveCourse?.name ?? "N/A",
            detail: snapshot.leastStudiedActiveCourse?.seconds.compactDuration ?? "No active courses",
            systemImage: "arrow.down.right",
            colorHex: snapshot.leastStudiedActiveCourse?.colorHex
        )
    }

    private var bestDayHighlight: some View {
        WeeklyHighlightTile(
            title: "Best Study Day",
            value: snapshot.bestStudyDay?.date.formatted(.dateTime.weekday(.wide)) ?? "N/A",
            detail: snapshot.bestStudyDay?.seconds.compactDuration ?? "No study time",
            systemImage: "star",
            colorHex: nil
        )
    }

    private var changeText: String {
        guard let change = snapshot.weekOverWeekChange else {
            return snapshot.totalStudyTime > 0 ? "New" : "0%"
        }
        let percent = Int((change * 100).rounded())
        return percent > 0 ? "+\(percent)%" : "\(percent)%"
    }

    private var changeIcon: String {
        guard let change = snapshot.weekOverWeekChange else { return "sparkles" }
        if change > 0 { return "arrow.up.right" }
        if change < 0 { return "arrow.down.right" }
        return "equal"
    }

    private var focusRatingText: String {
        guard let average = snapshot.averageFocusRating else { return "N/A" }
        return String(format: "%.1f / 5", average)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No study sessions this week",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Review another week or log a study session.")
        )
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func moveWeek(by offset: Int) {
        guard let date = Calendar.current.date(
            byAdding: .weekOfYear,
            value: offset,
            to: selectedWeekStart
        ) else { return }
        selectedWeekStart = min(normalizedWeekStart(for: date), currentWeekStart)
    }

    private func normalizedWeekStart(for date: Date) -> Date {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: date)?.start
            ?? date.startOfDay
        return min(start, currentWeekStart)
    }
}

private struct WeeklyMetricTile: View {
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
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WeeklyHighlightTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let colorHex: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 7) {
                if let colorHex {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 9, height: 9)
                }
                Text(value)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Text(detail)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WeeklyInsightsPanel: View {
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Generated Insights", systemImage: "sparkles")
                .font(.headline)

            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.tint)
                        .frame(width: 18)
                    Text(message)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct WeeklyTargetPanel: View {
    let suggestion: WeeklyTargetSuggestion?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggested Next Week", systemImage: "target")
                .font(.headline)

            if let suggestion {
                targetRow("Total", value: suggestion.totalDuration.compactDuration)
                targetRow("Active days", value: "\(suggestion.activeDayTarget)")
                targetRow("Per active day", value: suggestion.dailyDuration.compactDuration)
            } else {
                Text("Log study time to generate a suggested target.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func targetRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.callout)
    }
}
