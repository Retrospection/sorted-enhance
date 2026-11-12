import SwiftUI

extension FocusedValues {
    @Entry var plannerSearch: (() -> Void)?
    @Entry var plannerCreate: (() -> Void)?
    @Entry var plannerQuickCapture: (() -> Void)?
}

struct PlannerCommands: Commands {
    @FocusedValue(\.plannerSearch) private var search
    @FocusedValue(\.plannerCreate) private var create
    @FocusedValue(\.plannerQuickCapture) private var capture

    var body: some Commands {
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
