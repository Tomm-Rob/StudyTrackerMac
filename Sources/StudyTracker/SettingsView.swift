import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var store: StudyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("Choose where your local study data is saved and tune chart colors.")
                    .foregroundStyle(.secondary)
            }

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

                if let error = store.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
            .padding(18)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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

                Text("The circle graph uses each class color. Change a class color from that class page.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()
        }
        .padding(26)
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
