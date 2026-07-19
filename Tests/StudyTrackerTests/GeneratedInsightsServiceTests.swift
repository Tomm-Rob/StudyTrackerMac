import Foundation
import XCTest
@testable import StudyTracker

final class GeneratedInsightsServiceTests: XCTestCase {
    private let courseID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private var service: GeneratedInsightsService {
        GeneratedInsightsService(calendar: calendar)
    }

    func testSingleRatedSessionDoesNotCreateFocusOrBestDayInsight() {
        let sessions = [
            session(month: 7, day: 15, hour: 18, duration: 2_400, focus: 5)
        ]

        let insights = generate(sessions: sessions)

        XCTAssertFalse(insights.contains { $0.id == "focus-time-window" })
        XCTAssertFalse(insights.contains { $0.id == "focus-duration" })
        XCTAssertFalse(insights.contains { $0.id == "consistent-weekday" })
        XCTAssertEqual(insights.first?.id, "collecting-data")
    }

    func testFocusWindowRequiresMultipleSamplesAndClearDifference() {
        let sessions = [
            session(month: 7, day: 14, hour: 18, duration: 2_400, focus: 5),
            session(month: 7, day: 15, hour: 19, duration: 2_400, focus: 5),
            session(month: 7, day: 14, hour: 9, duration: 2_400, focus: 3),
            session(month: 7, day: 15, hour: 10, duration: 2_400, focus: 3)
        ]

        let insights = generate(sessions: sessions)
        let focus = insights.first { $0.id == "focus-time-window" }

        XCTAssertEqual(focus?.title, "Highest focus: 6 PM and 9 PM")
        XCTAssertTrue(focus?.explanation.contains("based on 2 rated sessions") == true)
        XCTAssertEqual(focus?.destination, .timePatterns)
    }

    func testConsistentDayRequiresThreeWeeksAndUniqueWinner() {
        let sessions = [
            session(month: 6, day: 23, hour: 9),
            session(month: 6, day: 30, hour: 9),
            session(month: 7, day: 7, hour: 9),
            session(month: 7, day: 8, hour: 9)
        ]

        let insights = generate(sessions: sessions)
        let weekday = insights.first { $0.id == "consistent-weekday" }

        XCTAssertEqual(weekday?.title, "Tuesday is your most consistent day")
        XCTAssertTrue(weekday?.explanation.contains("3 of 3 Tuesdays") == true)
    }

    func testComparisonIsSuppressedWhenEarlierPeriodHasNoData() {
        let sessions = [session(month: 7, day: 15)]
        let comparison = PeriodComparison(
            previousInterval: DateInterval(
                start: date(month: 7, day: 1),
                end: date(month: 7, day: 8)
            ),
            currentDuration: 3_600,
            previousDuration: 0,
            numericalDifference: 3_600,
            percentageChange: nil
        )

        let insights = service.generate(
            classes: [],
            allSessions: sessions,
            selectedSessions: sessions,
            courseTotals: [],
            comparison: comparison,
            interval: nil,
            asOf: date(month: 7, day: 15, hour: 20)
        )

        XCTAssertFalse(insights.contains { $0.id == "period-comparison" })
    }

    func testInactiveCourseAndWeeklyPacingUseExplicitRanges() {
        let studyClass = StudyClass(
            id: courseID,
            name: "D427",
            colorHex: "#2563EB",
            weeklyStudyHoursTarget: 14
        )
        let sessions = [
            session(month: 7, day: 8, duration: 3_600)
        ]

        let insights = generate(classes: [studyClass], sessions: sessions)

        XCTAssertTrue(insights.contains { $0.id == "inactive-course-\(courseID.uuidString)" })
        XCTAssertTrue(insights.contains { $0.id == "weekly-target-\(courseID.uuidString)" })
        XCTAssertTrue(insights.allSatisfy { !$0.dateRangeDescription.isEmpty })
    }

    func testProjectionRequiresThreeRecentStudyDays() {
        let studyClass = StudyClass(
            id: courseID,
            name: "Database Management",
            colorHex: "#2563EB",
            targetCompletionDate: date(month: 7, day: 30),
            plannedStudyHours: 10
        )
        let sessions = [
            session(month: 7, day: 11, duration: 3_600),
            session(month: 7, day: 12, duration: 3_600),
            session(month: 7, day: 13, duration: 3_600)
        ]

        let insights = generate(classes: [studyClass], sessions: sessions)

        XCTAssertTrue(insights.contains { $0.id == "planned-projection-\(courseID.uuidString)" })
    }

    func testInsightListIsDeterministicAndCappedAtFour() {
        let studyClass = StudyClass(
            id: courseID,
            name: "D427",
            colorHex: "#2563EB",
            targetCompletionDate: date(month: 7, day: 30),
            plannedStudyHours: 20,
            weeklyStudyHoursTarget: 14
        )
        let sessions = [
            session(month: 6, day: 23, hour: 18, focus: 5),
            session(month: 6, day: 30, hour: 18, focus: 5),
            session(month: 7, day: 7, hour: 9, focus: 3),
            session(month: 7, day: 8, hour: 9, focus: 3),
            session(month: 7, day: 11),
            session(month: 7, day: 12),
            session(month: 7, day: 13)
        ]
        let comparison = PeriodComparison(
            previousInterval: DateInterval(
                start: date(month: 6, day: 1),
                end: date(month: 6, day: 15)
            ),
            currentDuration: 7_200,
            previousDuration: 3_600,
            numericalDifference: 3_600,
            percentageChange: 1
        )

        let first = service.generate(
            classes: [studyClass],
            allSessions: sessions,
            selectedSessions: sessions,
            courseTotals: [],
            comparison: comparison,
            interval: nil,
            asOf: date(month: 7, day: 15, hour: 20)
        )
        let second = service.generate(
            classes: [studyClass],
            allSessions: sessions,
            selectedSessions: sessions,
            courseTotals: [],
            comparison: comparison,
            interval: nil,
            asOf: date(month: 7, day: 15, hour: 20)
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 4)
    }

    private func generate(
        classes: [StudyClass] = [],
        sessions: [StudySession]
    ) -> [GeneratedInsight] {
        service.generate(
            classes: classes,
            allSessions: sessions,
            selectedSessions: sessions,
            courseTotals: [],
            comparison: nil,
            interval: nil,
            asOf: date(month: 7, day: 15, hour: 20)
        )
    }

    private func session(
        month: Int,
        day: Int,
        hour: Int = 9,
        duration: TimeInterval = 3_600,
        focus: Int? = nil
    ) -> StudySession {
        StudySession(
            classID: courseID,
            startedAt: date(month: month, day: day, hour: hour),
            duration: duration,
            focusRating: focus
        )
    }

    private func date(month: Int, day: Int, hour: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: month, day: day, hour: hour)
        )!
    }
}
