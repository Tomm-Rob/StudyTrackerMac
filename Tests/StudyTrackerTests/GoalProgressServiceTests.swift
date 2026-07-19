import Foundation
import XCTest
@testable import StudyTracker

final class GoalProgressServiceTests: XCTestCase {
    private let courseA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let courseB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var service: GoalProgressService {
        GoalProgressService(calendar: calendar)
    }

    func testDailyGoalProgressUsesCurrentDayThroughAsOfTime() {
        let asOf = date(day: 8, hour: 12)
        let goal = StudyGoal(
            kind: .daily,
            targetDuration: 7_200,
            startDate: date(day: 1)
        )
        let sessions = [
            session(courseID: courseA, day: 7, hour: 15, duration: 14_400),
            session(courseID: courseA, day: 8, hour: 9, duration: 3_600),
            session(courseID: courseB, day: 8, hour: 11, duration: 1_800),
            session(courseID: courseA, day: 8, hour: 15, duration: 7_200)
        ]

        let progress = service.progress(for: goal, sessions: sessions, asOf: asOf)

        XCTAssertEqual(progress.studiedDuration, 5_400)
        XCTAssertEqual(progress.remainingDuration, 1_800)
        XCTAssertEqual(progress.completionFraction, 0.75)
        XCTAssertFalse(progress.isComplete)
        XCTAssertFalse(progress.isOverdue)
    }

    func testWeeklyGoalProgressUsesConfiguredCalendarWeek() {
        let asOf = date(day: 8, hour: 12)
        let goal = StudyGoal(
            kind: .weekly,
            targetDuration: 18_000,
            startDate: date(day: 1)
        )
        let sessions = [
            session(courseID: courseA, day: 5, duration: 7_200),
            session(courseID: courseA, day: 6, duration: 3_600),
            session(courseID: courseB, day: 8, duration: 7_200),
            session(courseID: courseA, day: 9, duration: 3_600)
        ]

        let progress = service.progress(for: goal, sessions: sessions, asOf: asOf)

        XCTAssertEqual(progress.studiedDuration, 10_800)
        XCTAssertEqual(progress.remainingDuration, 7_200)
        XCTAssertEqual(progress.completionFraction, 0.6, accuracy: 0.0001)
    }

    func testCourseGoalProgressFiltersCourseAndStartDate() {
        let goal = StudyGoal(
            kind: .course,
            targetDuration: 18_000,
            courseID: courseA,
            startDate: date(day: 2),
            targetDate: date(day: 10)
        )
        let sessions = [
            session(courseID: courseA, day: 1, duration: 7_200),
            session(courseID: courseA, day: 2, duration: 3_600),
            session(courseID: courseB, day: 3, duration: 7_200),
            session(courseID: courseA, day: 4, duration: 5_400)
        ]

        let progress = service.progress(
            for: goal,
            sessions: sessions,
            asOf: date(day: 5, hour: 12)
        )

        XCTAssertEqual(progress.studiedDuration, 9_000)
        XCTAssertEqual(progress.remainingDuration, 9_000)
        XCTAssertEqual(progress.completionFraction, 0.5)
    }

    func testCoursePacingAndProjectionUseRecentDailyRate() throws {
        let asOf = date(day: 10, hour: 18)
        let goal = StudyGoal(
            kind: .course,
            targetDuration: 108_000,
            courseID: courseA,
            startDate: date(day: 1),
            targetDate: date(day: 14)
        )
        let sessions = (0..<14).map { offset in
            StudySession(
                classID: courseA,
                startedAt: calendar.date(byAdding: .day, value: -offset, to: date(day: 10, hour: 9))!,
                duration: 7_200
            )
        }

        let pacing = try XCTUnwrap(service.coursePacing(for: goal, sessions: sessions, asOf: asOf))

        XCTAssertEqual(pacing.progress.studiedDuration, 72_000)
        XCTAssertEqual(pacing.progress.remainingDuration, 36_000)
        XCTAssertEqual(pacing.daysRemaining, 5)
        XCTAssertEqual(pacing.requiredDailyDuration, 7_200)
        XCTAssertEqual(pacing.recentDailyDuration, 7_200)
        XCTAssertEqual(pacing.paceRatio, 1)
        XCTAssertEqual(pacing.projectedCompletionDate, date(day: 14))
        XCTAssertEqual(pacing.status, .onTrack)
    }

    func testPastTargetDateIsOverdueWithoutUnsafeDivision() throws {
        let asOf = date(day: 10, hour: 18)
        let overdueService = GoalProgressService(calendar: calendar, recentWindowDays: 2)
        let goal = StudyGoal(
            kind: .course,
            targetDuration: 36_000,
            courseID: courseA,
            startDate: date(day: 1),
            targetDate: date(day: 9)
        )
        let sessions = [
            session(courseID: courseA, day: 9, duration: 3_600),
            session(courseID: courseA, day: 10, duration: 3_600)
        ]

        let pacing = try XCTUnwrap(overdueService.coursePacing(for: goal, sessions: sessions, asOf: asOf))

        XCTAssertTrue(pacing.progress.isOverdue)
        XCTAssertEqual(pacing.daysRemaining, 0)
        XCTAssertEqual(pacing.requiredDailyDuration, 28_800)
        XCTAssertTrue(pacing.requiredDailyDuration.isFinite)
        XCTAssertEqual(pacing.status, .overdue)
        XCTAssertNotNil(pacing.projectedCompletionDate)
    }

    func testZeroHourPastGoalIsCompleteAndNotOverdue() throws {
        let asOf = date(day: 10, hour: 12)
        let goal = StudyGoal(
            kind: .course,
            targetDuration: 0,
            courseID: courseA,
            startDate: date(day: 1),
            targetDate: date(day: 2)
        )

        let pacing = try XCTUnwrap(service.coursePacing(for: goal, sessions: [], asOf: asOf))

        XCTAssertTrue(pacing.progress.isComplete)
        XCTAssertFalse(pacing.progress.isOverdue)
        XCTAssertEqual(pacing.progress.completionFraction, 1)
        XCTAssertEqual(pacing.requiredDailyDuration, 0)
        XCTAssertEqual(pacing.paceRatio, 1)
        XCTAssertEqual(pacing.projectedCompletionDate, date(day: 10))
        XCTAssertEqual(pacing.status, .complete)
    }

    func testProjectionRequiresRecentStudyData() throws {
        let goal = StudyGoal(
            kind: .course,
            targetDuration: 36_000,
            courseID: courseA,
            startDate: date(day: 1),
            targetDate: date(day: 20)
        )

        let pacing = try XCTUnwrap(
            service.coursePacing(for: goal, sessions: [], asOf: date(day: 10, hour: 12))
        )

        XCTAssertEqual(pacing.recentDailyDuration, 0)
        XCTAssertNil(pacing.projectedCompletionDate)
        XCTAssertEqual(pacing.status, .noRecentData)
    }

    func testFutureGoalStartProducesZeroProgress() {
        let goal = StudyGoal(
            kind: .daily,
            targetDuration: 3_600,
            startDate: date(day: 12)
        )
        let sessions = [
            session(courseID: courseA, day: 10, duration: 3_600)
        ]

        let progress = service.progress(
            for: goal,
            sessions: sessions,
            asOf: date(day: 10, hour: 12)
        )

        XCTAssertEqual(progress.studiedDuration, 0)
        XCTAssertEqual(progress.completionFraction, 0)
        XCTAssertFalse(progress.isComplete)
    }

    func testCoursePacingReportsBehindRecentRate() throws {
        let pacingService = GoalProgressService(calendar: calendar, recentWindowDays: 2)
        let goal = StudyGoal(
            kind: .course,
            targetDuration: 36_000,
            courseID: courseA,
            startDate: date(day: 1),
            targetDate: date(day: 11)
        )
        let sessions = [
            session(courseID: courseA, day: 9, duration: 900),
            session(courseID: courseA, day: 10, duration: 900)
        ]

        let pacing = try XCTUnwrap(
            pacingService.coursePacing(for: goal, sessions: sessions, asOf: date(day: 10, hour: 12))
        )

        XCTAssertLessThan(pacing.recentDailyDuration, pacing.requiredDailyDuration)
        XCTAssertLessThan(pacing.paceRatio, 1)
        XCTAssertEqual(pacing.status, .behind)
    }

    private func session(
        courseID: UUID,
        day: Int,
        hour: Int = 9,
        duration: TimeInterval
    ) -> StudySession {
        StudySession(
            classID: courseID,
            startedAt: date(day: day, hour: hour),
            duration: duration
        )
    }

    private func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }
}
