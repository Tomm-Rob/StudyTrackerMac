import SwiftUI

@main
struct StudyTrackerApp: App {
    @StateObject private var store = StudyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .frame(minWidth: 720, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
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
