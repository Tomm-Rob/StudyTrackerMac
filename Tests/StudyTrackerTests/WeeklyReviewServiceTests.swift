import Foundation
import XCTest
@testable import StudyTracker

final class WeeklyReviewServiceTests: XCTestCase {
    private let courseA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let courseB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let courseC = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var service: WeeklyReviewService {
        WeeklyReviewService(calendar: calendar)
    }

    private var classes: [StudyClass] {
        [
            StudyClass(id: courseA, name: "Biology", colorHex: "#16A34A"),
            StudyClass(id: courseB, name: "Chemistry", colorHex: "#DB2777"),
            StudyClass(
                id: courseC,
                name: "Archived Art",
                colorHex: "#2563EB",
                isArchived: true
            )
        ]
    }

    func testWeeklyReviewBuildsAllMetricsInsightsAndSuggestion() throws {
        let sessions = [
            session(courseID: courseA, day: 6, duration: 7_200),
            session(courseID: courseB, day: 7, duration: 7_200),
            session(courseID: courseA, day: 13, duration: 7_200, focusRating: 4),
            session(courseID: courseB, day: 14, duration: 3_600, focusRating: 3),
            session(
                courseID: courseA,
                day: 15,
                duration: 10_800,
                source: .pomodoro,
                pomodoroIntervals: 2,
                focusRating: 5
            ),
            session(courseID: courseA, day: 16, duration: 3_600)
        ]
        let weeklyGoal = StudyGoal(
            kind: .weekly,
            targetDuration: 18_000,
            startDate: date(day: 1)
        )
        let courseGoal = StudyGoal(
            kind: .course,
            targetDuration: 36_000,
            courseID: courseB,
            startDate: date(day: 1),
            targetDate: date(day: 20)
        )

        let review = service.review(
            classes: classes,
            goals: [weeklyGoal, courseGoal],
            sessions: sessions,
            weekContaining: date(day: 15),
            asOf: date(day: 16, hour: 18)
        )

        XCTAssertEqual(review.weekInterval.start, date(day: 13))
        XCTAssertEqual(review.weekInterval.end, date(day: 20))
        XCTAssertEqual(review.totalStudyTime, 25_200)
        XCTAssertEqual(review.previousWeekStudyTime, 14_400)
        XCTAssertEqual(try XCTUnwrap(review.weekOverWeekChange), 0.75, accuracy: 0.0001)
        XCTAssertEqual(review.activeStudyDays, 4)
        XCTAssertEqual(review.currentStreak, 4)
        XCTAssertEqual(review.mostStudiedCourse?.name, "Biology")
        XCTAssertEqual(review.mostStudiedCourse?.seconds, 21_600)
        XCTAssertEqual(review.leastStudiedActiveCourse?.name, "Chemistry")
        XCTAssertEqual(review.leastStudiedActiveCourse?.seconds, 3_600)
        XCTAssertEqual(review.averageSessionDuration, 6_300)
        XCTAssertEqual(try XCTUnwrap(review.averageFocusRating), 4, accuracy: 0.0001)
        XCTAssertEqual(review.ratedSessionCount, 3)
        XCTAssertEqual(review.pomodoroIntervalsCompleted, 2)
        XCTAssertEqual(review.goalsCompleted, 1)
        XCTAssertEqual(review.goalsBehind, 1)
        XCTAssertEqual(review.bestStudyDay?.date, date(day: 15))
        XCTAssertEqual(review.bestStudyDay?.seconds, 10_800)
        XCTAssertEqual(
            review.insights,
            [
                "Study time increased 75% from the previous week.",
                "Study activity was recorded on 4 days.",
                "Most studied: Biology at 6h.",
                "Best study day: Wednesday with 3h.",
                "Average focus rating: 4.0 out of 5.",
                "1 active goal is behind pace."
            ]
        )
        XCTAssertEqual(review.targetSuggestion?.totalDuration, 27_000)
        XCTAssertEqual(review.targetSuggestion?.activeDayTarget, 3)
        XCTAssertEqual(review.targetSuggestion?.dailyDuration, 9_000)
    }

    func testPreviousWeekCanBeReviewedAndIncludesZeroTimeActiveCourse() {
        let sessions = [
            session(courseID: courseA, day: 6, duration: 7_200),
            session(courseID: courseA, day: 7, duration: 7_200),
            session(courseID: courseA, day: 13, duration: 3_600)
        ]

        let review = service.review(
            classes: classes,
            goals: [],
            sessions: sessions,
            weekContaining: date(day: 8),
            asOf: date(day: 16, hour: 18)
        )

        XCTAssertEqual(review.weekInterval.start, date(day: 6))
        XCTAssertEqual(review.totalStudyTime, 14_400)
        XCTAssertEqual(review.activeStudyDays, 2)
        XCTAssertEqual(review.currentStreak, 0)
        XCTAssertEqual(review.mostStudiedCourse?.name, "Biology")
        XCTAssertEqual(review.leastStudiedActiveCourse?.name, "Chemistry")
        XCTAssertEqual(review.leastStudiedActiveCourse?.seconds, 0)
        XCTAssertTrue(review.insights.contains("Chemistry had no logged study time."))
    }

    func testFocusRatingRequiresMinimumSample() {
        let sessions = [
            session(courseID: courseA, day: 13, duration: 3_600, focusRating: 5),
            session(courseID: courseA, day: 14, duration: 3_600, focusRating: 3)
        ]

        let review = service.review(
            classes: classes,
            goals: [],
            sessions: sessions,
            weekContaining: date(day: 15),
            asOf: date(day: 16, hour: 18)
        )

        XCTAssertEqual(review.ratedSessionCount, 2)
        XCTAssertNil(review.averageFocusRating)
        XCTAssertFalse(review.insights.contains { $0.contains("focus rating") })
    }

    func testCompletedPastWeekMarksIncompleteWeeklyGoalBehind() {
        let weeklyGoal = StudyGoal(
            kind: .weekly,
            targetDuration: 36_000,
            startDate: date(day: 1)
        )
        let sessions = [
            session(courseID: courseA, day: 6, duration: 7_200)
        ]

        let review = service.review(
            classes: classes,
            goals: [weeklyGoal],
            sessions: sessions,
            weekContaining: date(day: 8),
            asOf: date(day: 16, hour: 18)
        )

        XCTAssertEqual(review.goalsCompleted, 0)
        XCTAssertEqual(review.goalsBehind, 1)
    }

    func testEmptyWeekHasSafeDefaultsAndNoSuggestion() {
        let review = service.review(
            classes: classes,
            goals: [],
            sessions: [],
            weekContaining: date(day: 15),
            asOf: date(day: 16, hour: 18)
        )

        XCTAssertTrue(review.isEmpty)
        XCTAssertEqual(review.totalStudyTime, 0)
        XCTAssertEqual(review.weekOverWeekChange, 0)
        XCTAssertEqual(review.activeStudyDays, 0)
        XCTAssertEqual(review.currentStreak, 0)
        XCTAssertNil(review.averageFocusRating)
        XCTAssertNil(review.bestStudyDay)
        XCTAssertEqual(review.insights, ["No study sessions were logged for this week."])
        XCTAssertNil(review.targetSuggestion)
    }

    private func session(
        courseID: UUID,
        day: Int,
        duration: TimeInterval,
        source: StudySessionSource = .manual,
        pomodoroIntervals: Int = 0,
        focusRating: Int? = nil
    ) -> StudySession {
        StudySession(
            classID: courseID,
            startedAt: date(day: day, hour: 9),
            duration: duration,
            source: source,
            pomodoroIntervalCount: pomodoroIntervals,
            focusRating: focusRating
        )
    }

    private func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }
}
