import Foundation
import SwiftUI
import AppKit

struct StudyData: Codable, Equatable {
    static let currentSchemaVersion = 8

    var schemaVersion: Int = currentSchemaVersion
    var classes: [StudyClass] = []
    var sessions: [StudySession] = []
    var goals: [StudyGoal] = []
    var chartSettings = ChartSettings()
    var pomodoroSettings = PomodoroSettings()
    var dashboardLayout = DashboardLayout()

    init(
        schemaVersion: Int = currentSchemaVersion,
        classes: [StudyClass] = [],
        sessions: [StudySession] = [],
        goals: [StudyGoal] = [],
        chartSettings: ChartSettings = ChartSettings(),
        pomodoroSettings: PomodoroSettings = PomodoroSettings(),
        dashboardLayout: DashboardLayout = DashboardLayout()
    ) {
        self.schemaVersion = schemaVersion
        self.classes = classes
        self.sessions = sessions
        self.goals = goals
        self.chartSettings = chartSettings
        self.pomodoroSettings = pomodoroSettings
        self.dashboardLayout = dashboardLayout
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case classes
        case sessions
        case goals
        case chartSettings
        case pomodoroSettings
        case dashboardLayout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        classes = try container.decodeIfPresent([StudyClass].self, forKey: .classes) ?? []
        sessions = try container.decodeIfPresent([StudySession].self, forKey: .sessions) ?? []
        goals = try container.decodeIfPresent([StudyGoal].self, forKey: .goals) ?? []
        chartSettings = try container.decodeIfPresent(ChartSettings.self, forKey: .chartSettings) ?? ChartSettings()
        pomodoroSettings = try container.decodeIfPresent(PomodoroSettings.self, forKey: .pomodoroSettings) ?? PomodoroSettings()
        let decodedDashboardLayout = try container.decodeIfPresent(
            DashboardLayout.self,
            forKey: .dashboardLayout
        ) ?? DashboardLayout()
        dashboardLayout = DashboardLayoutService().normalized(decodedDashboardLayout)
    }

    mutating func migrateToCurrentSchema(legacyPomodoroSettings: PomodoroSettings?) {
        if schemaVersion < 2, let legacyPomodoroSettings {
            pomodoroSettings = legacyPomodoroSettings
        }

        pomodoroSettings.normalize()
        dashboardLayout = DashboardLayoutService().normalized(dashboardLayout)
        schemaVersion = Self.currentSchemaVersion
    }
}

struct StudyClass: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    var courseCode: String?
    var creditValue: Double?
    var startDate: Date?
    var targetCompletionDate: Date?
    var plannedStudyHours: Double?
    var status: CourseStatus
    var completionDate: Date?
    var progressPercentage: Double
    var weeklyStudyHoursTarget: Double?
    var priority: CoursePriority?
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        courseCode: String? = nil,
        creditValue: Double? = nil,
        startDate: Date? = nil,
        targetCompletionDate: Date? = nil,
        plannedStudyHours: Double? = nil,
        status: CourseStatus = .active,
        completionDate: Date? = nil,
        progressPercentage: Double = 0,
        weeklyStudyHoursTarget: Double? = nil,
        priority: CoursePriority? = nil,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.courseCode = Self.normalizedCode(courseCode)
        self.creditValue = Self.normalizedOptionalNumber(creditValue)
        self.startDate = startDate
        self.targetCompletionDate = targetCompletionDate
        self.plannedStudyHours = Self.normalizedOptionalNumber(plannedStudyHours)
        self.status = status
        self.completionDate = completionDate
        self.progressPercentage = Self.normalizedProgress(progressPercentage)
        self.weeklyStudyHoursTarget = Self.normalizedOptionalNumber(weeklyStudyHoursTarget)
        self.priority = priority
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case colorHex
        case courseCode
        case creditValue
        case startDate
        case targetCompletionDate
        case plannedStudyHours
        case status
        case completionDate
        case progressPercentage
        case weeklyStudyHoursTarget
        case priority
        case isArchived
        case archivedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#6B7280"
        courseCode = Self.normalizedCode(
            try container.decodeIfPresent(String.self, forKey: .courseCode)
        )
        creditValue = Self.normalizedOptionalNumber(
            try container.decodeIfPresent(Double.self, forKey: .creditValue)
        )
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        targetCompletionDate = try container.decodeIfPresent(Date.self, forKey: .targetCompletionDate)
        plannedStudyHours = Self.normalizedOptionalNumber(
            try container.decodeIfPresent(Double.self, forKey: .plannedStudyHours)
        )
        status = try container.decodeIfPresent(CourseStatus.self, forKey: .status) ?? .active
        completionDate = try container.decodeIfPresent(Date.self, forKey: .completionDate)
        progressPercentage = Self.normalizedProgress(
            try container.decodeIfPresent(Double.self, forKey: .progressPercentage) ?? 0
        )
        weeklyStudyHoursTarget = Self.normalizedOptionalNumber(
            try container.decodeIfPresent(Double.self, forKey: .weeklyStudyHoursTarget)
        )
        priority = try container.decodeIfPresent(CoursePriority.self, forKey: .priority)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
    }

    private static func normalizedCode(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedOptionalNumber(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func normalizedProgress(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 100)
    }
}

enum CourseStatus: String, Codable, CaseIterable, Hashable, Identifiable {
    case notStarted
    case active
    case paused
    case completed

    var id: String { rawValue }
}

enum CoursePriority: String, Codable, CaseIterable, Hashable, Identifiable {
    case low
    case normal
    case high
    case critical

    var id: String { rawValue }
}

struct StudySession: Identifiable, Codable, Hashable {
    var id: UUID
    var classID: UUID
    var startedAt: Date
    var endedAt: Date
    var duration: TimeInterval
    var source: StudySessionSource
    var pomodoroIntervalCount: Int
    var focusRating: Int?
    var energyRating: Int?
    var distractionRating: Int?
    var topic: String?
    var completionState: SessionCompletionState

    init(
        id: UUID = UUID(),
        classID: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        duration: TimeInterval,
        source: StudySessionSource = .manual,
        pomodoroIntervalCount: Int = 0,
        focusRating: Int? = nil,
        energyRating: Int? = nil,
        distractionRating: Int? = nil,
        topic: String? = nil,
        completionState: SessionCompletionState? = nil
    ) {
        self.id = id
        self.classID = classID
        self.startedAt = startedAt
        self.duration = duration
        let calculatedEnd = startedAt.addingTimeInterval(max(0, duration))
        self.endedAt = endedAt.map { max($0, startedAt) } ?? calculatedEnd
        self.source = source
        self.pomodoroIntervalCount = max(0, pomodoroIntervalCount)
        self.focusRating = Self.normalizedRating(focusRating)
        self.energyRating = Self.normalizedRating(energyRating)
        self.distractionRating = Self.normalizedRating(distractionRating)
        self.topic = Self.normalizedTopic(topic)
        self.completionState = completionState
            ?? (source == .manual ? .manuallyEntered : .completedNormally)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case classID
        case startedAt
        case endedAt
        case legacyDate = "date"
        case duration
        case source
        case pomodoroIntervalCount
        case focusRating
        case energyRating
        case distractionRating
        case topic
        case completionState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        classID = try container.decode(UUID.self, forKey: .classID)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
            ?? container.decode(Date.self, forKey: .legacyDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
            ?? startedAt.addingTimeInterval(max(0, duration))
        source = try container.decodeIfPresent(StudySessionSource.self, forKey: .source) ?? .manual
        pomodoroIntervalCount = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .pomodoroIntervalCount) ?? 0
        )
        focusRating = Self.normalizedRating(
            try container.decodeIfPresent(Int.self, forKey: .focusRating)
        )
        energyRating = Self.normalizedRating(
            try container.decodeIfPresent(Int.self, forKey: .energyRating)
        )
        distractionRating = Self.normalizedRating(
            try container.decodeIfPresent(Int.self, forKey: .distractionRating)
        )
        topic = Self.normalizedTopic(
            try container.decodeIfPresent(String.self, forKey: .topic)
        )
        completionState = try container.decodeIfPresent(
            SessionCompletionState.self,
            forKey: .completionState
        ) ?? (source == .manual ? .manuallyEntered : .completedNormally)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(classID, forKey: .classID)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(duration, forKey: .duration)
        try container.encode(source, forKey: .source)
        try container.encode(pomodoroIntervalCount, forKey: .pomodoroIntervalCount)
        try container.encodeIfPresent(focusRating, forKey: .focusRating)
        try container.encodeIfPresent(energyRating, forKey: .energyRating)
        try container.encodeIfPresent(distractionRating, forKey: .distractionRating)
        try container.encodeIfPresent(topic, forKey: .topic)
        try container.encode(completionState, forKey: .completionState)
    }

    private static func normalizedRating(_ rating: Int?) -> Int? {
        guard let rating, (1...5).contains(rating) else { return nil }
        return rating
    }

    private static func normalizedTopic(_ topic: String?) -> String? {
        guard let topic else { return nil }
        let trimmed = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum StudySessionSource: String, Codable, Hashable {
    case manual
    case timer
    case pomodoro
}

enum SessionCompletionState: String, Codable, CaseIterable, Hashable, Identifiable {
    case completedNormally
    case stoppedEarly
    case manuallyEntered

    var id: String { rawValue }
}

struct ChartSettings: Codable, Equatable {
    var dailyBarColorHex: String

    init(dailyBarColorHex: String = "#2563EB") {
        self.dailyBarColorHex = dailyBarColorHex
    }

    private enum CodingKeys: String, CodingKey {
        case dailyBarColorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyBarColorHex = try container.decodeIfPresent(String.self, forKey: .dailyBarColorHex) ?? "#2563EB"
    }
}

struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Int
    var shortBreakMinutes: Int
    var longBreakMinutes: Int

    init(focusMinutes: Int = 25, shortBreakMinutes: Int = 5, longBreakMinutes: Int = 15) {
        self.focusMinutes = focusMinutes
        self.shortBreakMinutes = shortBreakMinutes
        self.longBreakMinutes = longBreakMinutes
        normalize()
    }

    private enum CodingKeys: String, CodingKey {
        case focusMinutes
        case shortBreakMinutes
        case longBreakMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
        shortBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? 5
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15
        normalize()
    }

    mutating func normalize() {
        focusMinutes = min(max(focusMinutes, 1), 180)
        shortBreakMinutes = min(max(shortBreakMinutes, 1), 60)
        longBreakMinutes = min(max(longBreakMinutes, 1), 90)
    }
}

struct DailyTotal: Identifiable {
    var id: Date { date }
    let date: Date
    let seconds: TimeInterval
}

struct DailyClassTotal: Identifiable {
    struct ID: Hashable {
        let date: Date
        let classID: UUID
    }

    var id: ID { ID(date: date, classID: studyClass.id) }
    let date: Date
    let studyClass: StudyClass
    let seconds: TimeInterval
}

struct ClassTotal: Identifiable {
    var id: UUID { studyClass.id }
    let studyClass: StudyClass
    let seconds: TimeInterval
}

enum SidebarSelection: Hashable {
    case dashboard
    case insights
    case weeklyReview
    case goals
    case archivedCourses
    case pomodoro
    case settings
    case studyClass(UUID)
}

extension TimeInterval {
    var hours: Double {
        self / 3600
    }

    var compactDuration: String {
        let totalSeconds = max(0, Int(self))
        if totalSeconds < 60 {
            return "\(totalSeconds)s"
        }

        let totalMinutes = totalSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }

    var timerDuration: String {
        let totalSeconds = max(0, Int(self))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    var hhMMDuration: String {
        let totalMinutes = max(0, Int(self / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double

        switch cleaned.count {
        case 6:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        default:
            red = 0.2
            green = 0.2
            blue = 0.2
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    func hexString() -> String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else {
            return nil
        }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}
