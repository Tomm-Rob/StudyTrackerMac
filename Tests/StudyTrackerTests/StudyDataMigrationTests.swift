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
        XCTAssertEqual(data.sessions[0].source, .manual)
        XCTAssertEqual(data.sessions[0].pomodoroIntervalCount, 0)
        XCTAssertNil(data.sessions[0].focusRating)
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

    func testCurrentSessionEncodingUsesAnalyticsFieldsAndStartedAt() throws {
        let studyClass = StudyClass(name: "Chemistry", colorHex: "#DB2777")
        let session = StudySession(
            classID: studyClass.id,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 1_800,
            source: .pomodoro,
            pomodoroIntervalCount: 1,
            focusRating: 4
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
        XCTAssertNil(encodedSession["date"])
        XCTAssertEqual(encodedSession["source"] as? String, "pomodoro")
        XCTAssertEqual(encodedSession["pomodoroIntervalCount"] as? Int, 1)
        XCTAssertEqual(encodedSession["focusRating"] as? Int, 4)
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
