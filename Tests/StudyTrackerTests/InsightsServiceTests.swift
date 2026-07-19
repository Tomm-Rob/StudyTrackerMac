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
        XCTAssertEqual(snapshot.averageStudyTimePerActiveDay, 6_300)
        XCTAssertEqual(snapshot.averageSessionDuration, 4_200)
        XCTAssertEqual(snapshot.longestSessionDuration, 7_200)
        XCTAssertEqual(snapshot.sessionCount, 3)
        XCTAssertEqual(snapshot.activeDayCount, 2)
        XCTAssertEqual(snapshot.selectedDayCount, 2)
        XCTAssertEqual(snapshot.studiedDayPercentage, 1)
        XCTAssertEqual(snapshot.pomodoroIntervalCount, 1)
        XCTAssertEqual(snapshot.currentStreak, 2)
        XCTAssertEqual(snapshot.longestStreak, 2)
        XCTAssertEqual(snapshot.courseCount, 2)
        XCTAssertEqual(snapshot.courseTotals.map(\.name), ["Chemistry", "Biology"])
        XCTAssertEqual(snapshot.courseTotals.map(\.seconds), [7_200, 5_400])
        XCTAssertEqual(snapshot.weekdayTotals.first(where: { $0.label == "Tue" })?.seconds, 3_600)
        XCTAssertEqual(snapshot.weekdayTotals.first(where: { $0.label == "Wed" })?.seconds, 9_000)
        XCTAssertEqual(snapshot.hourlyTotals.first(where: { $0.hour == 10 })?.seconds, 7_200)
        XCTAssertEqual(
            snapshot.timeWindowTotals.first(where: { $0.window == .morning })?.seconds,
            12_600
        )
        XCTAssertEqual(snapshot.heatmapDays.count, 2)
        XCTAssertEqual(snapshot.weeklyTrend.count, 1)
        XCTAssertEqual(snapshot.generatedInsights.count, 1)
        XCTAssertEqual(snapshot.generatedInsights.first?.id, "collecting-data")
        XCTAssertFalse(snapshot.generatedInsights.contains { $0.id == "consistent-weekday" })
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
        XCTAssertEqual(snapshot.generatedInsights.first?.id, "collecting-data")
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
        XCTAssertEqual(snapshot.selectedDayCount, 0)
        XCTAssertEqual(snapshot.currentStreak, 0)
        XCTAssertEqual(snapshot.longestStreak, 0)
        XCTAssertEqual(
            snapshot.messages,
            ["Log a study session in this range to generate local insights."]
        )
    }

    func testCoursePlanningPriorityAndTimeWindowAnalytics() throws {
        let classes = [
            StudyClass(
                id: courseA,
                name: "Biology",
                colorHex: "#16A34A",
                plannedStudyHours: 10,
                weeklyStudyHoursTarget: 4,
                priority: .critical
            ),
            StudyClass(
                id: courseB,
                name: "Chemistry",
                colorHex: "#DB2777",
                priority: .low
            )
        ]
        let sessions = [
            session(
                courseID: courseA,
                month: 7,
                day: 15,
                hour: 9,
                duration: 3_600,
                focusRating: 5
            ),
            session(
                courseID: courseB,
                month: 7,
                day: 15,
                hour: 14,
                duration: 7_200,
                focusRating: 2
            ),
            session(
                courseID: courseB,
                month: 7,
                day: 15,
                hour: 18,
                duration: 10_800,
                focusRating: 4
            )
        ]
        let snapshot = service.snapshot(
            classes: classes,
            sessions: sessions,
            interval: DateInterval(
                start: date(month: 7, day: 14),
                end: date(month: 7, day: 16)
            ),
            asOf: date(month: 7, day: 15, hour: 20)
        )

        let biology = try XCTUnwrap(snapshot.courseTotals.first { $0.courseID == courseA })
        XCTAssertEqual(biology.percentageOfTotal, 1.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(biology.averageSessionDuration, 3_600)
        XCTAssertEqual(biology.sessionCount, 1)
        XCTAssertEqual(biology.plannedProgressFraction, 0.1)
        XCTAssertEqual(biology.weeklyTargetProgressFraction, 0.25)
        XCTAssertTrue(biology.receivesLessAttention)

        let morning = try XCTUnwrap(
            snapshot.timeWindowTotals.first { $0.window == .morning }
        )
        XCTAssertEqual(morning.averageFocusRating, 5)
        XCTAssertEqual(morning.averageSessionDuration, 3_600)
        let afternoon = try XCTUnwrap(
            snapshot.timeWindowTotals.first { $0.window == .afternoon }
        )
        XCTAssertEqual(afternoon.averageFocusRating, 2)
        XCTAssertEqual(snapshot.mostProductiveTimeWindow?.window, .evening)
        let weekdayFocus = try XCTUnwrap(
            snapshot.weekdayTotals.first(where: { $0.label == "Wed" })?.averageFocusRating
        )
        XCTAssertEqual(weekdayFocus, 11.0 / 3.0, accuracy: 0.0001)
    }

    func testPreviousEquivalentPeriodComparison() throws {
        let asOf = date(month: 7, day: 15, hour: 14)
        let current = try XCTUnwrap(interval(for: .thisWeek, asOf: asOf))
        let previous = try XCTUnwrap(
            InsightsDateFilter.thisWeek.comparisonInterval(
                asOf: asOf,
                calendar: calendar,
                customStart: asOf,
                customEnd: asOf
            )
        )
        let sessions = [
            session(courseID: courseA, month: 7, day: 14, hour: 9, duration: 7_200),
            session(courseID: courseA, month: 7, day: 7, hour: 9, duration: 3_600)
        ]

        XCTAssertEqual(previous.start, date(month: 7, day: 6))
        XCTAssertEqual(
            previous.end.timeIntervalSince1970,
            date(month: 7, day: 8, hour: 14).timeIntervalSince1970,
            accuracy: 0.01
        )

        let snapshot = service.snapshot(
            classes: [StudyClass(id: courseA, name: "Biology", colorHex: "#16A34A")],
            sessions: sessions,
            interval: current,
            comparisonInterval: previous,
            asOf: asOf
        )
        let comparison = try XCTUnwrap(snapshot.comparison)

        XCTAssertEqual(comparison.currentDuration, 7_200)
        XCTAssertEqual(comparison.previousDuration, 3_600)
        XCTAssertEqual(comparison.numericalDifference, 3_600)
        XCTAssertEqual(comparison.percentageChange, 1)
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
        pomodoroIntervals: Int = 0,
        focusRating: Int? = nil
    ) -> StudySession {
        StudySession(
            classID: courseID,
            startedAt: date(month: month, day: day, hour: hour),
            duration: duration,
            source: source,
            pomodoroIntervalCount: pomodoroIntervals,
            focusRating: focusRating
        )
    }

    private func date(year: Int = 2026, month: Int, day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
