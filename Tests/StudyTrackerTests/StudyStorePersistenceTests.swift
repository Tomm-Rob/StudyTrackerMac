import XCTest
@testable import StudyTracker

@MainActor
final class StudyStorePersistenceTests: XCTestCase {
    func testLegacyDataIsImportedIntoProtectedSaveFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyURL = directory.appendingPathComponent("study-tracker-data.json")
        let legacyData = try encodedData(className: "Recovered Course")
        try legacyData.write(to: legacyURL)

        let store = StudyStore(saveDirectory: directory)

        XCTAssertEqual(store.data.classes.map(\.name), ["Recovered Course"])
        XCTAssertEqual(store.dataFileURL.lastPathComponent, "study-tracker-data-v2.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.dataFileURL.path))
        XCTAssertEqual(try Data(contentsOf: legacyURL), legacyData)
    }

    func testProtectedSaveTakesPriorityOverLaterLegacyChanges() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let legacyURL = directory.appendingPathComponent("study-tracker-data.json")
        try encodedData(className: "Protected Course").write(to: legacyURL)
        let firstStore = StudyStore(saveDirectory: directory)
        XCTAssertEqual(firstStore.data.classes.map(\.name), ["Protected Course"])

        try encodedData(className: "Stale Course").write(to: legacyURL)
        let reopenedStore = StudyStore(saveDirectory: directory)

        XCTAssertEqual(reopenedStore.data.classes.map(\.name), ["Protected Course"])
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudyTrackerPersistenceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func encodedData(className: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(
            StudyData(
                schemaVersion: 4,
                classes: [StudyClass(name: className, colorHex: "#2563EB")]
            )
        )
    }
}
