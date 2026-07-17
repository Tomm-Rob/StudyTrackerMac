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
        asOf date: Date = Date()
    ) -> InsightsSnapshot {
        let relevantSessions = sessions.filter { session in
            guard session.duration.isFinite,
                  session.duration > 0,
                  session.startedAt <= date else { return false }
            return interval?.contains(session.startedAt) ?? true
        }
        let totalStudyTime = relevantSessions.reduce(0) { $0 + $1.duration }
        let averageSessionDuration = relevantSessions.isEmpty
            ? 0
            : totalStudyTime / Double(relevantSessions.count)
        let activeDayCount = Set(
            relevantSessions.map { calendar.startOfDay(for: $0.startedAt) }
        ).count
        let pomodoroIntervalCount = relevantSessions
            .filter { $0.source == .pomodoro }
            .reduce(0) { $0 + $1.pomodoroIntervalCount }
        let courseTotals = makeCourseTotals(classes: classes, sessions: relevantSessions)
        let weekdayTotals = makeWeekdayTotals(sessions: relevantSessions)
        let hourlyTotals = makeHourlyTotals(sessions: relevantSessions)
        let messages = makeMessages(
            sessions: relevantSessions,
            totalStudyTime: totalStudyTime,
            averageSessionDuration: averageSessionDuration,
            activeDayCount: activeDayCount,
            courseTotals: courseTotals,
            weekdayTotals: weekdayTotals,
            interval: interval,
            asOf: date
        )

        return InsightsSnapshot(
            totalStudyTime: totalStudyTime,
            averageSessionDuration: averageSessionDuration,
            sessionCount: relevantSessions.count,
            activeDayCount: activeDayCount,
            pomodoroIntervalCount: pomodoroIntervalCount,
            courseCount: courseTotals.count,
            courseTotals: courseTotals,
            weekdayTotals: weekdayTotals,
            hourlyTotals: hourlyTotals,
            messages: messages
        )
    }

    private func makeCourseTotals(
        classes: [StudyClass],
        sessions: [StudySession]
    ) -> [CourseInsightTotal] {
        let classesByID = Dictionary(uniqueKeysWithValues: classes.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: sessions, by: \.classID)

        return grouped.map { courseID, groupedSessions in
            let studyClass = classesByID[courseID]
            return CourseInsightTotal(
                courseID: courseID,
                name: studyClass?.name ?? "Unknown Course",
                colorHex: studyClass?.colorHex ?? "#6B7280",
                seconds: groupedSessions.reduce(0) { $0 + $1.duration }
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
            WeekdayInsightTotal(
                weekday: weekday,
                label: weekdayLabel(weekday),
                seconds: grouped[weekday]?.reduce(0) { $0 + $1.duration } ?? 0
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

    private func makeMessages(
        sessions: [StudySession],
        totalStudyTime: TimeInterval,
        averageSessionDuration: TimeInterval,
        activeDayCount: Int,
        courseTotals: [CourseInsightTotal],
        weekdayTotals: [WeekdayInsightTotal],
        interval: DateInterval?,
        asOf date: Date
    ) -> [String] {
        guard !sessions.isEmpty else {
            return ["Log a study session in this range to generate local insights."]
        }

        var messages: [String] = []
        if let topCourse = courseTotals.first {
            messages.append(
                "Most studied: \(topCourse.name) with \(topCourse.seconds.compactDuration)."
            )
        }

        if let strongestDay = weekdayTotals
            .filter({ $0.seconds > 0 })
            .max(by: { $0.seconds < $1.seconds }) {
            messages.append(
                "Strongest study day: \(strongestDay.label) at \(strongestDay.seconds.compactDuration)."
            )
        }

        messages.append("Average session length: \(averageSessionDuration.compactDuration).")

        if let selectedDayCount = selectedDayCount(interval: interval, asOf: date) {
            messages.append("Study activity appeared on \(activeDayCount) of \(selectedDayCount) selected days.")
        } else {
            messages.append("Study activity spans \(activeDayCount) different days all time.")
        }

        if totalStudyTime > 0, courseTotals.count > 1 {
            let topShare = courseTotals[0].seconds / totalStudyTime
            if topShare >= 0.6 {
                messages.append("\(courseTotals[0].name) accounts for \(Int((topShare * 100).rounded()))% of this range.")
            }
        }

        return messages
    }

    private func selectedDayCount(interval: DateInterval?, asOf date: Date) -> Int? {
        guard let interval else { return nil }
        let effectiveEnd = min(interval.end, date.addingTimeInterval(0.001))
        guard interval.start < effectiveEnd else { return 0 }

        let startDay = calendar.startOfDay(for: interval.start)
        let lastIncludedDate = effectiveEnd.addingTimeInterval(-0.001)
        let endDay = calendar.startOfDay(for: lastIncludedDate)
        let difference = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(0, difference + 1)
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
