import Foundation

struct WeeklyReviewService {
    let calendar: Calendar
    let minimumFocusRatings: Int

    init(calendar: Calendar = .current, minimumFocusRatings: Int = 3) {
        self.calendar = calendar
        self.minimumFocusRatings = max(1, minimumFocusRatings)
    }

    func review(
        classes: [StudyClass],
        goals: [StudyGoal],
        sessions: [StudySession],
        weekContaining selectedDate: Date,
        asOf date: Date = Date()
    ) -> WeeklyReviewSnapshot {
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate)
            ?? fallbackWeek(containing: selectedDate)
        let endOfWeek = weekInterval.end.addingTimeInterval(-0.001)
        let reviewCutoff = min(max(date, weekInterval.start), endOfWeek)
        let selectedSessions = validSessions(
            sessions,
            in: weekInterval,
            through: reviewCutoff
        )
        let previousWeekInterval = previousWeek(before: weekInterval)
        let previousSessions = validSessions(
            sessions,
            in: previousWeekInterval,
            through: min(date, previousWeekInterval.end.addingTimeInterval(-0.001))
        )
        let totalStudyTime = selectedSessions.reduce(0) { $0 + $1.duration }
        let previousWeekStudyTime = previousSessions.reduce(0) { $0 + $1.duration }
        let weekOverWeekChange = change(
            current: totalStudyTime,
            previous: previousWeekStudyTime
        )
        let activeStudyDays = Set(
            selectedSessions.map { calendar.startOfDay(for: $0.startedAt) }
        ).count
        let analytics = StudyAnalyticsService(calendar: calendar)
        let sessionsThroughCutoff = sessions.filter {
            isValid($0) && $0.startedAt <= reviewCutoff
        }
        let currentStreak = analytics.currentStudyStreak(
            in: sessionsThroughCutoff,
            asOf: reviewCutoff
        )
        let courseSummaries = courseSummaries(classes: classes, sessions: selectedSessions)
        let mostStudiedCourse = courseSummaries
            .filter { $0.seconds > 0 }
            .sorted(by: descendingCourseOrder)
            .first
        let leastStudiedActiveCourse = courseSummaries
            .filter { summary in
                classes.contains { $0.id == summary.courseID && !$0.isArchived }
            }
            .sorted(by: ascendingCourseOrder)
            .first
        let averageSessionDuration = selectedSessions.isEmpty
            ? 0
            : totalStudyTime / Double(selectedSessions.count)
        let focusRatings = selectedSessions.compactMap(\.focusRating)
        let averageFocusRating = focusRatings.count >= minimumFocusRatings
            ? Double(focusRatings.reduce(0, +)) / Double(focusRatings.count)
            : nil
        let pomodoroIntervalsCompleted = selectedSessions
            .filter { $0.source == .pomodoro }
            .reduce(0) { $0 + $1.pomodoroIntervalCount }
        let daySummaries = daySummaries(sessions: selectedSessions)
        let bestStudyDay = daySummaries.sorted { left, right in
            if left.seconds != right.seconds {
                return left.seconds > right.seconds
            }
            return left.date < right.date
        }.first
        let goalStatus = goalStatus(
            goals: goals,
            sessions: sessionsThroughCutoff,
            weekInterval: weekInterval,
            reviewCutoff: reviewCutoff,
            asOf: date
        )
        let targetSuggestion = targetSuggestion(
            sessions: sessions,
            weekInterval: weekInterval,
            reviewCutoff: reviewCutoff,
            asOf: date
        )
        let insights = insights(
            totalStudyTime: totalStudyTime,
            previousWeekStudyTime: previousWeekStudyTime,
            weekOverWeekChange: weekOverWeekChange,
            activeStudyDays: activeStudyDays,
            mostStudiedCourse: mostStudiedCourse,
            leastStudiedActiveCourse: leastStudiedActiveCourse,
            bestStudyDay: bestStudyDay,
            averageFocusRating: averageFocusRating,
            goalsBehind: goalStatus.behind
        )

        return WeeklyReviewSnapshot(
            weekInterval: weekInterval,
            reviewCutoff: reviewCutoff,
            totalStudyTime: totalStudyTime,
            previousWeekStudyTime: previousWeekStudyTime,
            weekOverWeekChange: weekOverWeekChange,
            activeStudyDays: activeStudyDays,
            currentStreak: currentStreak,
            mostStudiedCourse: mostStudiedCourse,
            leastStudiedActiveCourse: leastStudiedActiveCourse,
            averageSessionDuration: averageSessionDuration,
            averageFocusRating: averageFocusRating,
            ratedSessionCount: focusRatings.count,
            pomodoroIntervalsCompleted: pomodoroIntervalsCompleted,
            goalsCompleted: goalStatus.completed,
            goalsBehind: goalStatus.behind,
            bestStudyDay: bestStudyDay,
            insights: insights,
            targetSuggestion: targetSuggestion
        )
    }

    private func courseSummaries(
        classes: [StudyClass],
        sessions: [StudySession]
    ) -> [WeeklyCourseSummary] {
        let totals = Dictionary(grouping: sessions, by: \.classID)
            .mapValues { grouped in grouped.reduce(0) { $0 + $1.duration } }
        var summaries = classes.map { studyClass in
            WeeklyCourseSummary(
                courseID: studyClass.id,
                name: studyClass.name,
                colorHex: studyClass.colorHex,
                seconds: totals[studyClass.id] ?? 0
            )
        }
        let knownIDs = Set(classes.map(\.id))
        let unknownIDs = Set(sessions.map(\.classID)).subtracting(knownIDs)
        summaries.append(contentsOf: unknownIDs.map { courseID in
            WeeklyCourseSummary(
                courseID: courseID,
                name: "Unknown Course",
                colorHex: "#6B7280",
                seconds: totals[courseID] ?? 0
            )
        })
        return summaries
    }

    private func daySummaries(sessions: [StudySession]) -> [WeeklyDaySummary] {
        Dictionary(grouping: sessions) {
            calendar.startOfDay(for: $0.startedAt)
        }
        .map { date, grouped in
            WeeklyDaySummary(
                date: date,
                seconds: grouped.reduce(0) { $0 + $1.duration }
            )
        }
    }

    private func goalStatus(
        goals: [StudyGoal],
        sessions: [StudySession],
        weekInterval: DateInterval,
        reviewCutoff: Date,
        asOf date: Date
    ) -> (completed: Int, behind: Int) {
        let service = GoalProgressService(calendar: calendar)
        let activeGoals = goals.filter {
            !$0.isArchived && $0.startDate <= reviewCutoff
        }
        let weekIsComplete = weekInterval.end <= date
        var completed = 0
        var behind = 0

        for goal in activeGoals {
            let progress = service.progress(for: goal, sessions: sessions, asOf: reviewCutoff)
            if progress.isComplete {
                completed += 1
                continue
            }

            if goal.kind == .course,
               let pacing = service.coursePacing(for: goal, sessions: sessions, asOf: reviewCutoff) {
                switch pacing.status {
                case .behind, .overdue, .noRecentData, .invalidCourse:
                    behind += 1
                case .complete, .onTrack, .noTargetDate:
                    break
                }
            } else if progress.isOverdue || weekIsComplete {
                behind += 1
            }
        }

        return (completed, behind)
    }

    private func targetSuggestion(
        sessions: [StudySession],
        weekInterval: DateInterval,
        reviewCutoff: Date,
        asOf date: Date
    ) -> WeeklyTargetSuggestion? {
        let weekIntervals = (0..<4).compactMap { offset -> DateInterval? in
            guard let start = calendar.date(
                byAdding: .weekOfYear,
                value: -offset,
                to: weekInterval.start
            ) else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: start)
        }
        let history = weekIntervals.map { interval -> (duration: TimeInterval, activeDays: Int) in
            let cutoff = interval == weekInterval
                ? reviewCutoff
                : min(date, interval.end.addingTimeInterval(-0.001))
            let relevant = validSessions(sessions, in: interval, through: cutoff)
            return (
                relevant.reduce(0) { $0 + $1.duration },
                Set(relevant.map { calendar.startOfDay(for: $0.startedAt) }).count
            )
        }
        let nonzeroWeeks = history.filter { $0.duration > 0 }
        guard !nonzeroWeeks.isEmpty else { return nil }

        let averageDuration = nonzeroWeeks.reduce(0) { $0 + $1.duration }
            / Double(nonzeroWeeks.count)
        let selectedDuration = history.first?.duration ?? 0
        let baseline = max(selectedDuration, averageDuration)
        let fifteenMinutes: TimeInterval = 900
        let suggestedTotal = ceil((baseline * 1.05) / fifteenMinutes) * fifteenMinutes
        let averageActiveDays = Double(nonzeroWeeks.reduce(0) { $0 + $1.activeDays })
            / Double(nonzeroWeeks.count)
        let activeDayTarget = min(7, max(1, Int(averageActiveDays.rounded())))

        return WeeklyTargetSuggestion(
            totalDuration: suggestedTotal,
            activeDayTarget: activeDayTarget,
            dailyDuration: suggestedTotal / Double(activeDayTarget)
        )
    }

    private func insights(
        totalStudyTime: TimeInterval,
        previousWeekStudyTime: TimeInterval,
        weekOverWeekChange: Double?,
        activeStudyDays: Int,
        mostStudiedCourse: WeeklyCourseSummary?,
        leastStudiedActiveCourse: WeeklyCourseSummary?,
        bestStudyDay: WeeklyDaySummary?,
        averageFocusRating: Double?,
        goalsBehind: Int
    ) -> [String] {
        guard totalStudyTime > 0 else {
            return ["No study sessions were logged for this week."]
        }

        var messages: [String] = []
        if let weekOverWeekChange {
            let percent = Int((abs(weekOverWeekChange) * 100).rounded())
            if weekOverWeekChange > 0 {
                messages.append("Study time increased \(percent)% from the previous week.")
            } else if weekOverWeekChange < 0 {
                messages.append("Study time decreased \(percent)% from the previous week.")
            } else {
                messages.append("Study time matched the previous week.")
            }
        } else if previousWeekStudyTime == 0 {
            messages.append("This week established a new study-time baseline.")
        }

        messages.append("Study activity was recorded on \(activeStudyDays) days.")
        if let mostStudiedCourse {
            messages.append("Most studied: \(mostStudiedCourse.name) at \(mostStudiedCourse.seconds.compactDuration).")
        }
        if let leastStudiedActiveCourse, leastStudiedActiveCourse.seconds == 0 {
            messages.append("\(leastStudiedActiveCourse.name) had no logged study time.")
        }
        if let bestStudyDay {
            let day = weekdayName(for: bestStudyDay.date)
            messages.append("Best study day: \(day) with \(bestStudyDay.seconds.compactDuration).")
        }
        if let averageFocusRating {
            messages.append("Average focus rating: \(String(format: "%.1f", averageFocusRating)) out of 5.")
        }
        if goalsBehind > 0 {
            messages.append("\(goalsBehind) active goal\(goalsBehind == 1 ? " is" : "s are") behind pace.")
        }
        return messages
    }

    private func validSessions(
        _ sessions: [StudySession],
        in interval: DateInterval,
        through cutoff: Date
    ) -> [StudySession] {
        sessions.filter {
            isValid($0) && interval.contains($0.startedAt) && $0.startedAt <= cutoff
        }
    }

    private func isValid(_ session: StudySession) -> Bool {
        session.duration.isFinite && session.duration > 0
    }

    private func change(current: TimeInterval, previous: TimeInterval) -> Double? {
        guard previous > 0 else {
            return current == 0 ? 0 : nil
        }
        return (current - previous) / previous
    }

    private func fallbackWeek(containing date: Date) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? date
        return DateInterval(start: start, end: end)
    }

    private func previousWeek(before interval: DateInterval) -> DateInterval {
        let start = calendar.date(
            byAdding: .weekOfYear,
            value: -1,
            to: interval.start
        ) ?? interval.start.addingTimeInterval(-604_800)
        return calendar.dateInterval(of: .weekOfYear, for: start)
            ?? DateInterval(start: start, duration: 604_800)
    }

    private func descendingCourseOrder(
        _ left: WeeklyCourseSummary,
        _ right: WeeklyCourseSummary
    ) -> Bool {
        if left.seconds != right.seconds {
            return left.seconds > right.seconds
        }
        return left.name.lowercased() < right.name.lowercased()
    }

    private func ascendingCourseOrder(
        _ left: WeeklyCourseSummary,
        _ right: WeeklyCourseSummary
    ) -> Bool {
        if left.seconds != right.seconds {
            return left.seconds < right.seconds
        }
        return left.name.lowercased() < right.name.lowercased()
    }

    private func weekdayName(for date: Date) -> String {
        switch calendar.component(.weekday, from: date) {
        case 1: "Sunday"
        case 2: "Monday"
        case 3: "Tuesday"
        case 4: "Wednesday"
        case 5: "Thursday"
        case 6: "Friday"
        case 7: "Saturday"
        default: "Study day"
        }
    }
}
