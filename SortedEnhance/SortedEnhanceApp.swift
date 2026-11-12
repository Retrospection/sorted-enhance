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
        Settings {
            TabView {
                GeneralPreferencesView().tabItem { Label("General", systemImage: "gearshape") }
                RecoveryView(recovery: recovery).tabItem { Label("Data", systemImage: "externaldrive") }
            }
            .modifier(PlannerPreferencesModifier())
            .frame(minWidth: 470, minHeight: 360)
        }
    }
}
