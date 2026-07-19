import Foundation

struct InsightsService {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func snapshot(
        classes: [StudyClass],
        sessions: [StudySession],
        interval: DateInterval?,
        comparisonInterval: DateInterval? = nil,
        asOf date: Date = Date()
    ) -> InsightsSnapshot {
        let validSessions = sessions.filter { isValid($0, asOf: date) }
        let relevantSessions = filter(validSessions, to: interval)
        let totalStudyTime = relevantSessions.reduce(0) { $0 + $1.duration }
        let averageSessionDuration = relevantSessions.isEmpty
            ? 0
            : totalStudyTime / Double(relevantSessions.count)
        let activeDayCount = Set(
            relevantSessions.map { calendar.startOfDay(for: $0.startedAt) }
        ).count
        let dayCount = selectedDayCount(
            interval: interval,
            sessions: relevantSessions,
            asOf: date
        )
        let pomodoroIntervalCount = relevantSessions
            .filter { $0.source == .pomodoro }
            .reduce(0) { $0 + $1.pomodoroIntervalCount }
        let courseTotals = makeCourseTotals(
            classes: classes,
            sessions: relevantSessions,
            totalStudyTime: totalStudyTime,
            asOf: date
        )
        let weekdayTotals = makeWeekdayTotals(sessions: relevantSessions)
        let hourlyTotals = makeHourlyTotals(sessions: relevantSessions)
        let timeWindowTotals = makeTimeWindowTotals(sessions: relevantSessions)
        let heatmapDays = makeHeatmapDays(
            sessions: relevantSessions,
            interval: interval,
            asOf: date
        )
        let weeklyTrend = makeWeeklyTrend(sessions: relevantSessions)
        let streakDate = effectiveStreakDate(interval: interval, asOf: date)
        let analytics = StudyAnalyticsService(calendar: calendar)
        let comparison = makeComparison(
            sessions: validSessions,
            currentDuration: totalStudyTime,
            interval: comparisonInterval
        )
        let generatedInsights = GeneratedInsightsService(calendar: calendar).generate(
            classes: classes,
            allSessions: validSessions,
            selectedSessions: relevantSessions,
            courseTotals: courseTotals.filter { $0.seconds > 0 },
            comparison: comparison,
            interval: interval,
            asOf: date
        )

        return InsightsSnapshot(
            totalStudyTime: totalStudyTime,
            averageStudyTimePerActiveDay: activeDayCount == 0
                ? 0
                : totalStudyTime / Double(activeDayCount),
            averageSessionDuration: averageSessionDuration,
            longestSessionDuration: relevantSessions.map(\.duration).max() ?? 0,
            sessionCount: relevantSessions.count,
            activeDayCount: activeDayCount,
            selectedDayCount: dayCount,
            studiedDayPercentage: dayCount == 0
                ? 0
                : Double(activeDayCount) / Double(dayCount),
            pomodoroIntervalCount: pomodoroIntervalCount,
            currentStreak: analytics.currentStudyStreak(
                in: relevantSessions,
                asOf: streakDate
            ),
            longestStreak: analytics.longestStudyStreak(in: relevantSessions),
            courseCount: courseTotals.filter { $0.seconds > 0 }.count,
            courseTotals: courseTotals,
            weekdayTotals: weekdayTotals,
            hourlyTotals: hourlyTotals,
            timeWindowTotals: timeWindowTotals,
            heatmapDays: heatmapDays,
            weeklyTrend: weeklyTrend,
            comparison: comparison,
            mostProductiveDay: weekdayTotals
                .filter { $0.seconds > 0 }
                .max { $0.seconds < $1.seconds },
            mostProductiveTimeWindow: timeWindowTotals
                .filter { $0.seconds > 0 }
                .max { $0.seconds < $1.seconds },
            generatedInsights: generatedInsights
        )
    }

    private func makeCourseTotals(
        classes: [StudyClass],
        sessions: [StudySession],
        totalStudyTime: TimeInterval,
        asOf date: Date
    ) -> [CourseInsightTotal] {
        let visibleClasses = classes.filter { !$0.isArchived }
        let attentionClasses = visibleClasses.filter {
            $0.status != .paused && $0.status != .completed
        }
        let classesByID = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: sessions, by: \.classID)
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: date)
        let priorityWeights = Dictionary(uniqueKeysWithValues: attentionClasses.map {
            ($0.id, priorityWeight($0.priority))
        })
        let totalPriorityWeight = priorityWeights.values.reduce(0, +)
        let knownIDs = Set(visibleClasses.map(\.id))
        let unknownIDs = Set(grouped.keys).subtracting(knownIDs)
        let courseIDs = visibleClasses.map(\.id) + unknownIDs.sorted {
            $0.uuidString < $1.uuidString
        }

        return courseIDs.map { courseID in
            let studyClass = classesByID[courseID]
            let courseSessions = grouped[courseID] ?? []
            let seconds = courseSessions.reduce(0) { $0 + $1.duration }
            let weeklySeconds = courseSessions
                .filter { currentWeek?.contains($0.startedAt) ?? false }
                .reduce(0) { $0 + $1.duration }
            let actualShare = totalStudyTime > 0 ? seconds / totalStudyTime : 0
            let expectedShare = totalPriorityWeight > 0
                ? (priorityWeights[courseID] ?? 0) / totalPriorityWeight
                : 0
            let plannedHours = studyClass?.plannedStudyHours
            let weeklyTarget = studyClass?.weeklyStudyHoursTarget

            return CourseInsightTotal(
                courseID: courseID,
                name: studyClass?.name ?? "Unknown Course",
                colorHex: studyClass?.colorHex ?? "#6B7280",
                seconds: seconds,
                percentageOfTotal: actualShare,
                averageSessionDuration: courseSessions.isEmpty
                    ? 0
                    : seconds / Double(courseSessions.count),
                sessionCount: courseSessions.count,
                lastStudiedDate: courseSessions.map(\.startedAt).max(),
                plannedStudyHours: plannedHours,
                plannedProgressFraction: plannedHours.flatMap {
                    $0 > 0 ? seconds.hours / $0 : nil
                },
                weeklyTargetHours: weeklyTarget,
                weeklyTargetProgressFraction: weeklyTarget.flatMap {
                    $0 > 0 ? weeklySeconds.hours / $0 : nil
                },
                priority: studyClass?.priority,
                receivesLessAttention: totalStudyTime > 0
                    && expectedShare > 0
                    && actualShare < expectedShare * 0.6
            )
        }
        .sorted { left, right in
            if left.seconds != right.seconds {
                return left.seconds > right.seconds
            }
            return left.name.lowercased() < right.name.lowercased()
        }
    }

    private func makeWeekdayTotals(sessions: [StudySession]) -> [WeekdayInsightTotal] {
        let grouped = Dictionary(grouping: sessions) {
            calendar.component(.weekday, from: $0.startedAt)
        }
        let orderedWeekdays = (0..<7).map { offset in
            ((calendar.firstWeekday - 1 + offset) % 7) + 1
        }

        return orderedWeekdays.map { weekday in
            let weekdaySessions = grouped[weekday] ?? []
            return WeekdayInsightTotal(
                weekday: weekday,
                label: weekdayLabel(weekday),
                seconds: weekdaySessions.reduce(0) { $0 + $1.duration },
                averageFocusRating: averageRating(weekdaySessions.compactMap(\.focusRating))
            )
        }
    }

    private func makeHourlyTotals(sessions: [StudySession]) -> [HourlyInsightTotal] {
        let grouped = Dictionary(grouping: sessions) {
            calendar.component(.hour, from: $0.startedAt)
        }

        return grouped.keys.sorted().map { hour in
            HourlyInsightTotal(
                hour: hour,
                label: hourLabel(hour),
                seconds: grouped[hour]?.reduce(0) { $0 + $1.duration } ?? 0
            )
        }
    }

    private func makeTimeWindowTotals(sessions: [StudySession]) -> [TimeWindowInsight] {
        let grouped = Dictionary(grouping: sessions) {
            timeWindow(for: calendar.component(.hour, from: $0.startedAt))
        }

        return StudyTimeWindow.allCases.map { window in
            let windowSessions = grouped[window] ?? []
            let seconds = windowSessions.reduce(0) { $0 + $1.duration }
            return TimeWindowInsight(
                window: window,
                seconds: seconds,
                averageFocusRating: averageRating(windowSessions.compactMap(\.focusRating)),
                averageSessionDuration: windowSessions.isEmpty
                    ? 0
                    : seconds / Double(windowSessions.count),
                sessionCount: windowSessions.count
            )
        }
    }

    private func makeHeatmapDays(
        sessions: [StudySession],
        interval: DateInterval?,
        asOf date: Date
    ) -> [StudyHeatmapDay] {
        guard let effectiveInterval = effectiveAnalysisInterval(
            interval: interval,
            sessions: sessions,
            asOf: date
        ) else { return [] }

        let totals = Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.startedAt)
        }
        .mapValues { $0.reduce(0) { $0 + $1.duration } }

        var days: [StudyHeatmapDay] = []
        var day = calendar.startOfDay(for: effectiveInterval.start)
        while day < effectiveInterval.end {
            days.append(StudyHeatmapDay(date: day, seconds: totals[day] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    private func makeWeeklyTrend(sessions: [StudySession]) -> [WeeklyStudyTrend] {
        Dictionary(grouping: sessions) {
            calendar.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start
                ?? calendar.startOfDay(for: $0.startedAt)
        }
        .map { weekStart, sessions in
            WeeklyStudyTrend(
                weekStart: weekStart,
                seconds: sessions.reduce(0) { $0 + $1.duration }
            )
        }
        .sorted { $0.weekStart < $1.weekStart }
    }

    private func makeComparison(
        sessions: [StudySession],
        currentDuration: TimeInterval,
        interval: DateInterval?
    ) -> PeriodComparison? {
        guard let interval else { return nil }
        let previousDuration = filter(sessions, to: interval)
            .reduce(0) { $0 + $1.duration }
        let difference = currentDuration - previousDuration
        return PeriodComparison(
            previousInterval: interval,
            currentDuration: currentDuration,
            previousDuration: previousDuration,
            numericalDifference: difference,
            percentageChange: previousDuration > 0 ? difference / previousDuration : nil
        )
    }

    private func selectedDayCount(
        interval: DateInterval?,
        sessions: [StudySession],
        asOf date: Date
    ) -> Int {
        guard let effective = effectiveAnalysisInterval(
            interval: interval,
            sessions: sessions,
            asOf: date
        ) else { return 0 }
        let startDay = calendar.startOfDay(for: effective.start)
        let lastDay = calendar.startOfDay(for: effective.end.addingTimeInterval(-0.001))
        let difference = calendar.dateComponents([.day], from: startDay, to: lastDay).day ?? 0
        return max(0, difference + 1)
    }

    private func effectiveAnalysisInterval(
        interval: DateInterval?,
        sessions: [StudySession],
        asOf date: Date
    ) -> DateInterval? {
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        ) ?? date.addingTimeInterval(0.001)

        if let interval {
            let end = min(interval.end, tomorrow)
            guard interval.start < end else { return nil }
            return DateInterval(start: interval.start, end: end)
        }

        guard let first = sessions.map(\.startedAt).min() else { return nil }
        return DateInterval(start: calendar.startOfDay(for: first), end: tomorrow)
    }

    private func effectiveStreakDate(interval: DateInterval?, asOf date: Date) -> Date {
        guard let interval else { return date }
        return min(date, interval.end.addingTimeInterval(-0.001))
    }

    private func filter(_ sessions: [StudySession], to interval: DateInterval?) -> [StudySession] {
        sessions.filter { interval?.contains($0.startedAt) ?? true }
    }

    private func isValid(_ session: StudySession, asOf date: Date) -> Bool {
        session.duration.isFinite && session.duration > 0 && session.startedAt <= date
    }

    private func averageRating(_ ratings: [Int]) -> Double? {
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    private func timeWindow(for hour: Int) -> StudyTimeWindow {
        switch hour {
        case 5..<12: .morning
        case 12..<17: .afternoon
        case 17..<21: .evening
        default: .night
        }
    }

    private func priorityWeight(_ priority: CoursePriority?) -> Double {
        switch priority {
        case .low: 1
        case .normal, nil: 2
        case .high: 3
        case .critical: 4
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        switch weekday {
        case 1: "Sun"
        case 2: "Mon"
        case 3: "Tue"
        case 4: "Wed"
        case 5: "Thu"
        case 6: "Fri"
        case 7: "Sat"
        default: "Day"
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12 AM"
        case 1..<12: "\(hour) AM"
        case 12: "12 PM"
        default: "\(hour - 12) PM"
        }
    }
}
