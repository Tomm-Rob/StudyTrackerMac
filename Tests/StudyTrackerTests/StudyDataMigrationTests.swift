import Foundation
import XCTest
@testable import StudyTracker

final class StudyDataMigrationTests: XCTestCase {
    func testVersionOneDataDecodesWithAnalyticsDefaults() throws {
        let classID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let json = """
        {
          "classes": [{
            "id": "\(classID.uuidString)",
            "name": "Biology",
            "colorHex": "#16A34A"
          }],
          "sessions": [{
            "id": "22222222-2222-2222-2222-222222222222",
            "classID": "\(classID.uuidString)",
            "date": "2026-07-15T14:00:00Z",
            "duration": 5400
          }],
          "chartSettings": {"dailyBarColorHex": "#2563EB"}
        }
        """

        var data = try decoder.decode(StudyData.self, from: Data(json.utf8))

        XCTAssertEqual(data.schemaVersion, 1)
        XCTAssertFalse(data.classes[0].isArchived)
        XCTAssertEqual(data.classes[0].status, .active)
        XCTAssertEqual(data.classes[0].progressPercentage, 0)
        XCTAssertNil(data.classes[0].courseCode)
        XCTAssertNil(data.classes[0].plannedStudyHours)
        XCTAssertEqual(data.sessions[0].source, .manual)
        XCTAssertEqual(data.sessions[0].pomodoroIntervalCount, 0)
        XCTAssertNil(data.sessions[0].focusRating)
        XCTAssertEqual(
            data.sessions[0].endedAt,
            data.sessions[0].startedAt.addingTimeInterval(data.sessions[0].duration)
        )
        XCTAssertNil(data.sessions[0].energyRating)
        XCTAssertNil(data.sessions[0].distractionRating)
        XCTAssertNil(data.sessions[0].topic)
        XCTAssertEqual(data.sessions[0].completionState, .manuallyEntered)
        XCTAssertEqual(data.pomodoroSettings, PomodoroSettings())
        XCTAssertTrue(data.goals.isEmpty)
        XCTAssertEqual(data.dashboardLayout, DashboardLayout())

        data.migrateToCurrentSchema(legacyPomodoroSettings: nil)
        XCTAssertEqual(data.schemaVersion, StudyData.currentSchemaVersion)
    }

    func testVersionTwoSessionDecodesWithAnalyticsDefaults() throws {
        let classID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let json = """
        {
          "schemaVersion": 2,
          "classes": [],
          "sessions": [{
            "id": "22222222-2222-2222-2222-222222222222",
            "classID": "\(classID.uuidString)",
            "startedAt": "2026-07-15T14:00:00Z",
            "duration": 1800
          }],
          "chartSettings": {},
          "pomodoroSettings": {}
        }
        """

        let data = try decoder.decode(StudyData.self, from: Data(json.utf8))

        XCTAssertEqual(data.schemaVersion, 2)
        XCTAssertEqual(data.sessions[0].source, .manual)
        XCTAssertEqual(data.sessions[0].pomodoroIntervalCount, 0)
        XCTAssertNil(data.sessions[0].focusRating)
        XCTAssertEqual(data.sessions[0].completionState, .manuallyEntered)
        XCTAssertEqual(data.chartSettings.dailyBarColorHex, "#2563EB")
        XCTAssertEqual(data.pomodoroSettings, PomodoroSettings())
        XCTAssertTrue(data.goals.isEmpty)
        XCTAssertEqual(data.dashboardLayout, DashboardLayout())
    }

    func testVersionThreeDataDecodesWithEmptyGoals() throws {
        let json = """
        {
          "schemaVersion": 3,
          "classes": [],
          "sessions": [],
          "chartSettings": {},
          "pomodoroSettings": {}
        }
        """

        var data = try decoder.decode(StudyData.self, from: Data(json.utf8))

        XCTAssertTrue(data.goals.isEmpty)
        data.migrateToCurrentSchema(legacyPomodoroSettings: nil)
        XCTAssertEqual(data.schemaVersion, StudyData.currentSchemaVersion)
    }

    func testVersionFourSessionDecodesWithoutFocusRating() throws {
        let classID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let json = """
        {
          "schemaVersion": 4,
          "classes": [],
          "sessions": [{
            "id": "22222222-2222-2222-2222-222222222222",
            "classID": "\(classID.uuidString)",
            "startedAt": "2026-07-15T14:00:00Z",
            "duration": 1800,
            "source": "manual",
            "pomodoroIntervalCount": 0
          }],
          "goals": [],
          "chartSettings": {},
          "pomodoroSettings": {}
        }
        """

        let data = try decoder.decode(StudyData.self, from: Data(json.utf8))

        XCTAssertEqual(data.schemaVersion, 4)
        XCTAssertNil(data.sessions[0].focusRating)
    }

    func testVersionFiveDataDecodesWithDefaultDashboardLayout() throws {
        let json = """
        {
          "schemaVersion": 5,
          "classes": [],
          "sessions": [],
          "goals": [],
          "chartSettings": {},
          "pomodoroSettings": {}
        }
        """

        var data = try decoder.decode(StudyData.self, from: Data(json.utf8))

        XCTAssertEqual(data.schemaVersion, 5)
        XCTAssertEqual(data.dashboardLayout, DashboardLayout())

        data.migrateToCurrentSchema(legacyPomodoroSettings: nil)
        XCTAssertEqual(data.schemaVersion, StudyData.currentSchemaVersion)
        XCTAssertEqual(data.dashboardLayout, DashboardLayout())
    }

    func testVersionSixCourseDecodesWithPlanningDefaults() throws {
        let json = """
        {
          "schemaVersion": 6,
          "classes": [{
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Biology",
            "colorHex": "#16A34A"
          }],
          "sessions": [],
          "goals": [],
          "chartSettings": {},
          "pomodoroSettings": {},
          "dashboardLayout": {"cards": []}
        }
        """

        var data = try decoder.decode(StudyData.self, from: Data(json.utf8))
        let course = try XCTUnwrap(data.classes.first)

        XCTAssertEqual(course.status, .active)
        XCTAssertEqual(course.progressPercentage, 0)
        XCTAssertNil(course.courseCode)
        XCTAssertNil(course.creditValue)
        XCTAssertNil(course.startDate)
        XCTAssertNil(course.targetCompletionDate)
        XCTAssertNil(course.plannedStudyHours)
        XCTAssertNil(course.completionDate)
        XCTAssertNil(course.weeklyStudyHoursTarget)
        XCTAssertNil(course.priority)

        data.migrateToCurrentSchema(legacyPomodoroSettings: nil)
        XCTAssertEqual(data.schemaVersion, StudyData.currentSchemaVersion)
    }

    func testVersionSevenSessionDecodesWithRicherSessionDefaults() throws {
        let classID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let json = """
        {
          "schemaVersion": 7,
          "classes": [],
          "sessions": [{
            "id": "22222222-2222-2222-2222-222222222222",
            "classID": "\(classID.uuidString)",
            "startedAt": "2026-07-15T14:00:00Z",
            "duration": 1800,
            "source": "timer",
            "pomodoroIntervalCount": 0,
            "focusRating": 4
          }],
          "goals": [],
          "chartSettings": {},
          "pomodoroSettings": {},
          "dashboardLayout": {"cards": []}
        }
        """

        var data = try decoder.decode(StudyData.self, from: Data(json.utf8))
        let session = try XCTUnwrap(data.sessions.first)

        XCTAssertEqual(session.endedAt, session.startedAt.addingTimeInterval(1800))
        XCTAssertEqual(session.focusRating, 4)
        XCTAssertNil(session.energyRating)
        XCTAssertNil(session.distractionRating)
        XCTAssertNil(session.topic)
        XCTAssertEqual(session.completionState, .completedNormally)

        data.migrateToCurrentSchema(legacyPomodoroSettings: nil)
        XCTAssertEqual(data.schemaVersion, StudyData.currentSchemaVersion)
    }

    func testRicherSessionFieldsNormalizeInvalidOptionalValues() {
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let session = StudySession(
            classID: UUID(),
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(-60),
            duration: 1_800,
            source: .timer,
            focusRating: 0,
            energyRating: 6,
            distractionRating: -1,
            topic: "   "
        )

        XCTAssertEqual(session.endedAt, startedAt)
        XCTAssertNil(session.focusRating)
        XCTAssertNil(session.energyRating)
        XCTAssertNil(session.distractionRating)
        XCTAssertNil(session.topic)
        XCTAssertEqual(session.completionState, .completedNormally)
    }

    func testCoursePlanningFieldsEncodeAndNormalize() throws {
        let course = StudyClass(
            name: "Physics",
            colorHex: "#2563EB",
            courseCode: "  PHY 201  ",
            creditValue: 4,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            targetCompletionDate: Date(timeIntervalSince1970: 1_710_000_000),
            plannedStudyHours: 120,
            status: .paused,
            completionDate: nil,
            progressPercentage: 140,
            weeklyStudyHoursTarget: 8.5,
            priority: .high
        )
        let data = StudyData(classes: [course])

        let encoded = try encoder.encode(data)
        let restored = try decoder.decode(StudyData.self, from: encoded)
        let restoredCourse = try XCTUnwrap(restored.classes.first)

        XCTAssertEqual(restoredCourse.courseCode, "PHY 201")
        XCTAssertEqual(restoredCourse.creditValue, 4)
        XCTAssertEqual(restoredCourse.plannedStudyHours, 120)
        XCTAssertEqual(restoredCourse.status, .paused)
        XCTAssertEqual(restoredCourse.progressPercentage, 100)
        XCTAssertEqual(restoredCourse.weeklyStudyHoursTarget, 8.5)
        XCTAssertEqual(restoredCourse.priority, .high)
    }

    func testCurrentSessionEncodingUsesAnalyticsFieldsAndStartedAt() throws {
        let studyClass = StudyClass(name: "Chemistry", colorHex: "#DB2777")
        let session = StudySession(
            classID: studyClass.id,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_001_800),
            duration: 1_800,
            source: .pomodoro,
            pomodoroIntervalCount: 1,
            focusRating: 4,
            energyRating: 3,
            distractionRating: 2,
            topic: "  Stoichiometry  ",
            completionState: .stoppedEarly
        )
        let goal = StudyGoal(
            kind: .course,
            targetDuration: 36_000,
            courseID: studyClass.id,
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            targetDate: Date(timeIntervalSince1970: 1_700_604_800)
        )
        let data = StudyData(classes: [studyClass], sessions: [session], goals: [goal])

        let encoded = try encoder.encode(data)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let sessions = try XCTUnwrap(json["sessions"] as? [[String: Any]])
        let encodedSession = try XCTUnwrap(sessions.first)
        let goals = try XCTUnwrap(json["goals"] as? [[String: Any]])
        let encodedGoal = try XCTUnwrap(goals.first)

        XCTAssertEqual(json["schemaVersion"] as? Int, StudyData.currentSchemaVersion)
        XCTAssertNotNil(encodedSession["startedAt"])
        XCTAssertNotNil(encodedSession["endedAt"])
        XCTAssertNil(encodedSession["date"])
        XCTAssertEqual(encodedSession["source"] as? String, "pomodoro")
        XCTAssertEqual(encodedSession["pomodoroIntervalCount"] as? Int, 1)
        XCTAssertEqual(encodedSession["focusRating"] as? Int, 4)
        XCTAssertEqual(encodedSession["energyRating"] as? Int, 3)
        XCTAssertEqual(encodedSession["distractionRating"] as? Int, 2)
        XCTAssertEqual(encodedSession["topic"] as? String, "Stoichiometry")
        XCTAssertEqual(encodedSession["completionState"] as? String, "stoppedEarly")
        XCTAssertEqual(encodedGoal["kind"] as? String, "course")
        XCTAssertEqual(encodedGoal["targetDuration"] as? Double, 36_000)
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
