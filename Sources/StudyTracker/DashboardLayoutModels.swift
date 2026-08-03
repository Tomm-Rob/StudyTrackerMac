import Foundation

enum DashboardCardSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case wide
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .wide: "Wide"
        case .extraLarge: "Extra Large"
        }
    }

    var columnSpan: Int {
        switch self {
        case .small: 1
        case .medium, .large: 2
        case .wide: 3
        case .extraLarge: 4
        }
    }

    var rowSpan: Int {
        switch self {
        case .small, .medium: 1
        case .large, .wide: 2
        case .extraLarge: 3
        }
    }
}

struct DashboardCardInstance: Identifiable, Codable, Equatable {
    var id: String
    var kindID: String
    var size: DashboardCardSize
    var isVisible: Bool

    init(
        id: String,
        kindID: String,
        size: DashboardCardSize,
        isVisible: Bool = true
    ) {
        self.id = id
        self.kindID = kindID
        self.size = size
        self.isVisible = isVisible
    }
}

struct DashboardLayout: Codable, Equatable {
    var cards: [DashboardCardInstance]

    init(cards: [DashboardCardInstance] = DashboardCardRegistry.defaultLayoutCards) {
        self.cards = cards
    }
}

struct DashboardCardDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let defaultSize: DashboardCardSize
    let supportedSizes: [DashboardCardSize]
    let defaultVisible: Bool
    let allowsMultiple: Bool

    init(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        defaultSize: DashboardCardSize,
        supportedSizes: [DashboardCardSize],
        defaultVisible: Bool = true,
        allowsMultiple: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.defaultSize = defaultSize
        self.supportedSizes = supportedSizes
        self.defaultVisible = defaultVisible
        self.allowsMultiple = allowsMultiple
    }

    var stableInstanceID: String { "dashboard.\(id)" }
}

enum DashboardCardRegistry {
    static let definitions: [DashboardCardDefinition] = [
        DashboardCardDefinition(
            id: "total-time",
            title: "Total Study Time",
            subtitle: "All recorded study time",
            systemImage: "clock",
            defaultSize: .small,
            supportedSizes: [.small, .medium]
        ),
        DashboardCardDefinition(
            id: "sessions",
            title: "Sessions",
            subtitle: "Number of logged sessions",
            systemImage: "list.bullet.rectangle",
            defaultSize: .small,
            supportedSizes: [.small, .medium]
        ),
        DashboardCardDefinition(
            id: "classes",
            title: "Classes",
            subtitle: "Active classes",
            systemImage: "books.vertical",
            defaultSize: .small,
            supportedSizes: [.small, .medium]
        ),
        DashboardCardDefinition(
            id: "study-timer",
            title: "Study Timer",
            subtitle: "Start and log a live session",
            systemImage: "stopwatch",
            defaultSize: .wide,
            supportedSizes: [.medium, .wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "daily-study",
            title: "Daily Study Time",
            subtitle: "Study time by day",
            systemImage: "chart.bar",
            defaultSize: .large,
            supportedSizes: [.small, .large, .wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "class-breakdown",
            title: "Time by Class",
            subtitle: "Total study share by class",
            systemImage: "chart.pie",
            defaultSize: .small,
            supportedSizes: [.small, .medium, .large, .wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "class-overview",
            title: "Class Overview",
            subtitle: "Class totals and legend",
            systemImage: "circle.grid.cross",
            defaultSize: .extraLarge,
            supportedSizes: [.large, .wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "leaderboard",
            title: "Leaderboard",
            subtitle: "Classes ranked by study time",
            systemImage: "list.number",
            defaultSize: .small,
            supportedSizes: [.small, .medium, .large, .wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "quick-log",
            title: "Quick Log",
            subtitle: "Add a study session",
            systemImage: "plus.circle",
            defaultSize: .wide,
            supportedSizes: [.wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "recent-sessions",
            title: "Recent Sessions",
            subtitle: "Review and edit logged sessions",
            systemImage: "clock.arrow.circlepath",
            defaultSize: .extraLarge,
            supportedSizes: [.large, .wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "local-insights",
            title: "Local Insights",
            subtitle: "Deterministic patterns from your data",
            systemImage: "lightbulb",
            defaultSize: .wide,
            supportedSizes: [.small, .medium, .large, .wide, .extraLarge]
        ),
        DashboardCardDefinition(
            id: "goals",
            title: "Goals",
            subtitle: "Current goal progress and pacing",
            systemImage: "target",
            defaultSize: .large,
            supportedSizes: [.small, .large, .wide, .extraLarge]
        )
    ]

    static var defaultLayoutCards: [DashboardCardInstance] {
        let visibleCards = [
            defaultCard("total-time", size: .small),
            defaultCard("daily-study", size: .small),
            defaultCard("class-breakdown", size: .small),
            defaultCard("leaderboard", size: .small),
            defaultCard("local-insights", size: .small),
            defaultCard("goals", size: .small)
        ]
        let visibleKindIDs = Set(visibleCards.map(\.kindID))
        let hiddenCards = definitions
            .filter { !visibleKindIDs.contains($0.id) }
            .map {
                DashboardCardInstance(
                    id: $0.stableInstanceID,
                    kindID: $0.id,
                    size: $0.defaultSize,
                    isVisible: false
                )
            }

        return visibleCards + hiddenCards
    }

    static var mixedSizeDefaultLayoutCards: [DashboardCardInstance] {
        var cards = defaultLayoutCards
        if let index = cards.firstIndex(where: { $0.kindID == "daily-study" }) {
            cards[index].size = .large
        }
        return cards
    }

    static var previousDefaultLayoutCards: [DashboardCardInstance] {
        definitions.map {
            DashboardCardInstance(
                id: $0.stableInstanceID,
                kindID: $0.id,
                size: $0.defaultSize,
                isVisible: $0.defaultVisible
            )
        }
    }

    static var legacyDefaultLayoutCards: [DashboardCardInstance] {
        definitions.map {
            DashboardCardInstance(
                id: $0.stableInstanceID,
                kindID: $0.id,
                size: ["class-breakdown", "leaderboard"].contains($0.id)
                    ? .large
                    : $0.defaultSize,
                isVisible: $0.defaultVisible
            )
        }
    }

    private static func defaultCard(
        _ kindID: String,
        size: DashboardCardSize
    ) -> DashboardCardInstance {
        DashboardCardInstance(
            id: "dashboard.\(kindID)",
            kindID: kindID,
            size: size
        )
    }

    static func definition(for kindID: String) -> DashboardCardDefinition? {
        definitions.first { $0.id == kindID }
    }
}

struct DashboardGridPlacement: Equatable {
    let instanceID: String
    let row: Int
    let column: Int
    let columnSpan: Int
    let rowSpan: Int
}

struct DashboardLayoutService {
    func recommendedColumnCount(forAvailableWidth width: CGFloat) -> Int {
        if width >= 540 { return 3 }
        if width >= 360 { return 2 }
        return 1
    }

    func applyingUpdatedDefaults(to layout: DashboardLayout) -> DashboardLayout {
        let knownPreviousDefaults = [
            DashboardCardRegistry.mixedSizeDefaultLayoutCards,
            DashboardCardRegistry.previousDefaultLayoutCards,
            DashboardCardRegistry.legacyDefaultLayoutCards
        ]
        guard knownPreviousDefaults.contains(layout.cards) else {
            return layout
        }
        return DashboardLayout()
    }

    func normalized(_ layout: DashboardLayout) -> DashboardLayout {
        var normalizedCards: [DashboardCardInstance] = []
        var seenIDs = Set<String>()
        var seenSingletonKinds = Set<String>()

        for card in layout.cards {
            guard let definition = DashboardCardRegistry.definition(for: card.kindID),
                  !card.id.isEmpty,
                  seenIDs.insert(card.id).inserted else { continue }

            if !definition.allowsMultiple,
               !seenSingletonKinds.insert(card.kindID).inserted {
                continue
            }

            var normalizedCard = card
            if !definition.supportedSizes.contains(card.size) {
                normalizedCard.size = definition.defaultSize
            }
            normalizedCards.append(normalizedCard)
        }

        for definition in DashboardCardRegistry.definitions
        where !seenSingletonKinds.contains(definition.id) {
            normalizedCards.append(
                DashboardCardInstance(
                    id: definition.stableInstanceID,
                    kindID: definition.id,
                    size: definition.defaultSize,
                    isVisible: definition.defaultVisible
                )
            )
        }

        return DashboardLayout(cards: normalizedCards)
    }

    func move(_ instanceID: String, before targetID: String, in layout: DashboardLayout) -> DashboardLayout {
        guard instanceID != targetID,
              let sourceIndex = layout.cards.firstIndex(where: { $0.id == instanceID }),
              let targetIndex = layout.cards.firstIndex(where: { $0.id == targetID }) else {
            return layout
        }

        var cards = layout.cards
        let card = cards.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        cards.insert(card, at: adjustedTarget)
        return DashboardLayout(cards: cards)
    }

    func setVisibility(_ isVisible: Bool, for instanceID: String, in layout: DashboardLayout) -> DashboardLayout {
        var cards = layout.cards
        guard let index = cards.firstIndex(where: { $0.id == instanceID }) else { return layout }
        cards[index].isVisible = isVisible
        return DashboardLayout(cards: cards)
    }

    func resize(_ instanceID: String, to size: DashboardCardSize, in layout: DashboardLayout) -> DashboardLayout {
        var cards = layout.cards
        guard let index = cards.firstIndex(where: { $0.id == instanceID }),
              let definition = DashboardCardRegistry.definition(for: cards[index].kindID),
              definition.supportedSizes.contains(size) else {
            return layout
        }
        cards[index].size = size
        return DashboardLayout(cards: cards)
    }

    func makingVisibleCardsUniform(_ layout: DashboardLayout) -> DashboardLayout {
        let visibleCards = layout.cards.filter(\.isVisible)
        guard !visibleCards.isEmpty,
              visibleCards.allSatisfy({ card in
                  DashboardCardRegistry.definition(for: card.kindID)?.supportedSizes.contains(.small) == true
              }) else {
            return layout
        }

        var cards = layout.cards
        for index in cards.indices where cards[index].isVisible {
            cards[index].size = .small
        }
        return DashboardLayout(cards: cards)
    }

    func placements(
        for cards: [DashboardCardInstance],
        columnCount: Int
    ) -> [DashboardGridPlacement] {
        let columns = max(1, columnCount)
        var occupied: [[Bool]] = []
        var result: [DashboardGridPlacement] = []

        for card in cards where card.isVisible {
            let columnSpan = min(card.size.columnSpan, columns)
            let rowSpan = card.size.rowSpan
            var row = 0
            var placed = false

            while !placed {
                ensureRows(row + rowSpan, columns: columns, occupied: &occupied)
                for column in 0...(columns - columnSpan) {
                    guard areaIsFree(
                        row: row,
                        column: column,
                        rowSpan: rowSpan,
                        columnSpan: columnSpan,
                        occupied: occupied
                    ) else { continue }

                    occupy(
                        row: row,
                        column: column,
                        rowSpan: rowSpan,
                        columnSpan: columnSpan,
                        occupied: &occupied
                    )
                    result.append(
                        DashboardGridPlacement(
                            instanceID: card.id,
                            row: row,
                            column: column,
                            columnSpan: columnSpan,
                            rowSpan: rowSpan
                        )
                    )
                    placed = true
                    break
                }
                if !placed { row += 1 }
            }
        }

        return result
    }

    private func ensureRows(_ count: Int, columns: Int, occupied: inout [[Bool]]) {
        while occupied.count < count {
            occupied.append(Array(repeating: false, count: columns))
        }
    }

    private func areaIsFree(
        row: Int,
        column: Int,
        rowSpan: Int,
        columnSpan: Int,
        occupied: [[Bool]]
    ) -> Bool {
        for rowIndex in row..<(row + rowSpan) {
            for columnIndex in column..<(column + columnSpan)
            where occupied[rowIndex][columnIndex] {
                return false
            }
        }
        return true
    }

    private func occupy(
        row: Int,
        column: Int,
        rowSpan: Int,
        columnSpan: Int,
        occupied: inout [[Bool]]
    ) {
        for rowIndex in row..<(row + rowSpan) {
            for columnIndex in column..<(column + columnSpan) {
                occupied[rowIndex][columnIndex] = true
            }
        }
    }
}
