import Foundation

struct CourseDateKey: Hashable {
    let date: Date
    let courseID: UUID
}

struct StudyAnalyticsService {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func totalStudyTime(
        in sessions: [StudySession],
        courseID: UUID? = nil,
        interval: DateInterval? = nil
    ) -> TimeInterval {
        filteredSessions(sessions, courseID: courseID, interval: interval)
            .reduce(0) { $0 + $1.duration }
    }

    func averageSessionDuration(
        in sessions: [StudySession],
        courseID: UUID? = nil,
        interval: DateInterval? = nil
    ) -> TimeInterval {
        let relevantSessions = filteredSessions(sessions, courseID: courseID, interval: interval)
        guard !relevantSessions.isEmpty else { return 0 }
        return relevantSessions.reduce(0) { $0 + $1.duration } / Double(relevantSessions.count)
    }

    func studyTimeByDate(
        in sessions: [StudySession],
        courseID: UUID? = nil,
        interval: DateInterval? = nil
    ) -> [Date: TimeInterval] {
        Dictionary(
            grouping: filteredSessions(sessions, courseID: courseID, interval: interval),
            by: { calendar.startOfDay(for: $0.startedAt) }
        )
        .mapValues { groupedSessions in
            groupedSessions.reduce(0) { $0 + $1.duration }
        }
    }

    func studyTimeByDateAndCourse(
        in sessions: [StudySession],
        interval: DateInterval? = nil
    ) -> [CourseDateKey: TimeInterval] {
        Dictionary(
            grouping: filteredSessions(sessions, courseID: nil, interval: interval),
            by: {
                CourseDateKey(
                    date: calendar.startOfDay(for: $0.startedAt),
                    courseID: $0.classID
                )
            }
        )
        .mapValues { groupedSessions in
            groupedSessions.reduce(0) { $0 + $1.duration }
        }
    }

    func studyTimeByWeek(
        in sessions: [StudySession],
        courseID: UUID? = nil,
        interval: DateInterval? = nil
    ) -> [Date: TimeInterval] {
        let relevantSessions = filteredSessions(sessions, courseID: courseID, interval: interval)
        let grouped = Dictionary(grouping: relevantSessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start
                ?? calendar.startOfDay(for: session.startedAt)
        }

        return grouped.mapValues { groupedSessions in
            groupedSessions.reduce(0) { $0 + $1.duration }
        }
    }

    func studyTimeByCourse(
        in sessions: [StudySession],
        interval: DateInterval? = nil
    ) -> [UUID: TimeInterval] {
        Dictionary(
            grouping: filteredSessions(sessions, courseID: nil, interval: interval),
            by: \.classID
        )
        .mapValues { groupedSessions in
            groupedSessions.reduce(0) { $0 + $1.duration }
        }
    }

    func currentStudyStreak(
        in sessions: [StudySession],
        asOf date: Date = Date(),
        courseID: UUID? = nil
    ) -> Int {
        let studyDays = Set(
            filteredSessions(sessions, courseID: courseID, interval: nil)
                .map { calendar.startOfDay(for: $0.startedAt) }
        )
        var day = calendar.startOfDay(for: date)
        // The current streak is active only after study time is logged on the as-of day.
        guard studyDays.contains(day) else { return 0 }

        var streak = 0
        while studyDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else {
                break
            }
            day = previousDay
        }
        return streak
    }

    func longestStudyStreak(
        in sessions: [StudySession],
        courseID: UUID? = nil
    ) -> Int {
        let studyDays = Set(
            filteredSessions(sessions, courseID: courseID, interval: nil)
                .map { calendar.startOfDay(for: $0.startedAt) }
        )
        .sorted()

        var longestStreak = 0
        var currentStreak = 0
        var previousDay: Date?

        for day in studyDays {
            if let previousDay,
               calendar.dateComponents([.day], from: previousDay, to: day).day == 1 {
                currentStreak += 1
            } else {
                currentStreak = 1
            }

            longestStreak = max(longestStreak, currentStreak)
            previousDay = day
        }

        return longestStreak
    }

    func pomodoroIntervalCount(
        in sessions: [StudySession],
        courseID: UUID? = nil,
        interval: DateInterval? = nil
    ) -> Int {
        filteredSessions(sessions, courseID: courseID, interval: interval)
            .filter { $0.source == .pomodoro }
            .reduce(0) { $0 + $1.pomodoroIntervalCount }
    }

    private func filteredSessions(
        _ sessions: [StudySession],
        courseID: UUID?,
        interval: DateInterval?
    ) -> [StudySession] {
        sessions.filter { session in
            guard session.duration.isFinite, session.duration > 0 else { return false }
            guard courseID == nil || session.classID == courseID else { return false }
            return interval?.contains(session.startedAt) ?? true
        }
    }
}
