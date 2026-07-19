import Foundation
import XCTest
@testable import StudyTracker

final class StudyAnalyticsServiceTests: XCTestCase {
    private let courseA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let courseB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var analytics: StudyAnalyticsService {
        StudyAnalyticsService(calendar: calendar)
    }

    func testTotalAndAverageSessionDuration() {
        let sessions = [
            session(courseID: courseA, day: 6, duration: 1_200),
            session(courseID: courseA, day: 6, duration: 3_600),
            session(courseID: courseB, day: 7, duration: 1_800),
            session(courseID: courseB, day: 7, duration: -300)
        ]

        XCTAssertEqual(analytics.totalStudyTime(in: sessions), 6_600)
        XCTAssertEqual(analytics.averageSessionDuration(in: sessions), 2_200)
        XCTAssertEqual(analytics.totalStudyTime(in: sessions, courseID: courseA), 4_800)
        XCTAssertEqual(analytics.averageSessionDuration(in: sessions, courseID: courseA), 2_400)
        XCTAssertEqual(analytics.averageSessionDuration(in: []), 0)
    }

    func testStudyTimeByDate() {
        let sessions = [
            session(courseID: courseA, day: 6, hour: 9, duration: 1_200),
            session(courseID: courseB, day: 6, hour: 14, duration: 1_800),
            session(courseID: courseA, day: 7, duration: 3_600)
        ]

        let totals = analytics.studyTimeByDate(in: sessions)

        XCTAssertEqual(totals[date(day: 6)], 3_000)
        XCTAssertEqual(totals[date(day: 7)], 3_600)
        XCTAssertEqual(analytics.studyTimeByDate(in: sessions, courseID: courseA)[date(day: 6)], 1_200)
    }

    func testStudyTimeByDateAndCourseSupportsStackedDailyBars() {
        let sessions = [
            session(courseID: courseA, day: 6, hour: 9, duration: 1_200),
            session(courseID: courseA, day: 6, hour: 10, duration: 600),
            session(courseID: courseB, day: 6, hour: 14, duration: 1_800),
            session(courseID: courseB, day: 7, duration: 3_600)
        ]

        let totals = analytics.studyTimeByDateAndCourse(in: sessions)

        XCTAssertEqual(totals[CourseDateKey(date: date(day: 6), courseID: courseA)], 1_800)
        XCTAssertEqual(totals[CourseDateKey(date: date(day: 6), courseID: courseB)], 1_800)
        XCTAssertEqual(totals[CourseDateKey(date: date(day: 7), courseID: courseB)], 3_600)
    }

    func testStudyTimeByWeekUsesCalendarWeekBoundaries() {
        let sessions = [
            session(courseID: courseA, day: 6, duration: 1_200),
            session(courseID: courseA, day: 12, duration: 1_800),
            session(courseID: courseA, day: 13, duration: 3_600)
        ]

        let totals = analytics.studyTimeByWeek(in: sessions)

        XCTAssertEqual(totals[date(day: 6)], 3_000)
        XCTAssertEqual(totals[date(day: 13)], 3_600)
    }

    func testStudyTimeByCourse() {
        let sessions = [
            session(courseID: courseA, day: 6, duration: 1_200),
            session(courseID: courseA, day: 7, duration: 1_800),
            session(courseID: courseB, day: 7, duration: 3_600)
        ]

        let totals = analytics.studyTimeByCourse(in: sessions)

        XCTAssertEqual(totals[courseA], 3_000)
        XCTAssertEqual(totals[courseB], 3_600)
    }

    func testCurrentAndLongestStudyStreaks() {
        let sessions = [
            session(courseID: courseA, day: 1),
            session(courseID: courseA, day: 2),
            session(courseID: courseA, day: 3),
            session(courseID: courseA, day: 3, hour: 16),
            session(courseID: courseB, day: 5),
            session(courseID: courseB, day: 6),
            session(courseID: courseB, day: 7)
        ]

        XCTAssertEqual(analytics.currentStudyStreak(in: sessions, asOf: date(day: 7)), 3)
        XCTAssertEqual(analytics.currentStudyStreak(in: sessions, asOf: date(day: 8)), 0)
        XCTAssertEqual(analytics.longestStudyStreak(in: sessions), 3)
        XCTAssertEqual(analytics.longestStudyStreak(in: sessions, courseID: courseA), 3)
        XCTAssertEqual(analytics.currentStudyStreak(in: [], asOf: date(day: 7)), 0)
    }

    func testPomodoroIntervalCounts() {
        let sessions = [
            session(courseID: courseA, day: 6, source: .pomodoro, pomodoroIntervals: 1),
            session(courseID: courseA, day: 7, source: .pomodoro, pomodoroIntervals: 2),
            session(courseID: courseB, day: 7, source: .pomodoro, pomodoroIntervals: 1),
            session(courseID: courseA, day: 7, source: .timer, pomodoroIntervals: 9)
        ]

        XCTAssertEqual(analytics.pomodoroIntervalCount(in: sessions), 4)
        XCTAssertEqual(analytics.pomodoroIntervalCount(in: sessions, courseID: courseA), 3)

        let daySeven = DateInterval(start: date(day: 7), end: date(day: 8))
        XCTAssertEqual(analytics.pomodoroIntervalCount(in: sessions, interval: daySeven), 3)
    }

    private func session(
        courseID: UUID,
        day: Int,
        hour: Int = 9,
        duration: TimeInterval = 1_800,
        source: StudySessionSource = .manual,
        pomodoroIntervals: Int = 0
    ) -> StudySession {
        StudySession(
            classID: courseID,
            startedAt: date(day: day, hour: hour),
            duration: duration,
            source: source,
            pomodoroIntervalCount: pomodoroIntervals
        )
    }

    private func date(day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }
}
