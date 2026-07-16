import Foundation
import AppKit

@MainActor
final class StudyStore: ObservableObject {
    static let maxClasses = 50

    @Published var data: StudyData {
        didSet {
            if data.classes.count > Self.maxClasses {
                data.classes = Array(data.classes.prefix(Self.maxClasses))
            }
            save()
        }
    }

    @Published private(set) var dataFileURL: URL
    @Published var lastError: String?

    private static let dataFileName = "study-tracker-data.json"
    private static let directoryKey = "StudyTracker.SaveDirectory"

    init() {
        let directory = Self.initialSaveDirectory()
        let fileURL = directory.appendingPathComponent(Self.dataFileName)
        self.dataFileURL = fileURL
        self.data = Self.load(from: fileURL)
        ensureSaveDirectoryExists()
        save()
    }

    func addClass() {
        guard data.classes.count < Self.maxClasses else { return }

        let color = defaultColors[data.classes.count % defaultColors.count]
        var baseName = "New Class"
        var index = 1
        let names = Set(data.classes.map(\.name))

        while names.contains(baseName) {
            index += 1
            baseName = "New Class \(index)"
        }

        data.classes.append(StudyClass(name: baseName, colorHex: color))
    }

    func deleteClass(id: UUID) {
        data.classes.removeAll { $0.id == id }
        data.sessions.removeAll { $0.classID == id }
    }

    func addSession(classID: UUID, date: Date, duration: TimeInterval) {
        guard duration > 0, data.classes.contains(where: { $0.id == classID }) else { return }
        data.sessions.append(StudySession(classID: classID, date: date, duration: duration))
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
            .sorted { $0.date > $1.date }
    }

    func dailyTotals(for classID: UUID? = nil, daysBack: Int = 14) -> [DailyTotal] {
        let calendar = Calendar.current
        let today = Date().startOfDay
        let start = calendar.date(byAdding: .day, value: -(daysBack - 1), to: today) ?? today
        let relevantSessions = data.sessions.filter { session in
            let isMatchingClass = classID == nil || session.classID == classID
            return isMatchingClass && session.date.startOfDay >= start
        }

        let grouped = Dictionary(grouping: relevantSessions, by: { $0.date.startOfDay })
            .mapValues { $0.reduce(0) { $0 + $1.duration } }

        return (0..<daysBack).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DailyTotal(date: day, seconds: grouped[day] ?? 0)
        }
    }

    func classTotals() -> [ClassTotal] {
        let grouped = Dictionary(grouping: data.sessions, by: \.classID)
            .mapValues { $0.reduce(0) { $0 + $1.duration } }

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

    private static func load(from url: URL) -> StudyData {
        guard let rawData = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.studyTracker.decode(StudyData.self, from: rawData) else {
            return StudyData()
        }

        return decoded
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
