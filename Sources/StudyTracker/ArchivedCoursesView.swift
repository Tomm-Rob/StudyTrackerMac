import SwiftUI

struct ArchivedCoursesView: View {
    @EnvironmentObject private var store: StudyStore

    private var archivedCourses: [StudyClass] {
        store.data.classes
            .filter(\.isArchived)
            .sorted { left, right in
                let leftDate = left.archivedAt ?? .distantPast
                let rightDate = right.archivedAt ?? .distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if archivedCourses.isEmpty {
                    ContentUnavailableView(
                        "No archived courses",
                        systemImage: "archivebox",
                        description: Text("Courses you archive will remain available here with their study history.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 290, maximum: 430), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(archivedCourses) { studyClass in
                            archivedCourseCard(studyClass)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Archived Courses")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("View archived course details or restore a course with all of its history.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func archivedCourseCard(_ studyClass: StudyClass) -> some View {
        let sessions = store.sessions(for: studyClass.id)
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                Circle()
                    .fill(Color(hex: studyClass.colorHex))
                    .frame(width: 12, height: 12)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 3) {
                    Text(studyClass.name)
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        if let code = studyClass.courseCode {
                            Text(code)
                        }
                        Text(studyClass.status.title)
                        if let priority = studyClass.priority {
                            Text(priority.title)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.restoreClass(id: studyClass.id)
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.activeClasses.count >= StudyStore.maxClasses)
                .help(
                    store.activeClasses.count >= StudyStore.maxClasses
                        ? "Archive another course before restoring this one"
                        : "Restore course"
                )
            }

            Divider()

            HStack(spacing: 20) {
                value("Study Time", totalDuration.compactDuration)
                value("Sessions", "\(sessions.count)")
                value("Progress", "\(Int(studyClass.progressPercentage.rounded()))%")
                Spacer()
            }

            if let archivedAt = studyClass.archivedAt {
                Text("Archived \(archivedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8))
    }

    private func value(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
        }
    }
}
