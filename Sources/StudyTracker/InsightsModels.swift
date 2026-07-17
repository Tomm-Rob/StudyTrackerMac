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
}

struct CourseInsightTotal: Identifiable, Equatable {
    var id: UUID { courseID }
    let courseID: UUID
    let name: String
    let colorHex: String
    let seconds: TimeInterval
}

struct WeekdayInsightTotal: Identifiable, Equatable {
    var id: Int { weekday }
    let weekday: Int
    let label: String
    let seconds: TimeInterval
}

struct HourlyInsightTotal: Identifiable, Equatable {
    var id: Int { hour }
    let hour: Int
    let label: String
    let seconds: TimeInterval
}

struct InsightsSnapshot: Equatable {
    let totalStudyTime: TimeInterval
    let averageSessionDuration: TimeInterval
    let sessionCount: Int
    let activeDayCount: Int
    let pomodoroIntervalCount: Int
    let courseCount: Int
    let courseTotals: [CourseInsightTotal]
    let weekdayTotals: [WeekdayInsightTotal]
    let hourlyTotals: [HourlyInsightTotal]
    let messages: [String]

    var isEmpty: Bool { sessionCount == 0 }
}
