import Foundation
import XCTest
@testable import StudyTracker

final class DashboardLayoutServiceTests: XCTestCase {
    private let service = DashboardLayoutService()

    func testLayoutSavesAndRestoresWithStableIdentifiers() throws {
        var layout = DashboardLayout()
        layout = service.resize("dashboard.daily-study", to: .extraLarge, in: layout)
        layout = service.setVisibility(false, for: "dashboard.classes", in: layout)
        layout = service.move("dashboard.local-insights", before: "dashboard.total-time", in: layout)
        let data = StudyData(dashboardLayout: layout)

        let encoded = try JSONEncoder().encode(data)
        let restored = try JSONDecoder().decode(StudyData.self, from: encoded)

        XCTAssertEqual(restored.dashboardLayout, layout)
        XCTAssertEqual(restored.dashboardLayout.cards.first?.id, "dashboard.local-insights")
        XCTAssertFalse(try XCTUnwrap(
            restored.dashboardLayout.cards.first { $0.id == "dashboard.classes" }
        ).isVisible)
    }

    func testGridReflowsWithinAvailableColumns() {
        let cards = [
            DashboardCardInstance(id: "wide", kindID: "daily-study", size: .wide),
            DashboardCardInstance(id: "small", kindID: "sessions", size: .small),
            DashboardCardInstance(id: "large", kindID: "leaderboard", size: .large)
        ]

        let fourColumn = service.placements(for: cards, columnCount: 4)
        let oneColumn = service.placements(for: cards, columnCount: 1)

        XCTAssertEqual(fourColumn[0], DashboardGridPlacement(
            instanceID: "wide", row: 0, column: 0, columnSpan: 3, rowSpan: 2
        ))
        XCTAssertEqual(fourColumn[1].column, 3)
        XCTAssertTrue(oneColumn.allSatisfy { $0.column == 0 && $0.columnSpan == 1 })
        XCTAssertEqual(oneColumn.map(\.instanceID), ["wide", "small", "large"])
    }

    func testUnsupportedSizeFallsBackDuringNormalizationAndCannotBeApplied() {
        let invalid = DashboardLayout(cards: [
            DashboardCardInstance(
                id: "dashboard.total-time",
                kindID: "total-time",
                size: .extraLarge
            )
        ])

        let normalized = service.normalized(invalid)
        let total = normalized.cards.first { $0.kindID == "total-time" }

        XCTAssertEqual(total?.size, .small)
        XCTAssertEqual(
            service.resize("dashboard.total-time", to: .wide, in: normalized),
            normalized
        )
    }

    func testMissingAndUnknownCardsAreReconciledWithRegistry() {
        let partial = DashboardLayout(cards: [
            DashboardCardInstance(id: "unknown", kindID: "removed-card", size: .small),
            DashboardCardInstance(
                id: "dashboard.sessions",
                kindID: "sessions",
                size: .medium,
                isVisible: false
            )
        ])

        let normalized = service.normalized(partial)

        XCTAssertNil(normalized.cards.first { $0.kindID == "removed-card" })
        XCTAssertEqual(normalized.cards.count, DashboardCardRegistry.definitions.count)
        XCTAssertFalse(try! XCTUnwrap(
            normalized.cards.first { $0.kindID == "sessions" }
        ).isVisible)
        XCTAssertNotNil(normalized.cards.first { $0.kindID == "daily-study" })
    }

    func testDuplicateIdentifiersAndSingletonKindsAreRemoved() {
        let duplicates = DashboardLayout(cards: [
            DashboardCardInstance(id: "first", kindID: "sessions", size: .small),
            DashboardCardInstance(id: "first", kindID: "total-time", size: .small),
            DashboardCardInstance(id: "second", kindID: "sessions", size: .medium)
        ])

        let normalized = service.normalized(duplicates)

        XCTAssertEqual(normalized.cards.filter { $0.kindID == "sessions" }.count, 1)
        XCTAssertEqual(normalized.cards.filter { $0.id == "first" }.count, 1)
        XCTAssertEqual(normalized.cards.count, DashboardCardRegistry.definitions.count)
    }
}
