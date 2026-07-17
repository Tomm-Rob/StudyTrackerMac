import SwiftUI

struct StudySessionTimer: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID?

    @State private var selectedClassID: UUID?
    @State private var elapsedSeconds = 0
    @State private var isRunning = false
    @State private var sessionStartedAt: Date?
    @State private var focusRating: Int?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var effectiveClassID: UUID? {
        if let classID {
            return store.activeClasses.contains(where: { $0.id == classID }) ? classID : nil
        }

        if let selectedClassID,
           store.activeClasses.contains(where: { $0.id == selectedClassID }) {
            return selectedClassID
        }

        return store.activeClasses.first?.id
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                timerHeader
                Spacer(minLength: 8)
                classPicker
                FocusRatingControl(rating: $focusRating)
                timerControls
            }

            VStack(alignment: .leading, spacing: 12) {
                timerHeader
                HStack(spacing: 12) {
                    classPicker
                    FocusRatingControl(rating: $focusRating)
                    Spacer()
                    timerControls
                }
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            selectedClassID = effectiveClassID
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            elapsedSeconds += 1
        }
        .onChange(of: store.activeClasses.map(\.id)) { _, _ in
            if classID == nil {
                selectedClassID = effectiveClassID
            }
        }
    }

    private var timerHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: isRunning ? "stopwatch.fill" : "stopwatch")
                .font(.system(size: 24))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Study Timer")
                    .font(.headline)
                Text(TimeInterval(elapsedSeconds).timerDuration)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var classPicker: some View {
        if classID == nil {
            Picker("Class", selection: Binding(
                get: { effectiveClassID },
                set: { selectedClassID = $0 }
            )) {
                ForEach(store.activeClasses) { studyClass in
                    Text(studyClass.name).tag(Optional(studyClass.id))
                }
            }
            .frame(width: 190)
        }
    }

    private var timerControls: some View {
        HStack(spacing: 8) {
            Button {
                toggleTimer()
            } label: {
                Label(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill")
                    .frame(width: 82)
            }
            .buttonStyle(.borderedProminent)
            .disabled(effectiveClassID == nil)

            Button {
                resetTimer()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("Reset timer")
            .disabled(elapsedSeconds == 0)

            Button {
                logTimer()
            } label: {
                Label("Log", systemImage: "checkmark.circle")
                    .frame(width: 72)
            }
            .disabled(effectiveClassID == nil || elapsedSeconds == 0)
        }
    }

    private func toggleTimer() {
        guard effectiveClassID != nil else { return }

        if sessionStartedAt == nil {
            sessionStartedAt = Date()
        }

        isRunning.toggle()
    }

    private func resetTimer() {
        isRunning = false
        elapsedSeconds = 0
        sessionStartedAt = nil
        focusRating = nil
    }

    private func logTimer() {
        guard let effectiveClassID, elapsedSeconds > 0 else { return }
        store.addSession(
            classID: effectiveClassID,
            startedAt: sessionStartedAt ?? Date(),
            duration: TimeInterval(elapsedSeconds),
            source: .timer,
            focusRating: focusRating
        )
        resetTimer()
    }
}

struct SessionEditor: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID?

    @State private var selectedClassID: UUID?
    @State private var date = Date()
    @State private var hours = 1
    @State private var minutes = 0
    @State private var focusRating: Int?

    private var effectiveClassID: UUID? {
        if let classID {
            return store.activeClasses.contains(where: { $0.id == classID }) ? classID : nil
        }

        if let selectedClassID,
           store.activeClasses.contains(where: { $0.id == selectedClassID }) {
            return selectedClassID
        }

        return store.activeClasses.first?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Study Session")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                horizontalEditorControls
                verticalEditorControls
            }

            if store.activeClasses.isEmpty {
                Text("Add a class first, then study sessions can be logged here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            selectedClassID = effectiveClassID
        }
        .onChange(of: store.activeClasses.map(\.id)) { _, _ in
            if classID == nil {
                selectedClassID = effectiveClassID
            }
        }
    }

    private var horizontalEditorControls: some View {
        HStack(alignment: .bottom, spacing: 10) {
            classControl
            dateControl
            durationControls
            FocusRatingControl(rating: $focusRating)
            Spacer(minLength: 0)
            addButton
        }
    }

    private var verticalEditorControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            classControl
            dateControl
            HStack(spacing: 10) {
                durationControls
                FocusRatingControl(rating: $focusRating)
                Spacer()
                addButton
            }
        }
    }

    @ViewBuilder
    private var classControl: some View {
        if classID == nil {
            VStack(alignment: .leading, spacing: 4) {
                Text("Class")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Class", selection: Binding(
                    get: { effectiveClassID },
                    set: { selectedClassID = $0 }
                )) {
                    ForEach(store.activeClasses) { studyClass in
                        Text(studyClass.name).tag(Optional(studyClass.id))
                    }
                }
                .frame(width: 190)
            }
        }
    }

    private var dateControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Date")
                .font(.caption)
                .foregroundStyle(.secondary)
            DatePicker("Date", selection: $date)
                .labelsHidden()
                .frame(width: 210)
        }
    }

    private var durationControls: some View {
        HStack(spacing: 10) {
            Stepper(value: $hours, in: 0...24) {
                LabeledValue(title: "Hours", value: "\(hours)")
            }
            .frame(width: 110)

            Stepper(value: $minutes, in: 0...59, step: 5) {
                LabeledValue(title: "Minutes", value: "\(minutes)")
            }
            .frame(width: 130)
        }
    }

    private var addButton: some View {
        Button {
            addSession()
        } label: {
            Label("Add", systemImage: "plus")
                .frame(width: 78)
        }
        .buttonStyle(.borderedProminent)
        .disabled(effectiveClassID == nil || (hours == 0 && minutes == 0))
    }

    private func addSession() {
        guard let effectiveClassID else { return }
        let duration = TimeInterval((hours * 60 + minutes) * 60)
        store.addSession(
            classID: effectiveClassID,
            startedAt: date,
            duration: duration,
            focusRating: focusRating
        )
        focusRating = nil
    }
}

struct SessionList: View {
    @EnvironmentObject private var store: StudyStore
    let classID: UUID?
    @Binding var editingSession: StudySession?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sessions")
                .font(.headline)

            let sessions = store.sessions(for: classID)
            if sessions.isEmpty {
                Text("No sessions to show yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(sessions) { session in
                        SessionRow(session: session, editingSession: $editingSession)
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

private struct SessionRow: View {
    @EnvironmentObject private var store: StudyStore
    let session: StudySession
    @Binding var editingSession: StudySession?
    @State private var confirmDelete = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: store.classColor(for: session.classID)))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.className(for: session.classID))
                    .font(.body.weight(.medium))
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(session.duration.compactDuration)
                .font(.body.weight(.medium))
                .monospacedDigit()

            if let focusRating = session.focusRating {
                Label("\(focusRating)/5", systemImage: "star.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                editingSession = session
            } label: {
                Image(systemName: "pencil")
            }
            .help("Edit session")

            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete session")
        }
        .padding(.vertical, 7)
        .confirmationDialog("Delete this study session?", isPresented: $confirmDelete) {
            Button("Delete Session", role: .destructive) {
                store.deleteSession(id: session.id)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct SessionEditSheet: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var session: StudySession
    @State private var hours: Int
    @State private var minutes: Int

    private var selectableClasses: [StudyClass] {
        guard let currentClass = store.data.classes.first(where: { $0.id == session.classID }),
              currentClass.isArchived else {
            return store.activeClasses
        }

        return [currentClass] + store.activeClasses
    }

    init(session: StudySession) {
        _session = State(initialValue: session)
        let totalMinutes = Int(session.duration / 60)
        _hours = State(initialValue: totalMinutes / 60)
        _minutes = State(initialValue: totalMinutes % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit Session")
                .font(.title2.weight(.semibold))

            Picker("Class", selection: $session.classID) {
                ForEach(selectableClasses) { studyClass in
                    Text(studyClass.name + (studyClass.isArchived ? " (Archived)" : "")).tag(studyClass.id)
                }
            }

            DatePicker("Started", selection: $session.startedAt)

            Stepper(value: $hours, in: 0...24) {
                LabeledValue(title: "Hours", value: "\(hours)")
            }

            Stepper(value: $minutes, in: 0...59, step: 5) {
                LabeledValue(title: "Minutes", value: "\(minutes)")
            }

            FocusRatingControl(rating: $session.focusRating)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    session.duration = TimeInterval((hours * 60 + minutes) * 60)
                    store.updateSession(session)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hours == 0 && minutes == 0)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

struct FocusRatingControl: View {
    @Binding var rating: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Focus")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Focus", selection: $rating) {
                Text("Not rated").tag(Int?.none)
                Divider()
                ForEach(1...5, id: \.self) { value in
                    Text("\(value) - \(label(for: value))").tag(Optional(value))
                }
            }
            .labelsHidden()
            .frame(width: 130)
        }
    }

    private func label(for value: Int) -> String {
        switch value {
        case 1: "Low"
        case 2: "Fair"
        case 3: "Good"
        case 4: "Strong"
        default: "Excellent"
        }
    }
}

struct LabeledValue: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
    }
}
