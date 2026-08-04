import AppKit
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: SidebarSelection = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        VStack(spacing: 0) {
            if store.isPersistenceLocked {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Study data could not be opened. The save file was left unchanged.")
                        .lineLimit(2)
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1))
            }

            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(selection: $selection)
                    .navigationSplitViewColumnWidth(min: 170, ideal: 220, max: 280)
            } detail: {
                DetailView(selection: selection)
                    .disabled(store.isPersistenceLocked && selection != .settings)
            }
        }
        .background(AppTheme.background(for: colorScheme))
        .tint(AppTheme.accent)
        .darkOutlineButtons()
        .onAppear {
            ApplicationIconManager.apply(for: colorScheme)
        }
        .onChange(of: colorScheme) { _, newValue in
            ApplicationIconManager.apply(for: newValue)
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: StudyStore
    @Binding var selection: SidebarSelection
    @AppStorage("Sidebar.ClassesExpanded") private var classesExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Study Tracker")
                    .font(.system(size: 21, weight: .semibold, design: .default))
                Text("\(store.activeClasses.count)/\(StudyStore.maxClasses) classes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            List(selection: $selection) {
                Label("Dashboard", systemImage: "chart.bar.xaxis")
                    .tag(SidebarSelection.dashboard)

                Label("Insights", systemImage: "chart.xyaxis.line")
                    .tag(SidebarSelection.insights)

                Label("Weekly Review", systemImage: "calendar.badge.clock")
                    .tag(SidebarSelection.weeklyReview)

                Label("Goals", systemImage: "target")
                    .tag(SidebarSelection.goals)

                Label("Pomodoro", systemImage: "timer")
                    .tag(SidebarSelection.pomodoro)

                Section(isExpanded: $classesExpanded) {
                    ForEach(Array(store.activeClasses.reversed())) { studyClass in
                        HStack(spacing: 9) {
                            Circle()
                                .fill(Color(hex: studyClass.colorHex))
                                .frame(width: 10, height: 10)
                            Text(studyClass.name)
                                .lineLimit(1)
                        }
                        .tag(SidebarSelection.studyClass(studyClass.id))
                    }
                } header: {
                    HStack {
                        Text("Classes")
                        Spacer()
                        Text("\(store.activeClasses.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Label("Archived Courses", systemImage: "archivebox")
                    Spacer()
                    Text("\(store.data.classes.filter(\.isArchived).count)")
                        .foregroundStyle(.secondary)
                }
                .tag(SidebarSelection.archivedCourses)

                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarSelection.settings)
            }
            .listStyle(.sidebar)

            Button {
                store.addClass()
                if let lastClass = store.activeClasses.last {
                    selection = .studyClass(lastClass.id)
                }
            } label: {
                Label("Add Class", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .appButtonStyle(.prominent)
            .disabled(store.isPersistenceLocked || store.activeClasses.count >= StudyStore.maxClasses)
            .padding([.horizontal, .bottom], 12)
        }
        .background(AppTheme.sidebar)
    }
}

private struct DetailView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.colorScheme) private var colorScheme
    let selection: SidebarSelection

    var body: some View {
        Group {
            switch selection {
            case .dashboard:
                DashboardView(classID: nil)
            case .insights:
                InsightsView()
            case .weeklyReview:
                WeeklyReviewView()
            case .goals:
                GoalsView()
            case .archivedCourses:
                ArchivedCoursesView()
            case .pomodoro:
                PomodoroView()
            case .settings:
                SettingsView()
            case .studyClass(let id):
                if store.activeClasses.contains(where: { $0.id == id }) {
                    ClassDetailView(classID: id)
                } else {
                    DashboardView(classID: nil)
                }
            }
        }
        .background(AppTheme.background(for: colorScheme))
    }
}

enum AppTheme {
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? color(0x151718) : color(0xF6F7F4)
    }

    static let panel = adaptive(light: 0xFFFFFF, dark: 0x202326)
    static let sidebar = adaptive(light: 0xF0F2F3, dark: 0x292D30)
    static let separator = adaptive(light: 0xDCE1E4, dark: 0x3A3E42)
    static let accent = adaptive(light: 0x2563EB, dark: 0x78D5A3)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(isDark ? dark : light)
        })
    }

    private static func color(_ hex: UInt32) -> Color {
        Color(nsColor: nsColor(hex))
    }

    private static func nsColor(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private struct DashboardCardContentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isDashboardCardContent: Bool {
        get { self[DashboardCardContentKey.self] }
        set { self[DashboardCardContentKey.self] = newValue }
    }
}

private struct AppPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isDashboardCardContent) private var isDashboardCardContent

    @ViewBuilder
    func body(content: Content) -> some View {
        if isDashboardCardContent {
            content
        } else {
            content.background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.panel)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AppTheme.separator, lineWidth: 0.75)
                    }
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.16 : 0.04),
                        radius: colorScheme == .dark ? 2 : 3,
                        y: 1
                    )
            }
        }
    }
}

extension View {
    func appPanel() -> some View {
        modifier(AppPanelModifier())
    }
}

enum AppButtonEmphasis {
    case standard
    case prominent
    case destructive
}

private struct AppAdaptiveButtonStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let emphasis: AppButtonEmphasis

    @ViewBuilder
    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.buttonStyle(AppDarkOutlineButtonStyle(emphasis: emphasis))
        } else {
            switch emphasis {
            case .prominent:
                content.buttonStyle(.borderedProminent)
            case .standard, .destructive:
                content.buttonStyle(.bordered)
            }
        }
    }
}

private struct AppDarkButtonEnvironmentModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.buttonStyle(AppDarkOutlineButtonStyle(emphasis: .standard))
        } else {
            content
        }
    }
}

private struct AppDarkOutlineButtonStyle: ButtonStyle {
    let emphasis: AppButtonEmphasis

    func makeBody(configuration: Configuration) -> some View {
        AppDarkOutlineButtonBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            emphasis: emphasis
        )
    }
}

private struct AppDarkOutlineButtonBody<Label: View>: View {
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    let label: Label
    let isPressed: Bool
    let emphasis: AppButtonEmphasis

    private var horizontalPadding: CGFloat {
        if controlSize == .mini { return 6 }
        if controlSize == .small { return 8 }
        if controlSize == .large { return 12 }
        return 10
    }

    private var verticalPadding: CGFloat {
        if controlSize == .mini { return 3 }
        if controlSize == .small { return 4 }
        if controlSize == .large { return 7 }
        return 5
    }

    private var borderColor: Color {
        guard isEnabled else { return AppTheme.separator }
        switch emphasis {
        case .prominent:
            return AppTheme.accent.opacity(isHovering ? 1 : 0.86)
        case .destructive:
            return .red.opacity(isHovering ? 1 : 0.78)
        case .standard:
            return isHovering ? AppTheme.accent.opacity(0.82) : AppTheme.separator
        }
    }

    private var foregroundColor: Color {
        guard isEnabled else { return .secondary }
        switch emphasis {
        case .prominent: return AppTheme.accent
        case .destructive: return .red
        case .standard: return .primary
        }
    }

    var body: some View {
        label
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.black.opacity(isPressed ? 0.34 : (isHovering ? 0.25 : 0.18)))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.easeOut(duration: 0.08), value: isPressed)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func appButtonStyle(_ emphasis: AppButtonEmphasis) -> some View {
        modifier(AppAdaptiveButtonStyleModifier(emphasis: emphasis))
    }

    func darkOutlineButtons() -> some View {
        modifier(AppDarkButtonEnvironmentModifier())
    }
}
