import SwiftUI
import AppKit

@MainActor
enum ApplicationIconManager {
    static func apply(for colorScheme: ColorScheme) {
        guard colorScheme == .dark else {
            NSApp.applicationIconImage = nil
            return
        }

        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments[0])
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
        let candidates = [
            Bundle.main.url(forResource: "StudyTrackerIcon-Dark", withExtension: "png"),
            executableDirectory.appendingPathComponent("StudyTrackerIcon-Dark.png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Assets/StudyTrackerIcon-Dark.png")
        ]

        for case let url? in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let image = NSImage(contentsOf: url) {
                NSApp.applicationIconImage = image
                return
            }
        }
    }
}

final class StudyTrackerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct StudyTrackerApp: App {
    @NSApplicationDelegateAdaptor(StudyTrackerAppDelegate.self) private var appDelegate
    @StateObject private var store = StudyStore()
    @AppStorage(AppearanceMode.storageKey) private var appearanceRawValue =
        AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(appearance.colorScheme)
                .frame(
                    minWidth: 560,
                    maxWidth: .infinity,
                    minHeight: 420,
                    maxHeight: .infinity
                )
        }
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Class") {
                    store.addClass()
                }
                .disabled(store.isPersistenceLocked || store.activeClasses.count >= StudyStore.maxClasses)
                .keyboardShortcut("n")
            }
        }
    }
}
