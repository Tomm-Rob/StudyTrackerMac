import Foundation
import XCTest
@testable import StudyTracker

final class InsightsServiceTests: XCTestCase {
    private let courseA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let courseB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private var service: InsightsService {
        InsightsService(calendar: calendar)
    }

    func testPresetDateRanges() throws {
        let asOf = date(month: 7, day: 15, hour: 14)

        XCTAssertEqual(
            interval(for: .today, asOf: asOf),
            DateInterval(start: date(month: 7, day: 15), end: date(month: 7, day: 16))
        )
        XCTAssertEqual(
            interval(for: .thisWeek, asOf: asOf),
            DateInterval(start: date(month: 7, day: 13), end: date(month: 7, day: 20))
        )
        XCTAssertEqual(
            interval(for: .thisMonth, asOf: asOf),
            DateInterval(start: date(month: 7, day: 1), end: date(month: 8, day: 1))
        )
        XCTAssertEqual(
            interval(for: .last7Days, asOf: asOf),
            DateInterval(start: date(month: 7, day: 9), end: date(month: 7, day: 16))
        )
        XCTAssertEqual(
            interval(for: .last30Days, asOf: asOf),
            DateInterval(start: date(month: 6, day: 16), end: date(month: 7, day: 16))
        )
        XCTAssertEqual(
            interval(for: .thisYear, asOf: asOf),
            DateInterval(start: date(month: 1, day: 1), end: date(year: 2027, month: 1, day: 1))
        )
        XCTAssertNil(
            InsightsDateFilter.allTime.dateInterval(
                asOf: asOf,
                calendar: calendar,
                customStart: asOf,
                customEnd: asOf
            )
        )
    }

    func testCustomRangeIncludesBothBoundaryDaysAndNormalizesOrder() throws {
        let interval = try XCTUnwrap(
            InsightsDateFilter.custom.dateInterval(
                asOf: date(month: 7, day: 15),
                calendar: calendar,
                customStart: date(month: 7, day: 10, hour: 17),
                customEnd: date(month: 7, day: 5, hour: 8)
            )
        )

        XCTAssertEqual(interval.start, date(month: 7, day: 5))
        XCTAssertEqual(interval.end, date(month: 7, day: 11))
    }

    func testSnapshotBuildsMetricsCourseAndTimePatterns() {
        let classes = [
            StudyClass(id: courseA, name: "Biology", colorHex: "#16A34A"),
            StudyClass(id: courseB, name: "Chemistry", colorHex: "#DB2777")
        ]
        let sessions = [
            session(courseID: courseA, month: 7, day: 14, hour: 9, duration: 3_600),
            session(
                courseID: courseA,
                month: 7,
                day: 15,
                hour: 8,
                duration: 1_800,
                source: .pomodoro,
                pomodoroIntervals: 1
            ),
            session(courseID: courseB, month: 7, day: 15, hour: 10, duration: 7_200),
            session(courseID: courseB, month: 7, day: 15, hour: 15, duration: 7_200),
            session(courseID: courseA, month: 7, day: 1, hour: 9, duration: 9_000),
            session(courseID: courseA, month: 7, day: 15, hour: 9, duration: -600)
        ]
        let interval = DateInterval(
            start: date(month: 7, day: 14),
            end: date(month: 7, day: 16)
        )

        let snapshot = service.snapshot(
            classes: classes,
            sessions: sessions,
            interval: interval,
            asOf: date(month: 7, day: 15, hour: 12)
        )

        XCTAssertEqual(snapshot.totalStudyTime, 12_600)
        XCTAssertEqual(snapshot.averageSessionDuration, 4_200)
        XCTAssertEqual(snapshot.sessionCount, 3)
        XCTAssertEqual(snapshot.activeDayCount, 2)
        XCTAssertEqual(snapshot.pomodoroIntervalCount, 1)
        XCTAssertEqual(snapshot.courseCount, 2)
        XCTAssertEqual(snapshot.courseTotals.map(\.name), ["Chemistry", "Biology"])
        XCTAssertEqual(snapshot.courseTotals.map(\.seconds), [7_200, 5_400])
        XCTAssertEqual(snapshot.weekdayTotals.first(where: { $0.label == "Tue" })?.seconds, 3_600)
        XCTAssertEqual(snapshot.weekdayTotals.first(where: { $0.label == "Wed" })?.seconds, 9_000)
        XCTAssertEqual(snapshot.hourlyTotals.first(where: { $0.hour == 10 })?.seconds, 7_200)
        XCTAssertEqual(
            snapshot.messages,
            [
                "Most studied: Chemistry with 2h.",
                "Strongest study day: Wed at 2h 30m.",
                "Average session length: 1h 10m.",
                "Study activity appeared on 2 of 2 selected days."
            ]
        )
    }

    func testCourseTiesUseStableNameOrdering() {
        let classes = [
            StudyClass(id: courseA, name: "Algebra", colorHex: "#2563EB"),
            StudyClass(id: courseB, name: "Biology", colorHex: "#16A34A")
        ]
        let sessions = [
            session(courseID: courseB, month: 7, day: 15, hour: 9, duration: 3_600),
            session(courseID: courseA, month: 7, day: 15, hour: 10, duration: 3_600)
        ]

        let snapshot = service.snapshot(
            classes: classes,
            sessions: sessions,
            interval: nil,
            asOf: date(month: 7, day: 15, hour: 12)
        )

        XCTAssertEqual(snapshot.courseTotals.map(\.name), ["Algebra", "Biology"])
        XCTAssertEqual(snapshot.messages.first, "Most studied: Algebra with 1h.")
    }

    func testEmptySnapshotProvidesDeterministicEmptyInsight() {
        let snapshot = service.snapshot(
            classes: [],
            sessions: [],
            interval: nil,
            asOf: date(month: 7, day: 15)
        )

        XCTAssertTrue(snapshot.isEmpty)
        XCTAssertEqual(snapshot.totalStudyTime, 0)
        XCTAssertEqual(snapshot.averageSessionDuration, 0)
        XCTAssertEqual(snapshot.sessionCount, 0)
        XCTAssertEqual(
            snapshot.messages,
            ["Log a study session in this range to generate local insights."]
        )
    }

    private func interval(for filter: InsightsDateFilter, asOf date: Date) -> DateInterval? {
        filter.dateInterval(
            asOf: date,
            calendar: calendar,
            customStart: date,
            customEnd: date
        )
    }

    private func session(
        courseID: UUID,
        month: Int,
        day: Int,
        hour: Int,
        duration: TimeInterval,
        source: StudySessionSource = .manual,
        pomodoroIntervals: Int = 0
    ) -> StudySession {
        StudySession(
            classID: courseID,
            startedAt: date(month: month, day: day, hour: hour),
            duration: duration,
            source: source,
            pomodoroIntervalCount: pomodoroIntervals
        )
    }

    private func date(year: Int = 2026, month: Int, day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
