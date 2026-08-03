import SwiftUI

struct CoursePlanningSummary: View {
    let studyClass: StudyClass

    var body: some View {
        HStack(spacing: 8) {
            Label(studyClass.status.title, systemImage: studyClass.status.systemImage)
                .foregroundStyle(studyClass.status.color)

            if let code = studyClass.courseCode {
                Text(code)
                    .foregroundStyle(.secondary)
            }

            if let priority = studyClass.priority {
                Text(priority.title)
                    .foregroundStyle(priority.color)
            }

            Text("\(Int(studyClass.progressPercentage.rounded()))%")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.caption)
        .lineLimit(1)
    }
}

struct CoursePlanningEditor: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    private let original: StudyClass

    @State private var name: String
    @State private var color: Color
    @State private var courseCode: String
    @State private var creditValue: String
    @State private var hasStartDate: Bool
    @State private var startDate: Date
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var plannedStudyHours: String
    @State private var status: CourseStatus
    @State private var hasCompletionDate: Bool
    @State private var completionDate: Date
    @State private var progressPercentage: Double
    @State private var weeklyStudyHoursTarget: String
    @State private var priority: CoursePriority?

    init(studyClass: StudyClass) {
        original = studyClass
        _name = State(initialValue: studyClass.name)
        _color = State(initialValue: Color(hex: studyClass.colorHex))
        _courseCode = State(initialValue: studyClass.courseCode ?? "")
        _creditValue = State(initialValue: Self.numberText(studyClass.creditValue))
        _hasStartDate = State(initialValue: studyClass.startDate != nil)
        _startDate = State(initialValue: studyClass.startDate ?? Date())
        _hasTargetDate = State(initialValue: studyClass.targetCompletionDate != nil)
        _targetDate = State(
            initialValue: studyClass.targetCompletionDate
                ?? Calendar.current.date(byAdding: .month, value: 4, to: Date())
                ?? Date()
        )
        _plannedStudyHours = State(initialValue: Self.numberText(studyClass.plannedStudyHours))
        _status = State(initialValue: studyClass.status)
        _hasCompletionDate = State(initialValue: studyClass.completionDate != nil)
        _completionDate = State(initialValue: studyClass.completionDate ?? Date())
        _progressPercentage = State(initialValue: studyClass.progressPercentage)
        _weeklyStudyHoursTarget = State(initialValue: Self.numberText(studyClass.weeklyStudyHoursTarget))
        _priority = State(initialValue: studyClass.priority)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit Course")
                .font(.title2.weight(.semibold))
                .padding([.horizontal, .top], 22)
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    identitySection
                    scheduleSection
                    progressSection
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasInvalidNumber)
            }
            .padding(16)
        }
        .frame(width: 500)
        .frame(minHeight: 580, maxHeight: 720)
        .onChange(of: startDate) { _, newStart in
            if targetDate < newStart {
                targetDate = newStart
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus == .completed, !hasCompletionDate {
                hasCompletionDate = true
                completionDate = Date()
            }
        }
    }

    private var identitySection: some View {
        planningSection("Course") {
            TextField("Course Name", text: $name)

            HStack {
                TextField("Course Code (optional)", text: $courseCode)
                ColorPicker("Color", selection: $color)
                    .frame(width: 110)
            }

            HStack {
                TextField("Credits (optional)", text: $creditValue)
                    .textFieldStyle(.roundedBorder)
                Picker("Priority", selection: $priority) {
                    Text("No priority").tag(CoursePriority?.none)
                    ForEach(CoursePriority.allCases) { priority in
                        Text(priority.title).tag(Optional(priority))
                    }
                }
            }
        }
    }

    private var scheduleSection: some View {
        planningSection("Plan") {
            optionalDateRow("Start Date", isEnabled: $hasStartDate, date: $startDate)
            optionalDateRow(
                "Target Completion",
                isEnabled: $hasTargetDate,
                date: $targetDate,
                range: hasStartDate ? startDate...Date.distantFuture : nil
            )

            HStack {
                TextField("Planned Total Hours", text: $plannedStudyHours)
                TextField("Weekly Target Hours", text: $weeklyStudyHoursTarget)
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    private var progressSection: some View {
        planningSection("Progress") {
            Picker("Status", selection: $status) {
                ForEach(CourseStatus.allCases) { status in
                    Label(status.title, systemImage: status.systemImage).tag(status)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text("\(Int(progressPercentage.rounded()))%")
                        .monospacedDigit()
                }
                Slider(value: $progressPercentage, in: 0...100, step: 1)
            }

            optionalDateRow(
                "Completion Date",
                isEnabled: $hasCompletionDate,
                date: $completionDate
            )
        }
    }

    private func planningSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .appPanel()
    }

    private func optionalDateRow(
        _ title: String,
        isEnabled: Binding<Bool>,
        date: Binding<Date>,
        range: ClosedRange<Date>? = nil
    ) -> some View {
        HStack {
            Toggle(title, isOn: isEnabled)
            Spacer()
            if isEnabled.wrappedValue {
                if let range {
                    DatePicker("", selection: date, in: range, displayedComponents: .date)
                        .labelsHidden()
                } else {
                    DatePicker("", selection: date, displayedComponents: .date)
                        .labelsHidden()
                }
            }
        }
    }

    private var hasInvalidNumber: Bool {
        [creditValue, plannedStudyHours, weeklyStudyHoursTarget].contains { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard let number = Double(trimmed) else { return true }
            return !number.isFinite || number < 0
        }
    }

    private func save() {
        guard let index = store.data.classes.firstIndex(where: { $0.id == original.id }) else {
            dismiss()
            return
        }

        store.data.classes[index] = StudyClass(
            id: original.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            colorHex: color.hexString() ?? original.colorHex,
            courseCode: courseCode,
            creditValue: parsedNumber(creditValue),
            startDate: hasStartDate ? startDate : nil,
            targetCompletionDate: hasTargetDate ? targetDate : nil,
            plannedStudyHours: parsedNumber(plannedStudyHours),
            status: status,
            completionDate: hasCompletionDate ? completionDate : nil,
            progressPercentage: progressPercentage,
            weeklyStudyHoursTarget: parsedNumber(weeklyStudyHoursTarget),
            priority: priority,
            isArchived: original.isArchived,
            archivedAt: original.archivedAt
        )
        dismiss()
    }

    private func parsedNumber(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private static func numberText(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

extension CourseStatus {
    var title: String {
        switch self {
        case .notStarted: "Not Started"
        case .active: "Active"
        case .paused: "Paused"
        case .completed: "Completed"
        }
    }

    var systemImage: String {
        switch self {
        case .notStarted: "circle"
        case .active: "play.circle"
        case .paused: "pause.circle"
        case .completed: "checkmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .notStarted: .secondary
        case .active: .green
        case .paused: .orange
        case .completed: .blue
        }
    }
}

extension CoursePriority {
    var title: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    var color: Color {
        switch self {
        case .low: .secondary
        case .normal: .blue
        case .high: .orange
        case .critical: .red
        }
    }
}
