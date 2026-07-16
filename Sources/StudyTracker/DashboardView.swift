import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID?

    @State private var daysBack = 14
    @State private var editingSession: StudySession?
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
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                LazyVGrid(columns: dashboardColumns, alignment: .leading, spacing: 10) {
                    MetricTile(title: "Total Study Time", value: totalSeconds.compactDuration, systemImage: "clock")
                    MetricTile(title: "Sessions", value: "\(sessionCount)", systemImage: "list.bullet.rectangle")

                    if classID == nil {
                        MetricTile(title: "Classes", value: "\(store.data.classes.count)", systemImage: "books.vertical")
                    } else {
                        MetricTile(title: "Average Session", value: averageSessionDuration.compactDuration, systemImage: "chart.line.uptrend.xyaxis")
                    }
                }

                StudySessionTimer(classID: classID)

                if classID == nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            DailyBarChart(classID: classID, daysBack: daysBack)
                                .frame(minWidth: 340, maxWidth: .infinity, minHeight: 250)

                            ClassDonutChart()
                                .frame(minWidth: 260, maxWidth: 360, minHeight: 250)
                        }

                        VStack(spacing: 12) {
                            DailyBarChart(classID: classID, daysBack: daysBack)
                                .frame(minHeight: 240)

                            ClassDonutChart()
                                .frame(minHeight: 240)
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ClassOverviewChart()
                                .frame(minWidth: 300, maxWidth: .infinity, minHeight: 250)

                            ClassLeaderboard()
                                .frame(minWidth: 260, maxWidth: 360, minHeight: 250)
                        }

                        VStack(spacing: 12) {
                            ClassOverviewChart()
                                .frame(minHeight: 240)

                            ClassLeaderboard()
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        DailyBarChart(classID: classID, daysBack: daysBack)
                            .frame(minHeight: 250)
                    }
                }

                SessionEditor(classID: classID)

                SessionList(classID: classID, editingSession: $editingSession)
            }
            .padding(16)
        }
        .sheet(item: $editingSession) { session in
            SessionEditSheet(session: session)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center) {
                titleBlock
                Spacer()
                rangePicker
            }

            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                rangePicker
                    .frame(maxWidth: 310)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("Log time, review daily progress, and keep class totals in view.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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

    private var index: Int? {
        store.data.classes.firstIndex(where: { $0.id == classID })
    }

    var body: some View {
        if let index {
            HStack(spacing: 14) {
                TextField("Class Name", text: $store.data.classes[index].name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                ColorPicker(
                    "Class color",
                    selection: Binding(
                        get: { Color(hex: store.data.classes[index].colorHex) },
                        set: { store.data.classes[index].colorHex = $0.hexString() ?? store.data.classes[index].colorHex }
                    )
                )
                .labelsHidden()

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .confirmationDialog("Delete this class and all of its sessions?", isPresented: $confirmDelete) {
                Button("Delete Class", role: .destructive) {
                    store.deleteClass(id: classID)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Study Time")
                .font(.headline)

            if store.data.sessions.isEmpty {
                EmptyChartState(systemImage: "chart.bar", title: "No study time logged yet")
            } else {
                let totals = store.dailyTotals(for: classID, daysBack: daysBack)
                ZStack(alignment: .topLeading) {
                    Chart(totals) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Hours", day.seconds.hours)
                        )
                        .foregroundStyle(barColor)
                        .cornerRadius(4)
                    }
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
                                    updateBarHover(phase, proxy: proxy, geometry: geometry, totals: totals)
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
        totals: [DailyTotal]
    ) {
        switch phase {
        case .active(let location):
            let plotFrame = geometry[proxy.plotAreaFrame]
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

private struct ClassDonutChart: View {
    @EnvironmentObject private var store: StudyStore
    @State private var hoverTooltip: ChartHoverTooltip?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Time by Class")
                .font(.headline)

            let totals = store.classTotals()
            if totals.isEmpty {
                EmptyChartState(systemImage: "chart.pie", title: "No class totals yet")
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
                                    updateCircleHover(phase, geometry: geometry, totals: totals, innerRadiusRatio: 0.58)
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
                    ForEach(store.data.classes) { studyClass in
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Leaderboard")
                .font(.headline)

            let totals = store.classTotals()
            if totals.isEmpty {
                EmptyChartState(systemImage: "list.number", title: "No ranked classes yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(totals.enumerated()), id: \.element.id) { index, total in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .leading)

                            Circle()
                                .fill(Color(hex: total.studyClass.colorHex))
                                .frame(width: 9, height: 9)

                            Text(total.studyClass.name)
                                .lineLimit(1)

                            Spacer()

                            Text(total.seconds.compactDuration)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .font(.callout)
                        .padding(.vertical, 7)

                        if total.id != totals.last?.id {
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
