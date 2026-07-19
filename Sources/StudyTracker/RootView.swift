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
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
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
            .buttonStyle(.borderedProminent)
            .disabled(store.isPersistenceLocked || store.activeClasses.count >= StudyStore.maxClasses)
            .padding([.horizontal, .bottom], 12)
        }
        .background(.thinMaterial)
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
        if colorScheme == .dark {
            return Color(nsColor: .windowBackgroundColor)
        }
        return Color(red: 246 / 255, green: 247 / 255, blue: 244 / 255)
    }

    static let panel = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
}
