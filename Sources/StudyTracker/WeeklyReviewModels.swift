import Foundation

struct WeeklyCourseSummary: Identifiable, Equatable {
    var id: UUID { courseID }
    let courseID: UUID
    let name: String
    let colorHex: String
    let seconds: TimeInterval
}

struct WeeklyDaySummary: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
}

struct WeeklyTargetSuggestion: Equatable {
    let totalDuration: TimeInterval
    let activeDayTarget: Int
    let dailyDuration: TimeInterval
}

struct WeeklyReviewSnapshot: Equatable {
    let weekInterval: DateInterval
    let reviewCutoff: Date
    let totalStudyTime: TimeInterval
    let previousWeekStudyTime: TimeInterval
    let weekOverWeekChange: Double?
    let activeStudyDays: Int
    let currentStreak: Int
    let mostStudiedCourse: WeeklyCourseSummary?
    let leastStudiedActiveCourse: WeeklyCourseSummary?
    let averageSessionDuration: TimeInterval
    let averageFocusRating: Double?
    let ratedSessionCount: Int
    let pomodoroIntervalsCompleted: Int
    let goalsCompleted: Int
    let goalsBehind: Int
    let bestStudyDay: WeeklyDaySummary?
    let insights: [String]
    let targetSuggestion: WeeklyTargetSuggestion?

    var isEmpty: Bool { totalStudyTime == 0 }
}
