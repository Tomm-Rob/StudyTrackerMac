import Foundation

struct GeneratedInsightsService {
    private struct Candidate {
        let priority: Int
        let insight: GeneratedInsight
    }

    private struct FocusGroup {
        let title: String
        let ratings: [Int]

        var average: Double {
            Double(ratings.reduce(0, +)) / Double(ratings.count)
        }
    }

    let calendar: Calendar
    let maximumInsightCount: Int

    init(calendar: Calendar = .current, maximumInsightCount: Int = 4) {
        self.calendar = calendar
        self.maximumInsightCount = max(1, maximumInsightCount)
    }

    func generate(
        classes: [StudyClass],
        allSessions: [StudySession],
        selectedSessions: [StudySession],
        courseTotals: [CourseInsightTotal],
        comparison: PeriodComparison?,
        interval: DateInterval?,
        asOf date: Date
    ) -> [GeneratedInsight] {
        guard !selectedSessions.isEmpty else {
            return [
                GeneratedInsight(
                    id: "empty",
                    title: "Not enough data yet",
                    explanation: "Log a study session in this range to generate local insights.",
                    dateRangeDescription: rangeDescription(interval, sessions: [], asOf: date),
                    destination: .overview
                )
            ]
        }

        let selectedRange = rangeDescription(interval, sessions: selectedSessions, asOf: date)
        var candidates: [Candidate] = []

        append(comparisonInsight(comparison, selectedRange: selectedRange), priority: 100, to: &candidates)
        append(weeklyTargetInsight(classes: classes, sessions: allSessions, asOf: date), priority: 95, to: &candidates)
        append(projectionInsight(classes: classes, sessions: allSessions, asOf: date), priority: 90, to: &candidates)
        append(inactiveCourseInsight(classes: classes, sessions: allSessions, asOf: date), priority: 85, to: &candidates)
        append(focusWindowInsight(sessions: selectedSessions, range: selectedRange), priority: 80, to: &candidates)
        append(consistentDayInsight(sessions: selectedSessions, range: selectedRange), priority: 75, to: &candidates)
        append(focusDurationInsight(sessions: selectedSessions, range: selectedRange), priority: 70, to: &candidates)
        append(courseShareInsight(courseTotals: courseTotals, range: selectedRange), priority: 65, to: &candidates)
        append(courseSpreadInsight(courseTotals: courseTotals, range: selectedRange), priority: 60, to: &candidates)

        let selected = candidates
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.insight.id < $1.insight.id
            }
            .prefix(maximumInsightCount)
            .map(\.insight)

        if selected.isEmpty {
            return [
                GeneratedInsight(
                    id: "collecting-data",
                    title: "Building a clearer picture",
                    explanation: "Keep logging sessions and optional ratings. Insights appear when there is enough evidence for a useful pattern.",
                    dateRangeDescription: selectedRange,
                    destination: .overview
                )
            ]
        }
        return selected
    }

    private func append(
        _ insight: GeneratedInsight?,
        priority: Int,
        to candidates: inout [Candidate]
    ) {
        guard let insight else { return }
        candidates.append(Candidate(priority: priority, insight: insight))
    }

    private func comparisonInsight(
        _ comparison: PeriodComparison?,
        selectedRange: String
    ) -> GeneratedInsight? {
        guard let comparison,
              comparison.previousDuration > 0,
              let percentage = comparison.percentageChange,
              abs(percentage) >= 0.1 else { return nil }

        let increased = percentage > 0
        let amount = Int((abs(percentage) * 100).rounded())
        let previousRange = rangeDescription(
            comparison.previousInterval,
            sessions: [],
            asOf: comparison.previousInterval.end
        )
        return GeneratedInsight(
            id: "period-comparison",
            title: increased ? "Study time increased" : "Study time decreased",
            explanation: "You studied \(amount)% \(increased ? "more" : "less") than in the previous equivalent period.",
            dateRangeDescription: "\(selectedRange), compared with \(previousRange)",
            destination: .consistency
        )
    }

    private func consistentDayInsight(
        sessions: [StudySession],
        range: String
    ) -> GeneratedInsight? {
        let weeks = Set(sessions.map { weekStart(for: $0.startedAt) })
        guard weeks.count >= 3 else { return nil }

        let activePairs = Set(sessions.map {
            WeekdayOccurrence(
                weekStart: weekStart(for: $0.startedAt),
                weekday: calendar.component(.weekday, from: $0.startedAt)
            )
        })
        let counts = Dictionary(grouping: activePairs, by: \.weekday).mapValues(\.count)
        let ranked = counts.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }
        guard let best = ranked.first,
              best.value >= 2,
              ranked.dropFirst().first?.value != best.value else { return nil }

        return GeneratedInsight(
            id: "consistent-weekday",
            title: "\(weekdayName(best.key)) is your most consistent day",
            explanation: "You studied on \(best.value) of \(weeks.count) \(weekdayName(best.key))s in this range.",
            dateRangeDescription: range,
            destination: .timePatterns
        )
    }

    private func focusWindowInsight(
        sessions: [StudySession],
        range: String
    ) -> GeneratedInsight? {
        let rated = sessions.filter { $0.focusRating != nil }
        guard rated.count >= 4 else { return nil }

        let grouped = Dictionary(grouping: rated) {
            (calendar.component(.hour, from: $0.startedAt) / 3) * 3
        }
        let qualifying = grouped.map { startHour, sessions in
            FocusGroup(
                title: "\(hourLabel(startHour)) and \(hourLabel((startHour + 3) % 24))",
                ratings: sessions.compactMap(\.focusRating)
            )
        }
        .filter { $0.ratings.count >= 2 }
        .sorted { $0.average > $1.average }

        guard qualifying.count >= 2,
              qualifying[0].average - qualifying[1].average >= 0.5 else { return nil }
        let best = qualifying[0]
        return GeneratedInsight(
            id: "focus-time-window",
            title: "Highest focus: \(best.title)",
            explanation: "Your average focus rating is \(oneDecimal(best.average)) in this window, based on \(best.ratings.count) rated sessions.",
            dateRangeDescription: range,
            destination: .timePatterns
        )
    }

    private func inactiveCourseInsight(
        classes: [StudyClass],
        sessions: [StudySession],
        asOf date: Date
    ) -> GeneratedInsight? {
        let activeClasses = classes.filter { !$0.isArchived && $0.status == .active }
        let lastDates = Dictionary(grouping: sessions, by: \.classID)
            .compactMapValues { $0.map(\.startedAt).max() }
        let stale = activeClasses.compactMap { studyClass -> (StudyClass, Date, Int)? in
            guard let lastDate = lastDates[studyClass.id] else { return nil }
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastDate),
                to: calendar.startOfDay(for: date)
            ).day ?? 0
            return days >= 5 ? (studyClass, lastDate, days) : nil
        }
        .sorted {
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending
        }
        guard let result = stale.first else { return nil }

        return GeneratedInsight(
            id: "inactive-course-\(result.0.id.uuidString)",
            title: "\(result.0.name) may need attention",
            explanation: "You have not studied \(result.0.name) in \(result.2) days. Its last session was \(shortDate(result.1)).",
            dateRangeDescription: "As of \(shortDate(date))",
            destination: .courses,
            courseID: result.0.id
        )
    }

    private func weeklyTargetInsight(
        classes: [StudyClass],
        sessions: [StudySession],
        asOf date: Date
    ) -> GeneratedInsight? {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        let elapsedDays = max(
            1,
            (calendar.dateComponents(
                [.day],
                from: week.start,
                to: calendar.startOfDay(for: date)
            ).day ?? 0) + 1
        )
        let elapsedFraction = min(1, Double(elapsedDays) / 7)
        let studiedByCourse = Dictionary(grouping: sessions.filter {
            $0.startedAt >= week.start && $0.startedAt <= date
        }, by: \.classID).mapValues { $0.reduce(0) { $0 + $1.duration } }

        let behind = classes.compactMap { studyClass -> (StudyClass, TimeInterval)? in
            guard !studyClass.isArchived,
                  studyClass.status == .active,
                  let target = studyClass.weeklyStudyHoursTarget,
                  target > 0 else { return nil }
            let expected = target * 3_600 * elapsedFraction
            let deficit = expected - (studiedByCourse[studyClass.id] ?? 0)
            return deficit >= 1_800 ? (studyClass, deficit) : nil
        }
        .max { $0.1 < $1.1 }
        guard let behind else { return nil }

        return GeneratedInsight(
            id: "weekly-target-\(behind.0.id.uuidString)",
            title: "Behind weekly pace",
            explanation: "\(behind.0.name) is \(behind.1.compactDuration) behind its expected pace for this point in the week.",
            dateRangeDescription: "Week of \(shortDate(week.start))",
            destination: .courses,
            courseID: behind.0.id
        )
    }

    private func projectionInsight(
        classes: [StudyClass],
        sessions: [StudySession],
        asOf date: Date
    ) -> GeneratedInsight? {
        let start = calendar.date(
            byAdding: .day,
            value: -13,
            to: calendar.startOfDay(for: date)
        ) ?? date
        let sessionsByCourse = Dictionary(grouping: sessions, by: \.classID)

        let projections = classes.compactMap {
            studyClass -> (StudyClass, Date, Int)? in
            guard !studyClass.isArchived,
                  studyClass.status == .active,
                  let plannedHours = studyClass.plannedStudyHours,
                  plannedHours > 0,
                  let targetDate = studyClass.targetCompletionDate,
                  targetDate >= calendar.startOfDay(for: date) else { return nil }
            let courseSessions = sessionsByCourse[studyClass.id] ?? []
            let total = courseSessions.reduce(0) { $0 + $1.duration }
            let remaining = plannedHours * 3_600 - total
            let recent = courseSessions.filter { $0.startedAt >= start && $0.startedAt <= date }
            guard remaining > 0,
                  recent.count >= 3,
                  Set(recent.map { calendar.startOfDay(for: $0.startedAt) }).count >= 3 else {
                return nil
            }
            let dailyRate = recent.reduce(0) { $0 + $1.duration } / 14
            guard dailyRate > 0 else { return nil }
            let daysNeeded = Int(ceil(remaining / dailyRate))
            guard let projected = calendar.date(
                byAdding: .day,
                value: max(0, daysNeeded - 1),
                to: calendar.startOfDay(for: date)
            ) else { return nil }
            let difference = calendar.dateComponents(
                [.day],
                from: projected,
                to: calendar.startOfDay(for: targetDate)
            ).day ?? 0
            return abs(difference) >= 2 ? (studyClass, projected, difference) : nil
        }
        .sorted { abs($0.2) > abs($1.2) }
        guard let result = projections.first else { return nil }

        let timing = result.2 > 0 ? "\(result.2) days early" : "\(abs(result.2)) days late"
        return GeneratedInsight(
            id: "planned-projection-\(result.0.id.uuidString)",
            title: "Projected completion for \(result.0.name)",
            explanation: "At your recent study rate, you are projected to reach the planned hours on \(shortDate(result.1)), \(timing).",
            dateRangeDescription: "Pace based on the last 14 days",
            destination: .courses,
            courseID: result.0.id
        )
    }

    private func focusDurationInsight(
        sessions: [StudySession],
        range: String
    ) -> GeneratedInsight? {
        let groups = Dictionary(grouping: sessions.filter { $0.focusRating != nil }) {
            durationBucket(for: $0.duration)
        }
        let qualifying = groups.map { title, sessions in
            FocusGroup(title: title, ratings: sessions.compactMap(\.focusRating))
        }
        .filter { $0.ratings.count >= 3 }
        .sorted { $0.average > $1.average }
        guard qualifying.count >= 2,
              qualifying[0].average - qualifying[1].average >= 0.5 else { return nil }
        let best = qualifying[0]

        return GeneratedInsight(
            id: "focus-duration",
            title: "Best-rated session length: \(best.title)",
            explanation: "Sessions lasting \(best.title) average \(oneDecimal(best.average)) for focus, based on \(best.ratings.count) rated sessions.",
            dateRangeDescription: range,
            destination: .timePatterns
        )
    }

    private func courseShareInsight(
        courseTotals: [CourseInsightTotal],
        range: String
    ) -> GeneratedInsight? {
        guard let top = courseTotals.first,
              top.sessionCount >= 2,
              top.percentageOfTotal >= 0.3 else { return nil }
        let percentage = Int((top.percentageOfTotal * 100).rounded())
        return GeneratedInsight(
            id: "course-share-\(top.courseID.uuidString)",
            title: "\(top.name) leads your study time",
            explanation: "\(top.name) represents \(percentage)% of your study time in this range.",
            dateRangeDescription: range,
            destination: .courses,
            courseID: top.courseID
        )
    }

    private func courseSpreadInsight(
        courseTotals: [CourseInsightTotal],
        range: String
    ) -> GeneratedInsight? {
        let studied = courseTotals.filter { $0.seconds > 0 }
        guard studied.count >= 4,
              studied.reduce(0, { $0 + $1.sessionCount }) >= 8,
              let least = studied.min(by: {
                  $0.percentageOfTotal < $1.percentageOfTotal
              }),
              least.percentageOfTotal < 0.1 else { return nil }
        let percentage = Int((least.percentageOfTotal * 100).rounded())
        return GeneratedInsight(
            id: "course-spread",
            title: "Study time is spread unevenly",
            explanation: "You studied across \(studied.count) courses, but \(least.name) received only \(percentage)% of the total time.",
            dateRangeDescription: range,
            destination: .courses,
            courseID: least.courseID
        )
    }

    private func rangeDescription(
        _ interval: DateInterval?,
        sessions: [StudySession],
        asOf date: Date
    ) -> String {
        if let interval {
            let end = min(interval.end.addingTimeInterval(-0.001), date)
            guard interval.start <= end else { return "Selected range" }
            return formattedRange(start: interval.start, end: end)
        }
        guard let first = sessions.map(\.startedAt).min() else { return "All recorded time" }
        return "All time: \(formattedRange(start: first, end: date))"
    }

    private func formattedRange(start: Date, end: Date) -> String {
        let startText = shortDate(start)
        let endText = shortDate(end)
        return startText == endText ? startText : "\(startText) - \(endText)"
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func weekStart(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.weekdaySymbols[max(0, min(6, weekday - 1))]
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12 AM"
        case 1..<12: "\(hour) AM"
        case 12: "12 PM"
        default: "\(hour - 12) PM"
        }
    }

    private func durationBucket(for duration: TimeInterval) -> String {
        let minutes = duration / 60
        return switch minutes {
        case ..<25: "under 25 minutes"
        case ..<35: "25 to 34 minutes"
        case ...55: "35 to 55 minutes"
        default: "over 55 minutes"
        }
    }

    private func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

private struct WeekdayOccurrence: Hashable {
    let weekStart: Date
    let weekday: Int
}
