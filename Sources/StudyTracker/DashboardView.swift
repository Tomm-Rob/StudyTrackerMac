import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID?

    @State private var daysBack = 14
    @State private var editingSession: StudySession?
    @State private var isEditingDashboard = false
    @State private var isShowingCardGallery = false
    @State private var isConfirmingReset = false
    private let layoutService = DashboardLayoutService()
    private let dashboardColumns = [
        GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 10)
    ]

    private var title: String {
        if let classID {
            return store.className(for: classID)
        }

        return "Dashboard"
    }

    private var totalSeconds: TimeInterval {
        store.sessions(for: classID).reduce(0) { $0 + $1.duration }
    }

    private var sessionCount: Int {
        store.sessions(for: classID).count
    }

    private var averageSessionDuration: TimeInterval {
        guard sessionCount > 0 else { return 0 }
        return totalSeconds / Double(sessionCount)
    }

    var body: some View {
        Group {
            if classID == nil {
                customizableDashboard
            } else {
                classDashboard
            }
        }
        .sheet(item: $editingSession) { session in
            SessionEditSheet(session: session)
        }
        .sheet(isPresented: $isShowingCardGallery) {
            DashboardCardGallery(
                hiddenDefinitions: hiddenCardDefinitions,
                restore: restoreCard
            )
        }
        .confirmationDialog(
            "Reset the dashboard to its default cards, sizes, and order?",
            isPresented: $isConfirmingReset
        ) {
            Button("Reset Dashboard", role: .destructive) {
                store.data.dashboardLayout = DashboardLayout()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            let updatedDefaults = layoutService.applyingUpdatedDefaults(
                to: store.data.dashboardLayout
            )
            let normalized = layoutService.normalized(updatedDefaults)
            if normalized != store.data.dashboardLayout {
                store.data.dashboardLayout = normalized
            }
        }
    }

    private var customizableDashboard: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 720 || geometry.size.height < 620
            let cards = visibleDashboardCards

            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                    dashboardHeader(isCompact: isCompact)

                    if cards.isEmpty {
                        ContentUnavailableView(
                            "Dashboard is empty",
                            systemImage: "rectangle.grid.2x2",
                            description: Text("Edit the dashboard and add cards from the gallery.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else if !cards.isEmpty {
                        DashboardResponsiveGrid(spacing: 10) {
                            ForEach(cards) { card in
                                DashboardCardHost(
                                    card: card,
                                    definition: DashboardCardRegistry.definition(for: card.kindID),
                                    isEditing: isEditingDashboard,
                                    canMoveBackward: cards.first?.id != card.id,
                                    canMoveForward: cards.last?.id != card.id,
                                    moveBackward: { moveCard(card.id, by: -1) },
                                    moveForward: { moveCard(card.id, by: 1) },
                                    moveBefore: { sourceID in
                                        moveCard(sourceID, before: card.id)
                                    },
                                    resize: { resizeCard(card.id, to: $0) },
                                    hide: { setCardVisibility(card.id, isVisible: false) }
                                ) {
                                    dashboardCardContent(for: card)
                                }
                                .dashboardCardSize(card.size)
                            }
                        }
                    }
                }
                .padding(isCompact ? 10 : 16)
            }
        }
    }

    private var classDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                classHeader

                LazyVGrid(columns: dashboardColumns, alignment: .leading, spacing: 10) {
                    MetricTile(title: "Total Study Time", value: totalSeconds.compactDuration, systemImage: "clock")
                    MetricTile(title: "Sessions", value: "\(sessionCount)", systemImage: "list.bullet.rectangle")
                    MetricTile(
                        title: "Average Session",
                        value: averageSessionDuration.compactDuration,
                        systemImage: "chart.line.uptrend.xyaxis"
                    )
                }

                StudySessionTimer(classID: classID)
                GoalsSection(classID: classID, maximumVisible: 5)
                DailyBarChart(classID: classID, daysBack: daysBack)
                    .frame(minHeight: 250)
                SessionEditor(classID: classID)
                SessionList(classID: classID, editingSession: $editingSession)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func dashboardHeader(isCompact: Bool) -> some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    titleBlock(showSubtitle: false)
                    Spacer(minLength: 4)
                    compactRangePicker

                    if !isEditingDashboard {
                        Button {
                            isEditingDashboard = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .help("Edit dashboard")
                    }
                }

                if isEditingDashboard {
                    dashboardEditControls
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    titleBlock()
                    Spacer()
                    rangePicker
                    dashboardEditControls
                }

                VStack(alignment: .leading, spacing: 10) {
                    titleBlock()
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            rangePicker
                            Spacer()
                            dashboardEditControls
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            rangePicker
                            dashboardEditControls
                        }
                    }
                }
            }
        }
    }

    private var classHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center) {
                titleBlock()
                Spacer()
                rangePicker
            }

            VStack(alignment: .leading, spacing: 10) {
                titleBlock()
                rangePicker
                    .frame(maxWidth: 310)
            }
        }
    }

    @ViewBuilder
    private var dashboardEditControls: some View {
        if isEditingDashboard {
            HStack(spacing: 8) {
                Button {
                    isShowingCardGallery = true
                } label: {
                    Label("Add Card", systemImage: "plus")
                }

                Button {
                    isConfirmingReset = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Reset dashboard")

                Button("Done") {
                    isEditingDashboard = false
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Button {
                isEditingDashboard = true
            } label: {
                Label("Edit Dashboard", systemImage: "slider.horizontal.3")
            }
        }
    }

    private func titleBlock(showSubtitle: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            if showSubtitle {
                Text("Log time, review daily progress, and keep class totals in view.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $daysBack) {
            Text("7 days").tag(7)
            Text("14 days").tag(14)
            Text("30 days").tag(30)
            Text("90 days").tag(90)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 300)
    }

    private var compactRangePicker: some View {
        Picker("Range", selection: $daysBack) {
            Text("7 days").tag(7)
            Text("14 days").tag(14)
            Text("30 days").tag(30)
            Text("90 days").tag(90)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 105)
    }

    private var visibleDashboardCards: [DashboardCardInstance] {
        store.data.dashboardLayout.cards.filter(\.isVisible)
    }

    private var hiddenCardDefinitions: [DashboardCardDefinition] {
        let visibleKindIDs = Set(visibleDashboardCards.map(\.kindID))
        return DashboardCardRegistry.definitions.filter { !visibleKindIDs.contains($0.id) }
    }

    @ViewBuilder
    private func dashboardCardContent(for card: DashboardCardInstance) -> some View {
        switch card.kindID {
        case "total-time":
            MetricTile(title: "Total Study Time", value: totalSeconds.compactDuration, systemImage: "clock")
        case "sessions":
            MetricTile(title: "Sessions", value: "\(sessionCount)", systemImage: "list.bullet.rectangle")
        case "classes":
            MetricTile(title: "Classes", value: "\(store.activeClasses.count)", systemImage: "books.vertical")
        case "study-timer":
            StudySessionTimer(classID: nil)
        case "daily-study":
            DailyBarChart(classID: nil, daysBack: daysBack)
        case "class-breakdown":
            ClassDonutChart(size: card.size)
        case "class-overview":
            ClassOverviewChart()
        case "leaderboard":
            ClassLeaderboard(size: card.size)
        case "quick-log":
            SessionEditor(classID: nil)
        case "recent-sessions":
            DashboardRecentSessions(editingSession: $editingSession)
        case "local-insights":
            DashboardInsightsCard(
                maximumVisible: insightCount(for: card.size),
                compact: card.size == .small || card.size == .medium
            )
        case "goals":
            GoalsSection(
                classID: nil,
                maximumVisible: card.size == .small ? 1 : 3,
                compact: card.size == .small
            )
        default:
            EmptyView()
        }
    }

    private func setCardVisibility(_ id: String, isVisible: Bool) {
        store.data.dashboardLayout = layoutService.setVisibility(
            isVisible,
            for: id,
            in: store.data.dashboardLayout
        )
    }

    private func restoreCard(_ definition: DashboardCardDefinition) {
        guard let card = store.data.dashboardLayout.cards.first(where: { $0.kindID == definition.id }) else {
            return
        }
        setCardVisibility(card.id, isVisible: true)
    }

    private func resizeCard(_ id: String, to size: DashboardCardSize) {
        store.data.dashboardLayout = layoutService.resize(
            id,
            to: size,
            in: store.data.dashboardLayout
        )
    }

    private func moveCard(_ sourceID: String, before targetID: String) {
        store.data.dashboardLayout = layoutService.move(
            sourceID,
            before: targetID,
            in: store.data.dashboardLayout
        )
    }

    private func moveCard(_ id: String, by offset: Int) {
        let cards = visibleDashboardCards
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex = index + offset
        guard cards.indices.contains(targetIndex) else { return }

        if offset < 0 {
            moveCard(id, before: cards[targetIndex].id)
        } else {
            moveCard(cards[targetIndex].id, before: id)
        }
    }

    private func insightCount(for size: DashboardCardSize) -> Int {
        switch size {
        case .small, .medium: 1
        case .large, .wide: 2
        case .extraLarge: 4
        }
    }
}

private struct DashboardCardSizeKey: LayoutValueKey {
    static let defaultValue = DashboardCardSize.small
}

private extension View {
    func dashboardCardSize(_ size: DashboardCardSize) -> some View {
        layoutValue(key: DashboardCardSizeKey.self, value: size)
    }
}

private struct DashboardResponsiveGrid: Layout {
    let spacing: CGFloat
    private let rowHeight: CGFloat = 130
    private let service = DashboardLayoutService()

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? 900
        let placements = makePlacements(subviews: subviews, width: width)
        let rows = placements.map { $0.row + $0.rowSpan }.max() ?? 0
        let height = rows > 0
            ? CGFloat(rows) * rowHeight + CGFloat(rows - 1) * spacing
            : 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let columns = columnCount(for: bounds.width)
        let placements = makePlacements(subviews: subviews, width: bounds.width)
        let columnWidth = (bounds.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)

        for (index, placement) in placements.enumerated() where subviews.indices.contains(index) {
            let width = CGFloat(placement.columnSpan) * columnWidth
                + CGFloat(placement.columnSpan - 1) * spacing
            let height = CGFloat(placement.rowSpan) * rowHeight
                + CGFloat(placement.rowSpan - 1) * spacing
            let point = CGPoint(
                x: bounds.minX + CGFloat(placement.column) * (columnWidth + spacing),
                y: bounds.minY + CGFloat(placement.row) * (rowHeight + spacing)
            )
            subviews[index].place(
                at: point,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
        }
    }

    private func makePlacements(subviews: Subviews, width: CGFloat) -> [DashboardGridPlacement] {
        let cards = subviews.enumerated().map { index, subview in
            DashboardCardInstance(
                id: String(index),
                kindID: String(index),
                size: subview[DashboardCardSizeKey.self]
            )
        }
        return service.placements(for: cards, columnCount: columnCount(for: width))
    }

    private func columnCount(for width: CGFloat) -> Int {
        service.recommendedColumnCount(forAvailableWidth: width)
    }
}

private struct DashboardCardHost<Content: View>: View {
    let card: DashboardCardInstance
    let definition: DashboardCardDefinition?
    let isEditing: Bool
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let moveBackward: () -> Void
    let moveForward: () -> Void
    let moveBefore: (String) -> Void
    let resize: (DashboardCardSize) -> Void
    let hide: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Group {
            if isEditing {
                cardBody
                    .draggable(card.id)
                    .dropDestination(for: String.self) { items, _ in
                        guard let sourceID = items.first else { return false }
                        moveBefore(sourceID)
                        return true
                    }
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    editToolbar
                        .padding(7)
                }
            }
            .overlay {
                if isEditing {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .allowsHitTesting(false)
                }
            }
    }

    private var editToolbar: some View {
        HStack(spacing: 2) {
            Button(action: moveBackward) {
                Image(systemName: "arrow.left")
            }
            .disabled(!canMoveBackward)
            .help("Move earlier")

            Button(action: moveForward) {
                Image(systemName: "arrow.right")
            }
            .disabled(!canMoveForward)
            .help("Move later")

            if let definition, definition.supportedSizes.count > 1 {
                Menu {
                    ForEach(definition.supportedSizes) { size in
                        Button {
                            resize(size)
                        } label: {
                            if size == card.size {
                                Label(size.title, systemImage: "checkmark")
                            } else {
                                Text(size.title)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .help("Resize card")
            }

            Button(action: hide) {
                Image(systemName: "eye.slash")
            }
            .help("Hide card")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(3)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct DashboardCardGallery: View {
    @Environment(\.dismiss) private var dismiss
    let hiddenDefinitions: [DashboardCardDefinition]
    let restore: (DashboardCardDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Add Card")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            if hiddenDefinitions.isEmpty {
                ContentUnavailableView(
                    "All cards are visible",
                    systemImage: "rectangle.grid.2x2.fill"
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 210), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(hiddenDefinitions) { definition in
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: definition.systemImage)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                Text(definition.title)
                                    .font(.headline)
                                Text(definition.subtitle)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button {
                                    restore(definition)
                                } label: {
                                    Label("Add", systemImage: "plus")
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
                            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(minWidth: 520, minHeight: 360)
    }
}

private struct DashboardRecentSessions: View {
    @EnvironmentObject private var store: StudyStore
    @Binding var editingSession: StudySession?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.headline)

            let sessions = Array(store.sessions().prefix(6))
            if sessions.isEmpty {
                EmptyChartState(systemImage: "clock.arrow.circlepath", title: "No sessions yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        Button {
                            editingSession = session
                        } label: {
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(Color(hex: store.classColor(for: session.classID)))
                                    .frame(width: 8, height: 8)
                                Text(store.className(for: session.classID))
                                    .lineLimit(1)
                                Spacer()
                                Text(session.duration.compactDuration)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)

                        if session.id != sessions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DashboardInsightsCard: View {
    @EnvironmentObject private var store: StudyStore
    private let service = InsightsService()
    let maximumVisible: Int
    let compact: Bool

    init(maximumVisible: Int = 4, compact: Bool = false) {
        self.maximumVisible = max(1, maximumVisible)
        self.compact = compact
    }

    private var insights: [GeneratedInsight] {
        service.snapshot(
            classes: store.data.classes,
            sessions: store.data.sessions,
            interval: nil
        ).generatedInsights
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            Label("Local Insights", systemImage: "lightbulb")
                .font(.headline)

            ForEach(insights.prefix(maximumVisible)) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.callout.weight(.semibold))
                        Text(insight.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 2 : nil)
                        Text(insight.dateRangeDescription)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(compact ? 10 : 12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ClassDetailView: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID

    var body: some View {
        VStack(spacing: 0) {
            ClassHeader(classID: classID)
            Divider()
            DashboardView(classID: classID)
        }
    }
}

private struct ClassHeader: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID
    @State private var confirmDelete = false
    @State private var isEditingCourse = false

    private var index: Int? {
        store.data.classes.firstIndex(where: { $0.id == classID })
    }

    var body: some View {
        if let index {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    nameAndColor(index: index)
                    planningSummary(index: index)
                    Spacer(minLength: 0)
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    nameAndColor(index: index)
                    HStack {
                        planningSummary(index: index)
                        Spacer()
                        actionButtons
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .confirmationDialog("Archive this class? Its study history will be preserved.", isPresented: $confirmDelete) {
                Button("Archive Class") {
                    store.archiveClass(id: classID)
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $isEditingCourse) {
                CoursePlanningEditor(studyClass: store.data.classes[index])
            }
        }
    }

    private func nameAndColor(index: Int) -> some View {
        HStack(spacing: 10) {
            TextField("Class Name", text: $store.data.classes[index].name)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .semibold, design: .rounded))

            ColorPicker(
                "Class color",
                selection: Binding(
                    get: { Color(hex: store.data.classes[index].colorHex) },
                    set: {
                        store.data.classes[index].colorHex =
                            $0.hexString() ?? store.data.classes[index].colorHex
                    }
                )
            )
            .labelsHidden()
        }
    }

    @ViewBuilder
    private func planningSummary(index: Int) -> some View {
        if let studyClass = store.data.classes[safe: index] {
            CoursePlanningSummary(studyClass: studyClass)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
                isEditingCourse = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                confirmDelete = true
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DailyBarChart: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID?
    let daysBack: Int
    @State private var hoverTooltip: ChartHoverTooltip?

    private var barColor: Color {
        if let classID {
            return Color(hex: store.classColor(for: classID))
        }

        return Color(hex: store.data.chartSettings.dailyBarColorHex)
    }

    var body: some View {
        let totals = store.dailyTotals(for: classID, daysBack: daysBack)
        let classTotals = classID == nil
            ? store.dailyClassTotals(daysBack: daysBack)
            : []
        let studiedClassIDs = Set(classTotals.map { $0.studyClass.id })
        let styledClasses = store.data.classes.filter { studiedClassIDs.contains($0.id) }
        let classStyleDomain = styledClasses.map { $0.id.uuidString }
        let classStyleRange = styledClasses.map { Color(hex: $0.colorHex) }

        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Study Time")
                .font(.headline)

            if totals.allSatisfy({ $0.seconds <= 0 }) {
                EmptyChartState(systemImage: "chart.bar", title: "No study time logged yet")
            } else {
                ZStack(alignment: .topLeading) {
                    Chart {
                        if classID != nil {
                            ForEach(totals) { day in
                                BarMark(
                                    x: .value("Day", day.date, unit: .day),
                                    y: .value("Hours", day.seconds.hours)
                                )
                                .foregroundStyle(barColor)
                                .cornerRadius(4)
                            }
                        } else {
                            ForEach(classTotals) { total in
                                BarMark(
                                    x: .value("Day", total.date, unit: .day),
                                    y: .value("Hours", total.seconds.hours)
                                )
                                .foregroundStyle(
                                    by: .value("Class", total.studyClass.id.uuidString)
                                )
                            }
                        }
                    }
                    .chartForegroundStyleScale(domain: classStyleDomain, range: classStyleRange)
                    .chartLegend(.hidden)
                    .chartYAxisLabel("Hours")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: daysBack > 30 ? 14 : 2)) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    updateBarHover(
                                        phase,
                                        proxy: proxy,
                                        geometry: geometry,
                                        totals: totals,
                                        classTotals: classTotals
                                    )
                                }
                        }
                    }

                    if let hoverTooltip {
                        HoverTooltip(tooltip: hoverTooltip)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func updateBarHover(
        _ phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        totals: [DailyTotal],
        classTotals: [DailyClassTotal]
    ) {
        switch phase {
        case .active(let location):
            guard let plotFrameAnchor = proxy.plotFrame else {
                hoverTooltip = nil
                return
            }
            let plotFrame = geometry[plotFrameAnchor]
            guard plotFrame.contains(location) else {
                hoverTooltip = nil
                return
            }

            let plotLocation = CGPoint(x: location.x - plotFrame.origin.x, y: location.y - plotFrame.origin.y)
            guard let hoveredDate = proxy.value(atX: plotLocation.x, as: Date.self) else {
                hoverTooltip = nil
                return
            }

            let hoveredDay = Calendar.current.startOfDay(for: hoveredDate)
            guard let hoveredTotal = totals.first(where: { Calendar.current.isDate($0.date, inSameDayAs: hoveredDay) }),
                  hoveredTotal.seconds > 0 else {
                hoverTooltip = nil
                return
            }

            if classID == nil,
               let hoveredHours = proxy.value(atY: plotLocation.y, as: Double.self),
               let classTotal = hoveredClassSegment(
                   on: hoveredDay,
                   atHours: hoveredHours,
                   totals: classTotals
               ) {
                hoverTooltip = ChartHoverTooltip(
                    title: classTotal.studyClass.name,
                    value: classTotal.seconds.hhMMDuration,
                    location: location
                )
                return
            }

            hoverTooltip = ChartHoverTooltip(
                title: hoveredTotal.date.formatted(date: .abbreviated, time: .omitted),
                value: hoveredTotal.seconds.hhMMDuration,
                location: location
            )
        case .ended:
            hoverTooltip = nil
        }
    }
}

private func hoveredClassSegment(
    on day: Date,
    atHours hours: Double,
    totals: [DailyClassTotal]
) -> DailyClassTotal? {
    guard hours >= 0 else { return nil }
    let dayTotals = totals.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    var cumulativeHours = 0.0

    for total in dayTotals {
        cumulativeHours += total.seconds.hours
        if hours <= cumulativeHours {
            return total
        }
    }

    return nil
}

private struct ClassDonutChart: View {
    @EnvironmentObject private var store: StudyStore
    @State private var hoverTooltip: ChartHoverTooltip?
    let size: DashboardCardSize

    var body: some View {
        let totals = store.classTotals()

        Group {
            if size == .medium {
                HStack(spacing: 10) {
                    chartHeading(totals: totals)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    donutContent(totals: totals)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: size == .small ? 6 : 12) {
                    chartHeading(totals: totals)
                    donutContent(totals: totals)
                }
            }
        }
        .padding(size == .small ? 10 : 12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func chartHeading(totals: [ClassTotal]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(size == .small ? "Time by Class" : "Total Time by Class")
                .font(size == .small ? .callout.weight(.semibold) : .headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if size == .medium {
                Text(totals.reduce(0) { $0 + $1.seconds }.compactDuration)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func donutContent(totals: [ClassTotal]) -> some View {
        if totals.isEmpty {
            if size == .small || size == .medium {
                Label("No data", systemImage: "chart.pie")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyChartState(systemImage: "chart.pie", title: "No class totals yet")
            }
        } else {
            ZStack(alignment: .topLeading) {
                Chart(totals) { total in
                    SectorMark(
                        angle: .value("Hours", total.seconds.hours),
                        innerRadius: .ratio(0.58),
                        angularInset: 2
                    )
                    .foregroundStyle(Color(hex: total.studyClass.colorHex))
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .chartOverlay { _ in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                updateCircleHover(
                                    phase,
                                    geometry: geometry,
                                    totals: totals,
                                    innerRadiusRatio: 0.58
                                )
                            }
                    }
                }

                if let hoverTooltip {
                    HoverTooltip(tooltip: hoverTooltip)
                }
            }
        }
    }

    private func updateCircleHover(
        _ phase: HoverPhase,
        geometry: GeometryProxy,
        totals: [ClassTotal],
        innerRadiusRatio: CGFloat
    ) {
        switch phase {
        case .active(let location):
            guard let hovered = hoveredClassTotal(
                at: location,
                in: geometry.size,
                totals: totals,
                innerRadiusRatio: innerRadiusRatio
            ) else {
                hoverTooltip = nil
                return
            }

            hoverTooltip = ChartHoverTooltip(
                title: hovered.studyClass.name,
                value: hovered.seconds.hhMMDuration,
                location: location
            )
        case .ended:
            hoverTooltip = nil
        }
    }
}

private struct ClassOverviewChart: View {
    @EnvironmentObject private var store: StudyStore
    @State private var hoverTooltip: ChartHoverTooltip?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All Classes")
                .font(.headline)

            let totals = store.classTotals()
            if totals.isEmpty {
                EmptyChartState(systemImage: "circle.grid.cross", title: "No class time yet")
            } else {
                ZStack(alignment: .topLeading) {
                    Chart(totals) { total in
                        SectorMark(
                            angle: .value("Hours", total.seconds.hours),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color(hex: total.studyClass.colorHex))
                        .cornerRadius(3)
                    }
                    .chartLegend(.hidden)
                    .chartOverlay { _ in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    updateCircleHover(phase, geometry: geometry, totals: totals, innerRadiusRatio: 0.5)
                                }
                        }
                    }

                    if let hoverTooltip {
                        HoverTooltip(tooltip: hoverTooltip)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 6) {
                    ForEach(totals.map(\.studyClass)) { studyClass in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: studyClass.colorHex))
                                .frame(width: 8, height: 8)
                            Text(studyClass.name)
                                .lineLimit(1)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func updateCircleHover(
        _ phase: HoverPhase,
        geometry: GeometryProxy,
        totals: [ClassTotal],
        innerRadiusRatio: CGFloat
    ) {
        switch phase {
        case .active(let location):
            guard let hovered = hoveredClassTotal(
                at: location,
                in: geometry.size,
                totals: totals,
                innerRadiusRatio: innerRadiusRatio
            ) else {
                hoverTooltip = nil
                return
            }

            hoverTooltip = ChartHoverTooltip(
                title: hovered.studyClass.name,
                value: hovered.seconds.hhMMDuration,
                location: location
            )
        case .ended:
            hoverTooltip = nil
        }
    }
}

private struct ClassLeaderboard: View {
    @EnvironmentObject private var store: StudyStore
    let size: DashboardCardSize

    private var maximumRows: Int? {
        switch size {
        case .small: 2
        case .medium: 3
        case .large, .wide, .extraLarge: nil
        }
    }

    var body: some View {
        let totals = store.classTotals()
        let visibleTotals = maximumRows.map { Array(totals.prefix($0)) } ?? totals

        VStack(alignment: .leading, spacing: size == .small ? 5 : 8) {
            Text("Leaderboard")
                .font(size == .small ? .callout.weight(.semibold) : .headline)

            if totals.isEmpty {
                if size == .small || size == .medium {
                    Label("No rankings", systemImage: "list.number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyChartState(systemImage: "list.number", title: "No ranked classes yet")
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visibleTotals.enumerated()), id: \.element.id) { index, total in
                        HStack(spacing: size == .small ? 5 : 8) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: size == .small ? 12 : 18, alignment: .leading)

                            Circle()
                                .fill(Color(hex: total.studyClass.colorHex))
                                .frame(width: 8, height: 8)

                            Text(total.studyClass.name)
                                .lineLimit(1)

                            Spacer()

                            Text(total.seconds.compactDuration)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .font(size == .small ? .caption : .callout)
                        .padding(.vertical, size == .small ? 4 : 5)

                        if total.id != visibleTotals.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(size == .small ? 10 : 12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ChartHoverTooltip {
    let title: String
    let value: String
    let location: CGPoint
}

private struct HoverTooltip: View {
    let tooltip: ChartHoverTooltip

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tooltip.title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Text(tooltip.value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(AppTheme.separator.opacity(0.8), lineWidth: 0.5)
        )
        .offset(x: tooltip.location.x + 12, y: max(0, tooltip.location.y - 42))
        .allowsHitTesting(false)
    }
}

private func hoveredClassTotal(
    at location: CGPoint,
    in size: CGSize,
    totals: [ClassTotal],
    innerRadiusRatio: CGFloat
) -> ClassTotal? {
    let diameter = min(size.width, size.height)
    guard diameter > 0 else { return nil }

    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let dx = location.x - center.x
    let dy = location.y - center.y
    let distance = sqrt(dx * dx + dy * dy)
    let outerRadius = diameter / 2

    guard distance >= outerRadius * innerRadiusRatio, distance <= outerRadius else {
        return nil
    }

    let totalSeconds = totals.reduce(0) { $0 + $1.seconds }
    guard totalSeconds > 0 else { return nil }

    var angle = atan2(dy, dx) + (.pi / 2)
    if angle < 0 {
        angle += 2 * .pi
    }

    let target = (angle / (2 * .pi)) * totalSeconds
    var cumulative: TimeInterval = 0

    for total in totals {
        cumulative += total.seconds
        if target <= cumulative {
            return total
        }
    }

    return totals.last
}

private struct EmptyChartState: View {
    let systemImage: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 170)
    }
}
