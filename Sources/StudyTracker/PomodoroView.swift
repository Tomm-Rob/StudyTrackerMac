import SwiftUI
import AppKit

struct PomodoroView: View {
    @EnvironmentObject private var store: StudyStore

    @AppStorage("Pomodoro.FocusMinutes") private var focusMinutes = 25
    @AppStorage("Pomodoro.ShortBreakMinutes") private var shortBreakMinutes = 5
    @AppStorage("Pomodoro.LongBreakMinutes") private var longBreakMinutes = 15

    @State private var mode: PomodoroMode = .focus
    @State private var remainingSeconds = 25 * 60
    @State private var isRunning = false
    @State private var completedFocusSessions = 0
    @State private var selectedClassID: UUID?
    @State private var elapsedFocusSeconds = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    timerPanel
                    settingsPanel
                }

                VStack(spacing: 12) {
                    timerPanel
                    settingsPanel
                }
            }

            Spacer()
        }
        .padding(16)
        .onAppear {
            selectedClassID = selectedClassID ?? store.data.classes.first?.id
            resetTimer()
        }
        .onReceive(timer) { _ in
            tick()
        }
        .onChange(of: focusMinutes) { _, _ in resetTimerIfPaused() }
        .onChange(of: shortBreakMinutes) { _, _ in resetTimerIfPaused() }
        .onChange(of: longBreakMinutes) { _, _ in resetTimerIfPaused() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pomodoro")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
            Text("Adjust your focus and break lengths, then log completed focus time to a class.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var timerPanel: some View {
        VStack(spacing: 14) {
            Picker("Mode", selection: $mode) {
                ForEach(PomodoroMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in resetTimer() }

            ZStack {
                Circle()
                    .stroke(AppTheme.separator, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(mode.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 8) {
                    Text(timeString)
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(mode.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 12) {
                Button {
                    isRunning.toggle()
                } label: {
                    Label(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill")
                        .frame(width: 106)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    resetTimer()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    logPicker
                    logButton
                }

                VStack(spacing: 10) {
                    logPicker
                    logButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var logPicker: some View {
        Picker("Log To", selection: Binding(
            get: { selectedClassID },
            set: { selectedClassID = $0 }
        )) {
            ForEach(store.data.classes) { studyClass in
                Text(studyClass.name).tag(Optional(studyClass.id))
            }
        }
        .frame(width: 210)
    }

    private var logButton: some View {
        Button {
            logElapsedFocus()
        } label: {
            Label("Log Focus", systemImage: "checkmark.circle")
        }
        .disabled(selectedClassID == nil || elapsedFocusSeconds < 60)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timer Lengths")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Stepper(value: $focusMinutes, in: 1...180) {
                        LabeledValue(title: "Focus", value: "\(focusMinutes) min")
                    }

                    Stepper(value: $shortBreakMinutes, in: 1...60) {
                        LabeledValue(title: "Short Break", value: "\(shortBreakMinutes) min")
                    }

                    Stepper(value: $longBreakMinutes, in: 1...90) {
                        LabeledValue(title: "Long Break", value: "\(longBreakMinutes) min")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Stepper(value: $focusMinutes, in: 1...180) {
                        LabeledValue(title: "Focus", value: "\(focusMinutes) min")
                    }

                    Stepper(value: $shortBreakMinutes, in: 1...60) {
                        LabeledValue(title: "Short Break", value: "\(shortBreakMinutes) min")
                    }

                    Stepper(value: $longBreakMinutes, in: 1...90) {
                        LabeledValue(title: "Long Break", value: "\(longBreakMinutes) min")
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Completed focus rounds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(completedFocusSessions)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            if store.data.classes.isEmpty {
                Text("Create a class to log Pomodoro focus time.")
                    .foregroundStyle(.secondary)
            }

        }
        .padding(16)
        .frame(minWidth: 220, maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var fullSeconds: Int {
        mode.minutes(focus: focusMinutes, shortBreak: shortBreakMinutes, longBreak: longBreakMinutes) * 60
    }

    private var progress: Double {
        guard fullSeconds > 0 else { return 0 }
        return Double(fullSeconds - remainingSeconds) / Double(fullSeconds)
    }

    private var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func tick() {
        guard isRunning else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
            if mode == .focus {
                elapsedFocusSeconds += 1
            }
            return
        }

        completeCurrentMode()
    }

    private func completeCurrentMode() {
        isRunning = false
        NSSound(named: "Glass")?.play()

        if mode == .focus {
            completedFocusSessions += 1
            logElapsedFocus()
            mode = completedFocusSessions.isMultiple(of: 4) ? .longBreak : .shortBreak
        } else {
            mode = .focus
        }

        resetTimer()
    }

    private func resetTimer() {
        isRunning = false
        remainingSeconds = fullSeconds
        if mode != .focus {
            elapsedFocusSeconds = 0
        }
    }

    private func resetTimerIfPaused() {
        if !isRunning {
            resetTimer()
        }
    }

    private func logElapsedFocus() {
        guard let selectedClassID, elapsedFocusSeconds >= 60 else { return }
        store.addSession(classID: selectedClassID, date: Date(), duration: TimeInterval(elapsedFocusSeconds))
        elapsedFocusSeconds = 0
    }
}

private enum PomodoroMode: String, CaseIterable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var color: Color {
        switch self {
        case .focus: Color(hex: "#2563EB")
        case .shortBreak: Color(hex: "#16A34A")
        case .longBreak: Color(hex: "#DB2777")
        }
    }

    func minutes(focus: Int, shortBreak: Int, longBreak: Int) -> Int {
        switch self {
        case .focus: focus
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
    }
}
