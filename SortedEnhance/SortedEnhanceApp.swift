import SwiftUI

@main
struct SortedEnhanceApp: App {
    @StateObject private var store = PlannerStore.shared

    private let widgetUpdates = PlannerWidgetUpdates(store: PlannerStore.shared)
    @StateObject private var recovery = PlannerRecovery(store: PlannerStore.shared)

    var body: some Scene {
        Window("Sorted Enhance", id: "planner") {
            ContentView(store: store)
                .modifier(PlannerPreferencesModifier())
                .onAppear { recovery.refresh() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1024, height: 800)
        .commands {
            PlannerCommands()
            CommandMenu("Planner") {
                Button("Undo Planner Change") { store.undo() }
                    .keyboardShortcut("z", modifiers: [.command, .option])
                    .disabled(!store.canUndo)
                Button("Redo Planner Change") { store.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .option, .shift])
                    .disabled(!store.canRedo)
            }
        }
        Settings {
            PlannerSettingsView(recovery: recovery)
                .modifier(PlannerPreferencesModifier())
        }
    }
}
