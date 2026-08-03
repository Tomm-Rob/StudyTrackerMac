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

    func testDashboardUsesUpToThreeColumnsAsSpaceAllows() {
        XCTAssertEqual(service.recommendedColumnCount(forAvailableWidth: 359), 1)
        XCTAssertEqual(service.recommendedColumnCount(forAvailableWidth: 360), 2)
        XCTAssertEqual(service.recommendedColumnCount(forAvailableWidth: 539), 2)
        XCTAssertEqual(service.recommendedColumnCount(forAvailableWidth: 540), 3)
        XCTAssertEqual(service.recommendedColumnCount(forAvailableWidth: 1_400), 3)
    }

    func testDailyChartSupportsUniformCompactSize() throws {
        let definition = try XCTUnwrap(
            DashboardCardRegistry.definition(for: "daily-study")
        )

        XCTAssertTrue(definition.supportedSizes.contains(.small))
    }

    func testDonutCardSupportsCompactSizesAndDefaultsToSmall() throws {
        let definition = try XCTUnwrap(
            DashboardCardRegistry.definition(for: "class-breakdown")
        )

        XCTAssertEqual(definition.defaultSize, .small)
        XCTAssertTrue(definition.supportedSizes.contains(.small))
        XCTAssertTrue(definition.supportedSizes.contains(.medium))
    }

    func testLeaderboardSupportsCompactSizesAndDefaultsToSmall() throws {
        let definition = try XCTUnwrap(
            DashboardCardRegistry.definition(for: "leaderboard")
        )

        XCTAssertEqual(definition.defaultSize, .small)
        XCTAssertTrue(definition.supportedSizes.contains(.small))
        XCTAssertTrue(definition.supportedSizes.contains(.medium))
    }

    func testInsightsCardSupportsSmallSquareSize() throws {
        let definition = try XCTUnwrap(
            DashboardCardRegistry.definition(for: "local-insights")
        )

        XCTAssertTrue(definition.supportedSizes.contains(.small))
    }

    func testGoalsCardSupportsSmallSquareSize() throws {
        let definition = try XCTUnwrap(
            DashboardCardRegistry.definition(for: "goals")
        )

        XCTAssertTrue(definition.supportedSizes.contains(.small))
    }

    func testDefaultLayoutUsesUniformThreeColumnRectangles() {
        let visibleCards = DashboardCardRegistry.defaultLayoutCards.filter(\.isVisible)
        XCTAssertEqual(
            visibleCards.map(\.kindID),
            [
                "total-time",
                "daily-study",
                "class-breakdown",
                "leaderboard",
                "local-insights",
                "goals"
            ]
        )
        XCTAssertEqual(
            visibleCards.map(\.size),
            [.small, .small, .small, .small, .small, .small]
        )

        let placements = service.placements(for: visibleCards, columnCount: 3)
        XCTAssertEqual(placements, [
            DashboardGridPlacement(
                instanceID: "dashboard.total-time",
                row: 0,
                column: 0,
                columnSpan: 1,
                rowSpan: 1
            ),
            DashboardGridPlacement(
                instanceID: "dashboard.daily-study",
                row: 0,
                column: 1,
                columnSpan: 1,
                rowSpan: 1
            ),
            DashboardGridPlacement(
                instanceID: "dashboard.class-breakdown",
                row: 0,
                column: 2,
                columnSpan: 1,
                rowSpan: 1
            ),
            DashboardGridPlacement(
                instanceID: "dashboard.leaderboard",
                row: 1,
                column: 0,
                columnSpan: 1,
                rowSpan: 1
            ),
            DashboardGridPlacement(
                instanceID: "dashboard.local-insights",
                row: 1,
                column: 1,
                columnSpan: 1,
                rowSpan: 1
            ),
            DashboardGridPlacement(
                instanceID: "dashboard.goals",
                row: 1,
                column: 2,
                columnSpan: 1,
                rowSpan: 1
            )
        ])
    }

    func testUniformCardsResizesSupportedVisibleCardsAndPreservesHiddenCards() {
        let layout = DashboardLayout(cards: [
            DashboardCardInstance(id: "dashboard.daily-study", kindID: "daily-study", size: .large),
            DashboardCardInstance(id: "dashboard.goals", kindID: "goals", size: .wide),
            DashboardCardInstance(
                id: "dashboard.recent-sessions",
                kindID: "recent-sessions",
                size: .extraLarge,
                isVisible: false
            )
        ])

        let uniform = service.makingVisibleCardsUniform(layout)

        XCTAssertEqual(uniform.cards[0].size, .small)
        XCTAssertEqual(uniform.cards[1].size, .small)
        XCTAssertEqual(uniform.cards[2].size, .extraLarge)
    }

    func testUniformCardsLeavesUnsupportedVisibleLayoutUnchanged() {
        let layout = DashboardLayout(cards: [
            DashboardCardInstance(id: "dashboard.quick-log", kindID: "quick-log", size: .wide)
        ])

        XCTAssertEqual(service.makingVisibleCardsUniform(layout), layout)
    }

    func testOldDefaultsReceiveNewLayoutWithoutChangingCustomLayouts() {
        let mixedSizeDefault = DashboardLayout(
            cards: DashboardCardRegistry.mixedSizeDefaultLayoutCards
        )
        let previousDefault = DashboardLayout(
            cards: DashboardCardRegistry.previousDefaultLayoutCards
        )
        let legacyDefault = DashboardLayout(
            cards: DashboardCardRegistry.legacyDefaultLayoutCards
        )
        XCTAssertEqual(
            service.applyingUpdatedDefaults(to: mixedSizeDefault),
            DashboardLayout()
        )
        XCTAssertEqual(
            service.applyingUpdatedDefaults(to: previousDefault),
            DashboardLayout()
        )
        XCTAssertEqual(
            service.applyingUpdatedDefaults(to: legacyDefault),
            DashboardLayout()
        )

        let customized = service.setVisibility(
            false,
            for: "dashboard.classes",
            in: previousDefault
        )
        XCTAssertEqual(service.applyingUpdatedDefaults(to: customized), customized)
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
