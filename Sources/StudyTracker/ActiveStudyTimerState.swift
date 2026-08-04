import Foundation

struct ActiveStudyTimerState: Equatable {
    private(set) var classID: UUID?
    private(set) var startedAt: Date?
    private(set) var runningSince: Date?
    private(set) var accumulatedDuration: TimeInterval = 0

    var isRunning: Bool {
        runningSince != nil
    }

    var hasSession: Bool {
        classID != nil
    }

    func elapsedDuration(at date: Date) -> TimeInterval {
        guard let runningSince else { return accumulatedDuration }
        return accumulatedDuration + max(0, date.timeIntervalSince(runningSince))
    }

    mutating func start(classID: UUID, at date: Date = Date()) {
        guard runningSince == nil else { return }

        if let existingClassID = self.classID {
            guard existingClassID == classID else { return }
        } else {
            self.classID = classID
            startedAt = date
        }

        runningSince = date
    }

    mutating func pause(at date: Date = Date()) {
        guard let runningSince else { return }
        accumulatedDuration += max(0, date.timeIntervalSince(runningSince))
        self.runningSince = nil
    }

    mutating func reset() {
        self = ActiveStudyTimerState()
    }
}
