import Foundation
import AppKit

@MainActor
final class StudyStore: ObservableObject {
    static let maxClasses = 50

    @Published var data: StudyData {
        didSet {
            save()
        }
    }

    @Published private(set) var dataFileURL: URL
    @Published var lastError: String?
    @Published private(set) var isPersistenceLocked = false

    private static let dataFileName = "study-tracker-data-v2.json"
    private static let legacyDataFileName = "study-tracker-data.json"
    private static let directoryKey = "StudyTracker.SaveDirectory"
    private static let legacyPomodoroKeys = [
        "Pomodoro.FocusMinutes",
        "Pomodoro.ShortBreakMinutes",
        "Pomodoro.LongBreakMinutes"
    ]
    private let analytics = StudyAnalyticsService()

    var activeClasses: [StudyClass] {
        data.classes.filter { !$0.isArchived }
    }

    var activeGoals: [StudyGoal] {
        data.goals.filter { !$0.isArchived }
    }

    init(saveDirectory: URL? = nil) {
        let directory = saveDirectory ?? Self.initialSaveDirectory()
        let fileURL = directory.appendingPathComponent(Self.dataFileName)
        var preparationError: String?

        do {
            try Self.importLegacyDataIfNeeded(into: fileURL)
        } catch {
            preparationError = "Could not protect your existing study data, so no save file was changed: \(error.localizedDescription)"
        }

        let loadResult = preparationError == nil ? Self.load(from: fileURL) : .missing
        var loadedData = StudyData()
        var originalData: Data?
        var originalSchemaVersion: Int?
        var persistenceLocked = preparationError != nil
        var initialError = preparationError

        switch loadResult {
        case .missing:
            break
        case .loaded(let data, let rawData):
            loadedData = data
            originalData = rawData
            originalSchemaVersion = data.schemaVersion
        case .unsupportedSchema(let version):
            persistenceLocked = true
            initialError = "This save file was created by a newer version of Study Tracker (data version \(version)). It was left unchanged."
        case .failed(let message):
            persistenceLocked = true
            initialError = message
        }

        let requiresMigration = !persistenceLocked
            && loadedData.schemaVersion < StudyData.currentSchemaVersion

        if requiresMigration {
            loadedData.migrateToCurrentSchema(legacyPomodoroSettings: Self.legacyPomodoroSettings())
        }

        self.dataFileURL = fileURL
        self.data = loadedData
        self.isPersistenceLocked = persistenceLocked
        self.lastError = initialError

        guard !isPersistenceLocked else { return }

        ensureSaveDirectoryExists()

        if requiresMigration, let originalData, let originalSchemaVersion {
            do {
                try Self.backUp(
                    originalData,
                    schemaVersion: originalSchemaVersion,
                    beside: fileURL
                )
            } catch {
                isPersistenceLocked = true
                lastError = "Could not create a migration backup, so the original save file was left unchanged: \(error.localizedDescription)"
                return
            }
        }

        save()

        if requiresMigration, lastError == nil {
            Self.clearLegacyPomodoroSettings()
        }
    }

    func addClass() {
        guard activeClasses.count < Self.maxClasses else { return }

        let color = defaultColors[activeClasses.count % defaultColors.count]
        var baseName = "New Class"
        var index = 1
        let names = Set(activeClasses.map(\.name))

        while names.contains(baseName) {
            index += 1
            baseName = "New Class \(index)"
        }

        data.classes.append(StudyClass(name: baseName, colorHex: color))
    }

    func archiveClass(id: UUID) {
        guard let index = data.classes.firstIndex(where: { $0.id == id && !$0.isArchived }) else { return }
        var studyClass = data.classes[index]
        studyClass.isArchived = true
        studyClass.archivedAt = Date()
        data.classes[index] = studyClass
    }

    func restoreClass(id: UUID) {
        guard activeClasses.count < Self.maxClasses,
              let index = data.classes.firstIndex(where: { $0.id == id && $0.isArchived }) else {
            return
        }
        var studyClass = data.classes[index]
        studyClass.isArchived = false
        studyClass.archivedAt = nil
        data.classes[index] = studyClass
    }

    func addGoal(_ goal: StudyGoal) {
        data.goals.append(goal)
    }

    func updateGoal(_ goal: StudyGoal) {
        guard let index = data.goals.firstIndex(where: { $0.id == goal.id }) else { return }
        data.goals[index] = goal
    }

    func archiveGoal(id: UUID) {
        guard let index = data.goals.firstIndex(where: { $0.id == id && !$0.isArchived }) else { return }
        var goal = data.goals[index]
        goal.isArchived = true
        data.goals[index] = goal
    }

    func addSession(
        classID: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        duration: TimeInterval,
        source: StudySessionSource = .manual,
        pomodoroIntervalCount: Int = 0,
        focusRating: Int? = nil,
        energyRating: Int? = nil,
        distractionRating: Int? = nil,
        topic: String? = nil,
        completionState: SessionCompletionState? = nil
    ) {
        guard duration > 0,
              data.classes.contains(where: { $0.id == classID && !$0.isArchived }) else { return }
        data.sessions.append(
            StudySession(
                classID: classID,
                startedAt: startedAt,
                endedAt: endedAt,
                duration: duration,
                source: source,
                pomodoroIntervalCount: pomodoroIntervalCount,
                focusRating: focusRating,
                energyRating: energyRating,
                distractionRating: distractionRating,
                topic: topic,
                completionState: completionState
            )
        )
    }

    func updateSession(_ session: StudySession) {
        guard let index = data.sessions.firstIndex(where: { $0.id == session.id }) else { return }
        data.sessions[index] = session
    }

    func deleteSession(id: UUID) {
        data.sessions.removeAll { $0.id == id }
    }

    func className(for id: UUID) -> String {
        data.classes.first(where: { $0.id == id })?.name ?? "Deleted Class"
    }

    func classColor(for id: UUID) -> String {
        data.classes.first(where: { $0.id == id })?.colorHex ?? "#6B7280"
    }

    func sessions(for classID: UUID? = nil) -> [StudySession] {
        data.sessions
            .filter { classID == nil || $0.classID == classID }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func dailyTotals(for classID: UUID? = nil, daysBack: Int = 14) -> [DailyTotal] {
        let calendar = Calendar.current
        let today = Date().startOfDay
        let start = calendar.date(byAdding: .day, value: -(daysBack - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? Date.distantFuture
        let grouped = analytics.studyTimeByDate(
            in: data.sessions,
            courseID: classID,
            interval: DateInterval(start: start, end: end)
        )

        return (0..<daysBack).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DailyTotal(date: day, seconds: grouped[day] ?? 0)
        }
    }

    func dailyClassTotals(daysBack: Int = 14) -> [DailyClassTotal] {
        let calendar = Calendar.current
        let today = Date().startOfDay
        let start = calendar.date(byAdding: .day, value: -(daysBack - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? Date.distantFuture
        let grouped = analytics.studyTimeByDateAndCourse(
            in: data.sessions,
            interval: DateInterval(start: start, end: end)
        )

        return (0..<daysBack).flatMap { offset -> [DailyClassTotal] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return []
            }

            return data.classes.compactMap { studyClass in
                let key = CourseDateKey(date: day, courseID: studyClass.id)
                guard let seconds = grouped[key], seconds > 0 else { return nil }
                return DailyClassTotal(
                    date: day,
                    studyClass: studyClass,
                    seconds: seconds
                )
            }
        }
    }

    func classTotals() -> [ClassTotal] {
        let grouped = analytics.studyTimeByCourse(in: data.sessions)

        return data.classes.compactMap { studyClass in
            let seconds = grouped[studyClass.id] ?? 0
            guard seconds > 0 else { return nil }
            return ClassTotal(studyClass: studyClass, seconds: seconds)
        }
        .sorted { $0.seconds > $1.seconds }
    }

    func changeSaveDirectory(to directory: URL) {
        let destinationURL = directory.appendingPathComponent(Self.dataFileName)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoded = try JSONEncoder.studyTracker.encode(data)
            try encoded.write(to: destinationURL, options: [.atomic])
            UserDefaults.standard.set(directory.path, forKey: Self.directoryKey)
            dataFileURL = destinationURL
            lastError = nil
        } catch {
            lastError = "Could not save there: \(error.localizedDescription)"
        }
    }

    func resetSaveDirectory() {
        UserDefaults.standard.removeObject(forKey: Self.directoryKey)
        let directory = Self.defaultSaveDirectory()
        changeSaveDirectory(to: directory)
    }

    private func save() {
        guard !isPersistenceLocked else { return }

        do {
            ensureSaveDirectoryExists()
            let encoded = try JSONEncoder.studyTracker.encode(data)
            try encoded.write(to: dataFileURL, options: [.atomic])
            lastError = nil
        } catch {
            lastError = "Could not save your study data: \(error.localizedDescription)"
        }
    }

    private func ensureSaveDirectoryExists() {
        do {
            try FileManager.default.createDirectory(
                at: dataFileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            lastError = "Could not create the save folder: \(error.localizedDescription)"
        }
    }

    private static func initialSaveDirectory() -> URL {
        if let savedPath = UserDefaults.standard.string(forKey: directoryKey), !savedPath.isEmpty {
            return URL(fileURLWithPath: savedPath)
        }

        return defaultSaveDirectory()
    }

    private static func defaultSaveDirectory() -> URL {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.homeDirectoryForCurrentUser

        return supportDirectory.appendingPathComponent("Study Tracker", isDirectory: true)
    }

    private static func importLegacyDataIfNeeded(into fileURL: URL) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }

        let legacyURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(legacyDataFileName)
        guard fileManager.fileExists(atPath: legacyURL.path) else { return }

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let legacyData = try Data(contentsOf: legacyURL)
        try legacyData.write(to: fileURL, options: [.atomic])
    }

    private static func load(from url: URL) -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }

        do {
            let rawData = try Data(contentsOf: url)
            let header = try JSONDecoder.studyTracker.decode(SchemaHeader.self, from: rawData)

            guard header.schemaVersion <= StudyData.currentSchemaVersion else {
                return .unsupportedSchema(header.schemaVersion)
            }

            let decoded = try JSONDecoder.studyTracker.decode(StudyData.self, from: rawData)
            return .loaded(decoded, rawData)
        } catch {
            return .failed("Could not read your study data, so the save file was left unchanged: \(error.localizedDescription)")
        }
    }

    private static func backUp(_ data: Data, schemaVersion: Int, beside fileURL: URL) throws {
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("study-tracker-data-v2-schema\(schemaVersion)-backup.json")

        guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }
        try data.write(to: backupURL, options: [.atomic])
    }

    private static func legacyPomodoroSettings() -> PomodoroSettings? {
        let defaults = UserDefaults.standard
        guard legacyPomodoroKeys.contains(where: { defaults.object(forKey: $0) != nil }) else {
            return nil
        }

        var settings = PomodoroSettings()
        if defaults.object(forKey: legacyPomodoroKeys[0]) != nil {
            settings.focusMinutes = defaults.integer(forKey: legacyPomodoroKeys[0])
        }
        if defaults.object(forKey: legacyPomodoroKeys[1]) != nil {
            settings.shortBreakMinutes = defaults.integer(forKey: legacyPomodoroKeys[1])
        }
        if defaults.object(forKey: legacyPomodoroKeys[2]) != nil {
            settings.longBreakMinutes = defaults.integer(forKey: legacyPomodoroKeys[2])
        }
        settings.normalize()
        return settings
    }

    private static func clearLegacyPomodoroSettings() {
        let defaults = UserDefaults.standard
        legacyPomodoroKeys.forEach(defaults.removeObject(forKey:))
    }

    private let defaultColors = [
        "#2563EB",
        "#16A34A",
        "#EA580C",
        "#DB2777",
        "#7C3AED",
        "#0891B2",
        "#CA8A04",
        "#DC2626",
        "#4F46E5",
        "#059669"
    ]
}

private enum LoadResult {
    case missing
    case loaded(StudyData, Data)
    case unsupportedSchema(Int)
    case failed(String)
}

private struct SchemaHeader: Decodable {
    let schemaVersion: Int

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}

private extension JSONEncoder {
    static var studyTracker: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var studyTracker: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
