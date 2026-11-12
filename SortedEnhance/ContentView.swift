import SwiftUI
import AppKit

private enum PlannerSection: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case collections = "Lists & Tags"
    case history = "History"
    case trash = "Trash"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .inbox: "tray"
        case .collections: "folder"
        case .history: "clock.arrow.circlepath"
        case .trash: "trash"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: PlannerStore
    @State private var section: PlannerSection? = .inbox
    @State private var search = ""
    @State private var editing: PlannerItem?
    @State private var quickCapture = false
    @State private var selectedTask: UUID?
    @Environment(\.scenePhase) private var phase

    private var isSearching: Bool { !search.isEmpty }

    private var visibleItems: [PlannerItem] {
        store.items.filter { item in
            if isSearching {
                return !item.deleted && ([item.title, item.notes] + item.tags)
                    .contains { $0.localizedCaseInsensitiveContains(search) }
            }
            switch section {
            case .history: return !item.deleted && item.status != .active
            case .trash: return item.deleted
            default: return !item.deleted && item.status == .active && item.day == nil
            }
        }.sorted { ($0.order, $0.title) < ($1.order, $1.title) }
    }

    var body: some View {
        NavigationSplitView {
            List(PlannerSection.allCases, selection: $section) { destination in
                Label(destination.rawValue, systemImage: destination.symbol)
                    .accessibilityIdentifier(destination.rawValue)
                    .tag(destination)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 195)
        } detail: {
            detail
                .navigationTitle(isSearching ? "Search" : section?.rawValue ?? "Inbox")
                .toolbar {
                    Group {
                        Button("New Task", systemImage: "plus") { editing = PlannerItem(title: "") }
                            .keyboardShortcut("n", modifiers: [.command, .shift])
                    }
                    Button("Quick Capture", systemImage: "bolt") { quickCapture = true }
                        .keyboardShortcut("k", modifiers: .command)
                }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search tasks")
        .onChange(of: section) { search = "" }
        .sheet(item: $editing) { TaskEditorView(item: $0, store: store) }
        .sheet(isPresented: $quickCapture) { QuickCaptureView(store: store) }
        .alert("Could not update planner", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK") { store.errorMessage = nil } } message: {
            Text(store.errorMessage ?? "")
        }
        .plannerNotifications(for: store.items)
        .onAppear { materialize(through: .now) }
        .onChange(of: phase) {
            if phase == .active { materialize(through: .now) }
        }
        .frame(minWidth: 660, minHeight: 430)
    }

    @ViewBuilder private var detail: some View {
        if section == .collections && !isSearching {
            OrganizationView(store: store, onEdit: { editing = $0 })
        } else {
            List(selection: $selectedTask) {
                ForEach(visibleItems) { item in
                    HStack {
                        if item.status != .active {
                            Image(systemName: item.status == .completed ? "checkmark.circle" : "xmark.circle")
                                .accessibilityLabel(item.status == .completed ? "Completed" : "Canceled")
                        }
                        Text(item.title)
                        Spacer()
                        if let listID = item.listID, let list = store.lists.first(where: { $0.id == listID }) {
                            Text(list.name).foregroundStyle(.secondary)
                        }
                    }
                    .tag(item.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editing = item }
                    .accessibilityAction { editing = item }
                    .contextMenu { Button("Open") { editing = item } }
                }
            }
            .onKeyPress(.return) {
                guard let selectedTask, let item = visibleItems.first(where: { $0.id == selectedTask }) else { return .ignored }
                editing = item
                return .handled
            }
            .overlay {
                if visibleItems.isEmpty && !isSearching {
                    ContentUnavailableView(section?.rawValue ?? "Inbox",
                                           systemImage: section?.symbol ?? "tray",
                                           description: Text(emptyMessage))
                }
            }
        }
    }

    private var emptyMessage: String {
        switch section {
        case .history: "Completed and canceled tasks appear here."
        case .trash: "Deleted tasks appear here."
        default: "Create a task to add it to your inbox."
        }
    }

    private func materialize(through day: Date) {
        let occurrences = PlannerRepetition.upcoming(in: store.items, through: day)
        if !occurrences.isEmpty { store.save(occurrences) }
    }
}
