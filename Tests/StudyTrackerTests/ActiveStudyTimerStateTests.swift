import Foundation
import XCTest
@testable import StudyTracker

final class ActiveStudyTimerStateTests: XCTestCase {
    private let firstClassID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let secondClassID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    func testElapsedTimeContinuesWithoutViewOwnedTicks() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var timer = ActiveStudyTimerState()

        timer.start(classID: firstClassID, at: start)

        XCTAssertEqual(timer.elapsedDuration(at: start.addingTimeInterval(75)), 75)
        XCTAssertEqual(timer.classID, firstClassID)
        XCTAssertTrue(timer.isRunning)
    }

    func testPauseAndResumeExcludePausedTime() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        var timer = ActiveStudyTimerState()

        timer.start(classID: firstClassID, at: start)
        timer.pause(at: start.addingTimeInterval(30))
        timer.start(classID: firstClassID, at: start.addingTimeInterval(90))

        XCTAssertEqual(timer.elapsedDuration(at: start.addingTimeInterval(110)), 50)
        XCTAssertEqual(timer.startedAt, start)
    }

    func testActiveSessionCannotSwitchClassesUntilReset() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        var timer = ActiveStudyTimerState()

        timer.start(classID: firstClassID, at: start)
        timer.pause(at: start.addingTimeInterval(10))
        timer.start(classID: secondClassID, at: start.addingTimeInterval(20))

        XCTAssertEqual(timer.classID, firstClassID)
        XCTAssertFalse(timer.isRunning)

        timer.reset()
        timer.start(classID: secondClassID, at: start.addingTimeInterval(30))
        XCTAssertEqual(timer.classID, secondClassID)
        XCTAssertTrue(timer.isRunning)
    }
}
