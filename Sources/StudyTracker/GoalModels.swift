import Foundation

enum StudyGoalKind: String, Codable, Hashable {
    case daily
    case weekly
    case course
}

struct StudyGoal: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: StudyGoalKind
    var targetDuration: TimeInterval
    var courseID: UUID?
    var startDate: Date
    var targetDate: Date?
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        kind: StudyGoalKind,
        targetDuration: TimeInterval,
        courseID: UUID? = nil,
        startDate: Date,
        targetDate: Date? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.targetDuration = targetDuration.isFinite ? max(0, targetDuration) : 0
        self.courseID = courseID
        self.startDate = startDate
        self.targetDate = targetDate
        self.isArchived = isArchived
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case targetDuration
        case courseID
        case startDate
        case targetDate
        case isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(StudyGoalKind.self, forKey: .kind) ?? .daily
        let decodedTarget = try container.decodeIfPresent(TimeInterval.self, forKey: .targetDuration) ?? 0
        targetDuration = decodedTarget.isFinite ? max(0, decodedTarget) : 0
        courseID = try container.decodeIfPresent(UUID.self, forKey: .courseID)
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
            ?? Date(timeIntervalSince1970: 0)
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }
}

struct GoalProgress: Equatable {
    let goalID: UUID
    let studiedDuration: TimeInterval
    let targetDuration: TimeInterval
    let remainingDuration: TimeInterval
    let completionFraction: Double
    let isComplete: Bool
    let isOverdue: Bool
}

enum CoursePacingStatus: Equatable {
    case complete
    case onTrack
    case behind
    case overdue
    case noRecentData
    case noTargetDate
    case invalidCourse
}

struct CoursePacing: Equatable {
    let goalID: UUID
    let progress: GoalProgress
    let daysRemaining: Int
    let requiredDailyDuration: TimeInterval
    let recentDailyDuration: TimeInterval
    let paceRatio: Double
    let projectedCompletionDate: Date?
    let status: CoursePacingStatus
}
