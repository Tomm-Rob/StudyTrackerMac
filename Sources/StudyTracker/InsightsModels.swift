import Foundation

enum InsightsDateFilter: String, CaseIterable, Identifiable {
    case today
    case thisWeek
    case thisMonth
    case last7Days
    case last30Days
    case thisYear
    case allTime
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .thisWeek: "This week"
        case .thisMonth: "This month"
        case .last7Days: "Last 7 days"
        case .last30Days: "Last 30 days"
        case .thisYear: "This year"
        case .allTime: "All time"
        case .custom: "Custom range"
        }
    }

    func dateInterval(
        asOf date: Date,
        calendar: Calendar,
        customStart: Date,
        customEnd: Date
    ) -> DateInterval? {
        let today = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? date

        switch self {
        case .today:
            return DateInterval(start: today, end: tomorrow)
        case .thisWeek:
            return calendar.dateInterval(of: .weekOfYear, for: date)
        case .thisMonth:
            return calendar.dateInterval(of: .month, for: date)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return DateInterval(start: start, end: tomorrow)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -29, to: today) ?? today
            return DateInterval(start: start, end: tomorrow)
        case .thisYear:
            return calendar.dateInterval(of: .year, for: date)
        case .allTime:
            return nil
        case .custom:
            let lowerDate = min(customStart, customEnd)
            let upperDate = max(customStart, customEnd)
            let start = calendar.startOfDay(for: lowerDate)
            let upperDay = calendar.startOfDay(for: upperDate)
            let end = calendar.date(byAdding: .day, value: 1, to: upperDay) ?? upperDate
            return DateInterval(start: start, end: end)
        }
    }

    func comparisonInterval(
        asOf date: Date,
        calendar: Calendar,
        customStart: Date,
        customEnd: Date
    ) -> DateInterval? {
        guard self != .allTime,
              let current = dateInterval(
                asOf: date,
                calendar: calendar,
                customStart: customStart,
                customEnd: customEnd
              ) else { return nil }

        let effectiveEnd = min(current.end, date.addingTimeInterval(0.001))
        guard current.start < effectiveEnd else { return nil }

        let component: Calendar.Component?
        switch self {
        case .today: component = .day
        case .thisWeek: component = .weekOfYear
        case .thisMonth: component = .month
        case .thisYear: component = .year
        case .last7Days, .last30Days, .custom, .allTime: component = nil
        }

        if let component,
           let start = calendar.date(byAdding: component, value: -1, to: current.start),
           let end = calendar.date(byAdding: component, value: -1, to: effectiveEnd) {
            return DateInterval(start: start, end: end)
        }

        let duration = effectiveEnd.timeIntervalSince(current.start)
        return DateInterval(
            start: current.start.addingTimeInterval(-duration),
            end: current.start
        )
    }
}

struct CourseInsightTotal: Identifiable, Equatable {
    var id: UUID { courseID }
    let courseID: UUID
    let name: String
    let colorHex: String
    let seconds: TimeInterval
    let percentageOfTotal: Double
    let averageSessionDuration: TimeInterval
    let sessionCount: Int
    let lastStudiedDate: Date?
    let plannedStudyHours: Double?
    let plannedProgressFraction: Double?
    let weeklyTargetHours: Double?
    let weeklyTargetProgressFraction: Double?
    let priority: CoursePriority?
    let receivesLessAttention: Bool
}

struct WeekdayInsightTotal: Identifiable, Equatable {
    var id: Int { weekday }
    let weekday: Int
    let label: String
    let seconds: TimeInterval
    let averageFocusRating: Double?
}

enum StudyTimeWindow: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        case .night: "Night"
        }
    }

    var hourRange: String {
        switch self {
        case .morning: "5 AM - 12 PM"
        case .afternoon: "12 PM - 5 PM"
        case .evening: "5 PM - 9 PM"
        case .night: "9 PM - 5 AM"
        }
    }
}

struct TimeWindowInsight: Identifiable, Equatable {
    var id: StudyTimeWindow { window }
    let window: StudyTimeWindow
    let seconds: TimeInterval
    let averageFocusRating: Double?
    let averageSessionDuration: TimeInterval
    let sessionCount: Int
}

struct StudyHeatmapDay: Identifiable, Equatable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
}

struct WeeklyStudyTrend: Identifiable, Equatable {
    var id: Date { weekStart }
    let weekStart: Date
    let seconds: TimeInterval
}

struct PeriodComparison: Equatable {
    let previousInterval: DateInterval
    let currentDuration: TimeInterval
    let previousDuration: TimeInterval
    let numericalDifference: TimeInterval
    let percentageChange: Double?
}

struct HourlyInsightTotal: Identifiable, Equatable {
    var id: Int { hour }
    let hour: Int
    let label: String
    let seconds: TimeInterval
}

enum GeneratedInsightDestination: String, Equatable {
    case overview
    case courses
    case timePatterns
    case consistency
}

struct GeneratedInsight: Identifiable, Equatable {
    let id: String
    let title: String
    let explanation: String
    let dateRangeDescription: String
    let destination: GeneratedInsightDestination?
    let courseID: UUID?

    init(
        id: String,
        title: String,
        explanation: String,
        dateRangeDescription: String,
        destination: GeneratedInsightDestination?,
        courseID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.dateRangeDescription = dateRangeDescription
        self.destination = destination
        self.courseID = courseID
    }
}

struct InsightsSnapshot: Equatable {
    let totalStudyTime: TimeInterval
    let averageStudyTimePerActiveDay: TimeInterval
    let averageSessionDuration: TimeInterval
    let longestSessionDuration: TimeInterval
    let sessionCount: Int
    let activeDayCount: Int
    let selectedDayCount: Int
    let studiedDayPercentage: Double
    let pomodoroIntervalCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let courseCount: Int
    let courseTotals: [CourseInsightTotal]
    let weekdayTotals: [WeekdayInsightTotal]
    let hourlyTotals: [HourlyInsightTotal]
    let timeWindowTotals: [TimeWindowInsight]
    let heatmapDays: [StudyHeatmapDay]
    let weeklyTrend: [WeeklyStudyTrend]
    let comparison: PeriodComparison?
    let mostProductiveDay: WeekdayInsightTotal?
    let mostProductiveTimeWindow: TimeWindowInsight?
    let generatedInsights: [GeneratedInsight]

    var isEmpty: Bool { sessionCount == 0 }

    var messages: [String] {
        generatedInsights.map(\.explanation)
    }
}
