import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var selection: SidebarSelection = .dashboard

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 170, ideal: 220, max: 280)
        } detail: {
            DetailView(selection: selection)
        }
        .background(AppTheme.background)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var store: StudyStore
    @Binding var selection: SidebarSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Study Tracker")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                Text("\(store.data.classes.count)/\(StudyStore.maxClasses) classes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            List(selection: $selection) {
                Label("Dashboard", systemImage: "chart.bar.xaxis")
                    .tag(SidebarSelection.dashboard)

                Label("Pomodoro", systemImage: "timer")
                    .tag(SidebarSelection.pomodoro)

                Section("Classes") {
                    ForEach(store.data.classes) { studyClass in
                        HStack(spacing: 9) {
                            Circle()
                                .fill(Color(hex: studyClass.colorHex))
                                .frame(width: 10, height: 10)
                            Text(studyClass.name)
                                .lineLimit(1)
                        }
                        .tag(SidebarSelection.studyClass(studyClass.id))
                    }
                }

                Label("Settings", systemImage: "gearshape")
                    .tag(SidebarSelection.settings)
            }
            .listStyle(.sidebar)

            Button {
                store.addClass()
                if let lastClass = store.data.classes.last {
                    selection = .studyClass(lastClass.id)
                }
            } label: {
                Label("Add Class", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.data.classes.count >= StudyStore.maxClasses)
            .padding([.horizontal, .bottom], 12)
        }
        .background(.thinMaterial)
    }
}

private struct DetailView: View {
    @EnvironmentObject private var store: StudyStore
    let selection: SidebarSelection

    var body: some View {
        Group {
            switch selection {
            case .dashboard:
                DashboardView(classID: nil)
            case .pomodoro:
                PomodoroView()
            case .settings:
                SettingsView()
            case .studyClass(let id):
                if store.data.classes.contains(where: { $0.id == id }) {
                    ClassDetailView(classID: id)
                } else {
                    DashboardView(classID: nil)
                }
            }
        }
        .background(AppTheme.background)
    }
}

enum AppTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
}
