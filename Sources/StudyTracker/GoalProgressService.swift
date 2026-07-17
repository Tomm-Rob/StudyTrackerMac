import Foundation

struct GoalProgressService {
    let calendar: Calendar
    let recentWindowDays: Int

    init(calendar: Calendar = .current, recentWindowDays: Int = 14) {
        self.calendar = calendar
        self.recentWindowDays = max(1, recentWindowDays)
    }

    func progress(
        for goal: StudyGoal,
        sessions: [StudySession],
        asOf date: Date = Date()
    ) -> GoalProgress {
        let studiedDuration = relevantSessions(for: goal, sessions: sessions, asOf: date)
            .reduce(0) { $0 + $1.duration }
        let targetDuration = goal.targetDuration.isFinite ? max(0, goal.targetDuration) : 0
        let remainingDuration = max(0, targetDuration - studiedDuration)
        let isComplete = targetDuration == 0 || studiedDuration >= targetDuration
        let completionFraction = targetDuration == 0
            ? 1
            : min(max(studiedDuration / targetDuration, 0), 1)
        let isPastTarget = goal.targetDate.map {
            calendar.startOfDay(for: $0) < calendar.startOfDay(for: date)
        } ?? false

        return GoalProgress(
            goalID: goal.id,
            studiedDuration: studiedDuration,
            targetDuration: targetDuration,
            remainingDuration: remainingDuration,
            completionFraction: completionFraction,
            isComplete: isComplete,
            isOverdue: isPastTarget && !isComplete
        )
    }

    func coursePacing(
        for goal: StudyGoal,
        sessions: [StudySession],
        asOf date: Date = Date()
    ) -> CoursePacing? {
        guard goal.kind == .course else { return nil }

        let progress = progress(for: goal, sessions: sessions, asOf: date)
        guard let courseID = goal.courseID else {
            return CoursePacing(
                goalID: goal.id,
                progress: progress,
                daysRemaining: 0,
                requiredDailyDuration: 0,
                recentDailyDuration: 0,
                paceRatio: 0,
                projectedCompletionDate: nil,
                status: progress.isComplete ? .complete : .invalidCourse
            )
        }

        let recentDailyDuration = recentDailyStudyRate(
            for: courseID,
            sessions: sessions,
            asOf: date
        )
        let projectedDate = projectedCompletionDate(
            remainingDuration: progress.remainingDuration,
            recentDailyDuration: recentDailyDuration,
            asOf: date
        )

        guard let targetDate = goal.targetDate else {
            return CoursePacing(
                goalID: goal.id,
                progress: progress,
                daysRemaining: 0,
                requiredDailyDuration: 0,
                recentDailyDuration: recentDailyDuration,
                paceRatio: 0,
                projectedCompletionDate: projectedDate,
                status: progress.isComplete ? .complete : .noTargetDate
            )
        }

        let dayDifference = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
        let daysRemaining = max(0, dayDifference + 1)
        let divisor = max(1, daysRemaining)
        let requiredDailyDuration = progress.remainingDuration / Double(divisor)
        let paceRatio = requiredDailyDuration > 0
            ? recentDailyDuration / requiredDailyDuration
            : 1

        let status: CoursePacingStatus
        if progress.isComplete {
            status = .complete
        } else if progress.isOverdue {
            status = .overdue
        } else if recentDailyDuration == 0 {
            status = .noRecentData
        } else if recentDailyDuration >= requiredDailyDuration {
            status = .onTrack
        } else {
            status = .behind
        }

        return CoursePacing(
            goalID: goal.id,
            progress: progress,
            daysRemaining: daysRemaining,
            requiredDailyDuration: requiredDailyDuration,
            recentDailyDuration: recentDailyDuration,
            paceRatio: paceRatio,
            projectedCompletionDate: projectedDate,
            status: status
        )
    }

    func projectedCompletionDate(
        remainingDuration: TimeInterval,
        recentDailyDuration: TimeInterval,
        asOf date: Date = Date()
    ) -> Date? {
        guard remainingDuration.isFinite, recentDailyDuration.isFinite else { return nil }
        guard remainingDuration > 0 else { return calendar.startOfDay(for: date) }
        guard recentDailyDuration > 0 else { return nil }

        let studyDaysNeeded = Int(ceil(remainingDuration / recentDailyDuration))
        let dayOffset = max(0, studyDaysNeeded - 1)
        return calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: calendar.startOfDay(for: date)
        )
    }

    private func recentDailyStudyRate(
        for courseID: UUID,
        sessions: [StudySession],
        asOf date: Date
    ) -> TimeInterval {
        let asOfDay = calendar.startOfDay(for: date)
        let windowStart = calendar.date(
            byAdding: .day,
            value: -(recentWindowDays - 1),
            to: asOfDay
        ) ?? asOfDay
        let recentDuration = sessions
            .filter { session in
                session.classID == courseID
                    && isValid(session)
                    && session.startedAt >= windowStart
                    && session.startedAt <= date
            }
            .reduce(0) { $0 + $1.duration }
        return recentDuration / Double(recentWindowDays)
    }

    private func relevantSessions(
        for goal: StudyGoal,
        sessions: [StudySession],
        asOf date: Date
    ) -> [StudySession] {
        let period = goalPeriod(for: goal, asOf: date)
        return sessions.filter { session in
            guard isValid(session), session.startedAt <= date else { return false }
            guard goal.kind != .course || session.classID == goal.courseID else { return false }
            return session.startedAt >= period.start && session.startedAt < period.end
        }
    }

    private func goalPeriod(for goal: StudyGoal, asOf date: Date) -> DateInterval {
        switch goal.kind {
        case .daily:
            let day = calendar.dateInterval(of: .day, for: date)
                ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
            return period(day, startingAt: goal.startDate)
        case .weekly:
            let week = calendar.dateInterval(of: .weekOfYear, for: date)
                ?? DateInterval(start: calendar.startOfDay(for: date), duration: 604_800)
            return period(week, startingAt: goal.startDate)
        case .course:
            let end = date.addingTimeInterval(0.001)
            guard goal.startDate < end else {
                return DateInterval(start: end, end: end)
            }
            return DateInterval(start: goal.startDate, end: end)
        }
    }

    private func period(_ period: DateInterval, startingAt startDate: Date) -> DateInterval {
        let start = max(period.start, startDate)
        guard start < period.end else {
            return DateInterval(start: period.end, end: period.end)
        }
        return DateInterval(start: start, end: period.end)
    }

    private func isValid(_ session: StudySession) -> Bool {
        session.duration.isFinite && session.duration > 0
    }
}
