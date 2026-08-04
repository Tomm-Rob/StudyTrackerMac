import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var isAddingGoal = false
    @State private var editingGoal: StudyGoal?

    private var activeGoals: [StudyGoal] {
        store.activeGoals.sorted(by: goalSort)
    }

    private var archivedGoals: [StudyGoal] {
        store.data.goals.filter(\.isArchived).sorted(by: goalSort)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if activeGoals.isEmpty {
                    ContentUnavailableView(
                        "No active goals",
                        systemImage: "target",
                        description: Text("Add a daily, weekly, or class goal to begin tracking progress.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .appPanel()
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 290, maximum: 430), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(activeGoals) { goal in
                            GoalDetailCard(
                                goal: goal,
                                edit: { editingGoal = goal },
                                archive: { store.archiveGoal(id: goal.id) }
                            )
                        }
                    }
                }

                if !archivedGoals.isEmpty {
                    archivedSection
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $isAddingGoal) {
            GoalEditorSheet()
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorSheet(goal: goal)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                titleBlock
                Spacer()
                addButton
            }

            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                addButton
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Goals")
                .font(.system(size: 26, weight: .semibold, design: .default))
            Text("Track current progress and class pacing.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var addButton: some View {
        Button {
            isAddingGoal = true
        } label: {
            Label("Add Goal", systemImage: "plus")
        }
        .appButtonStyle(.prominent)
    }

    private var archivedSection: some View {
        DisclosureGroup("Archived Goals (\(archivedGoals.count))") {
            VStack(spacing: 0) {
                ForEach(archivedGoals) { goal in
                    HStack(spacing: 10) {
                        Image(systemName: goal.kind.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(goalTitle(goal))
                            .lineLimit(1)
                        Spacer()
                        Button("Restore") {
                            var restored = goal
                            restored.isArchived = false
                            store.updateGoal(restored)
                        }
                    }
                    .padding(.vertical, 7)

                    if goal.id != archivedGoals.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.top, 6)
        }
        .padding(12)
        .appPanel()
    }

    private func goalSort(_ lhs: StudyGoal, _ rhs: StudyGoal) -> Bool {
        if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
        return lhs.startDate > rhs.startDate
    }

    private func goalTitle(_ goal: StudyGoal) -> String {
        if goal.kind == .course, let courseID = goal.courseID {
            return store.className(for: courseID)
        }
        return goal.kind.title + " Goal"
    }
}

struct GoalsSection: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID?
    var maximumVisible = 4
    var compact = false

    @State private var isAddingGoal = false
    @State private var editingGoal: StudyGoal?

    private let service = GoalProgressService()

    private var goals: [StudyGoal] {
        store.activeGoals
            .filter { classID == nil || ($0.kind == .course && $0.courseID == classID) }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack {
                Label(classID == nil ? "Goals" : "Class Goals", systemImage: "target")
                    .font(.headline)
                Spacer()
                Button {
                    isAddingGoal = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add goal")
            }

            if goals.isEmpty {
                if compact {
                    Label("No active goals", systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(classID == nil ? "No active goals" : "No goals for this class")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(goals.prefix(maximumVisible))) { goal in
                        compactRow(goal)
                        if goal.id != goals.prefix(maximumVisible).last?.id {
                            Divider()
                        }
                    }
                }

                if !compact && goals.count > maximumVisible {
                    Text("\(goals.count - maximumVisible) more goal\(goals.count - maximumVisible == 1 ? "" : "s") on the Goals page")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(compact ? 10 : 12)
        .appPanel()
        .sheet(isPresented: $isAddingGoal) {
            GoalEditorSheet(presetCourseID: classID)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditorSheet(goal: goal)
        }
    }

    private func compactRow(_ goal: StudyGoal) -> some View {
        let progress = service.progress(for: goal, sessions: store.data.sessions)

        return Button {
            editingGoal = goal
        } label: {
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                HStack {
                    Label(goalName(goal), systemImage: goal.kind.systemImage)
                        .lineLimit(1)
                    Spacer()
                    Text(goalStatus(goal, progress: progress))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor(goal, progress: progress))
                }

                ProgressView(value: progress.completionFraction)
                    .tint(statusColor(goal, progress: progress))

                HStack {
                    Text(progress.studiedDuration.compactDuration)
                    Spacer()
                    Text(progress.targetDuration.compactDuration)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 7)
    }

    private func goalName(_ goal: StudyGoal) -> String {
        if goal.kind == .course, let courseID = goal.courseID {
            return store.className(for: courseID)
        }
        return goal.kind.title
    }

    private func goalStatus(_ goal: StudyGoal, progress: GoalProgress) -> String {
        if progress.isComplete { return "Complete" }
        if progress.isOverdue { return "Overdue" }
        if goal.kind == .course,
           let pacing = service.coursePacing(for: goal, sessions: store.data.sessions) {
            return pacing.status.title
        }
        return "\(Int((progress.completionFraction * 100).rounded()))%"
    }

    private func statusColor(_ goal: StudyGoal, progress: GoalProgress) -> Color {
        if progress.isComplete { return .green }
        if progress.isOverdue { return .red }
        if goal.kind == .course,
           let pacing = service.coursePacing(for: goal, sessions: store.data.sessions),
           [.behind, .noRecentData].contains(pacing.status) {
            return .orange
        }
        return .accentColor
    }
}

private struct GoalDetailCard: View {
    @EnvironmentObject private var store: StudyStore
    let goal: StudyGoal
    let edit: () -> Void
    let archive: () -> Void

    private let service = GoalProgressService()

    private var progress: GoalProgress {
        service.progress(for: goal, sessions: store.data.sessions)
    }

    private var pacing: CoursePacing? {
        service.coursePacing(for: goal, sessions: store.data.sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(title, systemImage: goal.kind.systemImage)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Edit", systemImage: "pencil", action: edit)
                    Button("Archive", systemImage: "archivebox", action: archive)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            HStack(alignment: .firstTextBaseline) {
                Text(progress.studiedDuration.compactDuration)
                    .font(.system(size: 23, weight: .semibold, design: .default))
                    .monospacedDigit()
                Text("of \(progress.targetDuration.compactDuration)")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(statusText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(statusColor)
            }

            ProgressView(value: progress.completionFraction)
                .tint(statusColor)

            if let pacing, goal.kind == .course {
                Divider()
                pacingDetails(pacing)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .appPanel()
    }

    private var title: String {
        if goal.kind == .course, let courseID = goal.courseID {
            return store.className(for: courseID)
        }
        return goal.kind.title + " Goal"
    }

    private var subtitle: String {
        switch goal.kind {
        case .daily: "Resets each day"
        case .weekly: "Resets each week"
        case .course:
            if let targetDate = goal.targetDate {
                "Target \(targetDate.formatted(date: .abbreviated, time: .omitted))"
            } else {
                "No target date"
            }
        }
    }

    private var statusText: String {
        if progress.isComplete { return "Complete" }
        if progress.isOverdue { return "Overdue" }
        return pacing?.status.title ?? "\(Int((progress.completionFraction * 100).rounded()))%"
    }

    private var statusColor: Color {
        if progress.isComplete { return .green }
        if progress.isOverdue { return .red }
        if let pacing, [.behind, .noRecentData].contains(pacing.status) { return .orange }
        return .accentColor
    }

    private func pacingDetails(_ pacing: CoursePacing) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Needed per day")
                Spacer()
                Text(pacing.requiredDailyDuration.compactDuration)
            }
            HStack {
                Text("Recent daily pace")
                Spacer()
                Text(pacing.recentDailyDuration.compactDuration)
            }
            if let projectedDate = pacing.projectedCompletionDate {
                HStack {
                    Text("Projected finish")
                    Spacer()
                    Text(projectedDate.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

struct GoalEditorSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    private let existingGoal: StudyGoal?
    private let lockedCourseID: UUID?

    @State private var kind: StudyGoalKind
    @State private var courseID: UUID?
    @State private var hours: Int
    @State private var minutes: Int
    @State private var startDate: Date
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date

    init(goal: StudyGoal? = nil, presetCourseID: UUID? = nil) {
        existingGoal = goal
        lockedCourseID = presetCourseID
        let initialKind = presetCourseID == nil ? (goal?.kind ?? .weekly) : .course
        let totalMinutes = Int((goal?.targetDuration ?? 3_600) / 60)
        _kind = State(initialValue: initialKind)
        _courseID = State(initialValue: presetCourseID ?? goal?.courseID)
        _hours = State(initialValue: totalMinutes / 60)
        _minutes = State(initialValue: totalMinutes % 60)
        _startDate = State(initialValue: goal?.startDate ?? Date())
        _hasTargetDate = State(initialValue: goal?.targetDate != nil)
        _targetDate = State(
            initialValue: goal?.targetDate
                ?? Calendar.current.date(byAdding: .weekOfYear, value: 4, to: Date())
                ?? Date()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existingGoal == nil ? "Add Goal" : "Edit Goal")
                .font(.title2.weight(.semibold))

            if lockedCourseID == nil {
                Picker("Type", selection: $kind) {
                    ForEach(StudyGoalKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            if kind == .course {
                Picker("Class", selection: $courseID) {
                    Text("Choose a class").tag(UUID?.none)
                    ForEach(selectableClasses) { studyClass in
                        Text(studyClass.name).tag(Optional(studyClass.id))
                    }
                }
                .disabled(lockedCourseID != nil)
            }

            DatePicker("Starts", selection: $startDate, displayedComponents: .date)

            HStack(spacing: 12) {
                Stepper(value: $hours, in: 0...500) {
                    LabeledValue(title: "Target Hours", value: "\(hours)")
                }
                Stepper(value: $minutes, in: 0...59, step: 5) {
                    LabeledValue(title: "Minutes", value: "\(minutes)")
                }
            }

            if kind == .course {
                Toggle("Set a target date", isOn: $hasTargetDate)
                if hasTargetDate {
                    DatePicker(
                        "Target Date",
                        selection: $targetDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button(existingGoal == nil ? "Add Goal" : "Save") {
                    save()
                }
                .appButtonStyle(.prominent)
                .disabled(!canSave)
            }
        }
        .padding(22)
        .frame(width: 440)
        .onChange(of: kind) { _, newKind in
            if newKind != .course {
                courseID = nil
                hasTargetDate = false
            } else if courseID == nil {
                courseID = store.activeClasses.first?.id
            }
        }
        .onChange(of: startDate) { _, newStartDate in
            if targetDate < newStartDate {
                targetDate = newStartDate
            }
        }
        .onAppear {
            if kind == .course, courseID == nil {
                courseID = store.activeClasses.first?.id
            }
        }
    }

    private var selectableClasses: [StudyClass] {
        if let existingGoal,
           let currentID = existingGoal.courseID,
           let currentClass = store.data.classes.first(where: { $0.id == currentID && $0.isArchived }) {
            return [currentClass] + store.activeClasses
        }
        return store.activeClasses
    }

    private var canSave: Bool {
        let durationMinutes = hours * 60 + minutes
        return durationMinutes > 0 && (kind != .course || courseID != nil)
    }

    private func save() {
        let goal = StudyGoal(
            id: existingGoal?.id ?? UUID(),
            kind: kind,
            targetDuration: TimeInterval((hours * 60 + minutes) * 60),
            courseID: kind == .course ? courseID : nil,
            startDate: startDate,
            targetDate: kind == .course && hasTargetDate ? targetDate : nil,
            isArchived: existingGoal?.isArchived ?? false
        )

        if existingGoal == nil {
            store.addGoal(goal)
        } else {
            store.updateGoal(goal)
        }
        dismiss()
    }
}

private extension StudyGoalKind {
    static var allCases: [StudyGoalKind] { [.daily, .weekly, .course] }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .course: "Class"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "sun.max"
        case .weekly: "calendar"
        case .course: "book.closed"
        }
    }

    var sortOrder: Int {
        switch self {
        case .daily: 0
        case .weekly: 1
        case .course: 2
        }
    }
}

private extension CoursePacingStatus {
    var title: String {
        switch self {
        case .complete: "Complete"
        case .onTrack: "On Track"
        case .behind: "Behind"
        case .overdue: "Overdue"
        case .noRecentData: "Needs Study Time"
        case .noTargetDate: "In Progress"
        case .invalidCourse: "Class Missing"
        }
    }
}
