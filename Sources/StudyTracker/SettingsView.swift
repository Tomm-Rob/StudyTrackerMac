import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: StudyStore
    @AppStorage(AppearanceMode.storageKey) private var appearanceRawValue =
        AppearanceMode.system.rawValue

    private var appearanceSelection: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRawValue) ?? .system },
            set: { appearanceRawValue = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .semibold, design: .default))
                    Text("Adjust appearance, local data storage, and chart colors.")
                        .foregroundStyle(.secondary)
                }

                appearanceSettings

                VStack(alignment: .leading, spacing: 16) {
                    Text("Data Location")
                        .font(.headline)

                    Text(store.dataFileURL.path)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)

                    HStack {
                        Button {
                            chooseSaveDirectory()
                        } label: {
                            Label("Choose Folder", systemImage: "folder")
                        }

                        Button {
                            store.resetSaveDirectory()
                        } label: {
                            Label("Use Default", systemImage: "arrow.uturn.backward")
                        }
                    }
                    .disabled(store.isPersistenceLocked)

                    if let error = store.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
                .appPanel()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Chart Colors")
                        .font(.headline)

                    ColorPicker(
                        "Daily bar graph color",
                        selection: Binding(
                            get: { Color(hex: store.data.chartSettings.dailyBarColorHex) },
                            set: { store.data.chartSettings.dailyBarColorHex = $0.hexString() ?? store.data.chartSettings.dailyBarColorHex }
                        )
                    )
                    .disabled(store.isPersistenceLocked)

                    Text("The circle graph uses each class color. Change a class color from that class page.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .appPanel()

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)

            Picker("Appearance", selection: appearanceSelection) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 440)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel()
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Study Tracker Save Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            store.changeSaveDirectory(to: url)
        }
    }
}
