import SwiftUI

@main
struct SortedEnhanceApp: App {
    @StateObject private var store = PlannerStore.shared

    var body: some Scene {
        WindowGroup("Sorted Enhance") {
            ContentView(store: store)
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandMenu("Planner") {
                Button("Undo Planner Change") { store.undo() }
                    .keyboardShortcut("z", modifiers: [.command, .option])
                    .disabled(!store.canUndo)
                Button("Redo Planner Change") { store.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .option, .shift])
                    .disabled(!store.canRedo)
            }
        }
    }
}
