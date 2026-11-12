import SwiftUI

extension FocusedValues {
    @Entry var plannerSearch: (() -> Void)?
    @Entry var plannerCreate: (() -> Void)?
    @Entry var plannerQuickCapture: (() -> Void)?
}

struct PlannerCommands: Commands {
    let presentSettings: () -> Void
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.plannerSearch) private var search
    @FocusedValue(\.plannerCreate) private var create
    @FocusedValue(\.plannerQuickCapture) private var capture

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: "planner")
                presentSettings()
            }
            .keyboardShortcut(",")
        }
        CommandGroup(after: .newItem) {
            Button("New item") { create?() }.keyboardShortcut("n", modifiers: [.shift, .command])
                .disabled(create == nil)
            Button("Quick Capture") { capture?() }.keyboardShortcut("k")
                .disabled(capture == nil)
        }
        CommandGroup(after: .textEditing) {
            Button("Search") { search?() }.keyboardShortcut("f")
                .disabled(search == nil)
        }
    }
}
