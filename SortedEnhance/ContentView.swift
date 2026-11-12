import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: PlannerStore
    @State private var section: PlannerSection = .schedule
    @State private var search = ""
    @State private var editing: PlannerItem?
    @State private var quickCapture = false
    @State private var listToShow: UUID?
    @State private var listNavigation = UUID()
    @State private var scheduleDay = Date.now
    @State private var schedulerPresented = false
    @State private var searching = false
    @State private var collectionRequest = 0
    @State private var helpPresented = false
    @Environment(\.openSettings) private var openSettings
    @StateObject private var calendars = SystemCalendarStore()
    @State private var eventToEdit: PlannerCalendarEvent?
    @State private var editingEvent = false
    @State private var eventDay = Date.now
    @State private var eventDraft: PlannerItem?
    @State private var searchEvents: [PlannerCalendarEvent] = []
    @State private var selectedTask: UUID?
    @Environment(\.scenePhase) private var phase

    private var isSearching: Bool { searching }
    private var editorPresented: Bool { editing != nil || editingEvent }

    private var visibleItems: [PlannerItem] {
        store.items.filter { item in
            if isSearching {
                return !search.isEmpty && !item.deleted && ([item.title, item.notes] + item.tags)
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
        GeometryReader { geometry in
            HStack(spacing: 0) {
                PlannerSidebar(section: Binding(get: { section }, set: { destination in
                    listToShow = nil
                    listNavigation = UUID()
                    section = destination
                }), day: $scheduleDay, onSettings: { openSettings() },
                               onHelp: { helpPresented = true })
                    .frame(width: min(300, max(200, geometry.size.width * 0.293)))
                    .overlay {
                        if schedulerPresented || editorPresented {
                            Color(nsColor: .textBackgroundColor).opacity(0.8)
                                .onTapGesture { if schedulerPresented { schedulerPresented = false } }
                        }
                    }
                ZStack(alignment: .bottomTrailing) {
                    Color(nsColor: .textBackgroundColor)
                    detail
                        .accessibilityHidden(editorPresented)
                        .disabled(editorPresented)
                    if !searching && !schedulerPresented && !editorPresented && section != .history && section != .trash {
                        Button(action: createInSection) {
                            Image(systemName: "plus")
                                .font(.system(size: 23, weight: .semibold))
                                .frame(width: 46, height: 46)
                                .foregroundStyle(.white)
                                .background(section.tint, in: Circle())
                                .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(section == .lists ? "New List" : section == .tags ? "New Tag" : "New Task")
                        .accessibilityIdentifier(section == .schedule ? "ScheduleAddButton" : section == .lists ? "New List" : section == .tags ? "New Tag" : "New Task")
                        .padding(24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if let item = editing {
                        PlannerEditorOverlay {
                            TaskEditorView(item: item, store: store, onClose: closeEditor, onNewEvent: { draft in
                                openEvent(nil, day: draft.day ?? scheduleDay, draft: draft)
                            }).id(item.id)
                        }
                    } else if editingEvent {
                        PlannerEditorOverlay {
                            CalendarEventEditor(store: calendars, day: eventDay, event: eventToEdit,
                                                taskDraft: eventDraft, onClose: closeEditor, onSwitchToTask: { draft in
                                closeEditor()
                                editing = draft
                            })
                        }
                    }
                }
            }
        }
        .tint(section.tint)
        .ignoresSafeArea(.container, edges: .top)
        .focusedSceneValue(\.plannerSearch, { startSearch() })
        .focusedSceneValue(\.plannerCreate, { createInSection() })
        .focusedSceneValue(\.plannerQuickCapture, { quickCapture = true })
        .onChange(of: section) { _, _ in
            finishSearch()
            schedulerPresented = false
        }
        .sheet(isPresented: $helpPresented) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Keyboard Shortcuts").font(.title2.bold())
                LabeledContent("Search", value: "⌘F")
                LabeledContent("New item", value: "⇧⌘N")
                LabeledContent("Quick Capture", value: "⌘K")
                Button("Done") { helpPresented = false }.keyboardShortcut(.cancelAction)
            }.padding(24).frame(width: 300)
        }
        .onChange(of: search) { searchEvents = calendars.search(search) }
        .onReceive(calendars.$calendars.receive(on: RunLoop.main)) { _ in searchEvents = calendars.search(search) }
        .sheet(isPresented: $quickCapture) { QuickCaptureView(store: store) }
        .alert("Could not update planner", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK") { store.errorMessage = nil } } message: {
            Text(store.errorMessage ?? "")
        }
        .onOpenURL(perform: openLink)
        .onReceive(DistributedNotificationCenter.default().publisher(for: SharedCapture.notification)) { _ in
            store.importSharedCaptures()
        }
        .plannerNotifications(for: store.items)
        .onAppear {
            store.importSharedCaptures()
            materialize(through: .now)
        }
        .onChange(of: phase) {
            if phase == .active {
                store.importSharedCaptures()
                materialize(through: .now)
            }
        }
        .frame(minWidth: 660, minHeight: 430)
    }

    @ViewBuilder private var detail: some View {
        if section == .schedule && !isSearching {
            DailyScheduleView(store: store, onEdit: { editing = $0 }, onNew: { day in
                var item = PlannerItem(title: "")
                item.day = day
                editing = item
            }, day: $scheduleDay, schedulerPresented: $schedulerPresented,
               onDayChange: { materialize(through: $0) }, onSearch: startSearch,
               onEvent: { event, day in openEvent(event, day: day) })
        } else if (section == .lists || section == .tags) && !isSearching {
            OrganizationView(store: store, section: section == .lists ? .lists : .tags,
                             onEdit: { editing = $0 }, onSearch: startSearch,
                             newCollectionSignal: collectionRequest, initialListID: listToShow)
                .id(listNavigation)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if isSearching {
                    HStack(spacing: 12) {
                        PlannerSearchField(text: $search)
                        Button("Done", action: finishSearch).keyboardShortcut(.cancelAction)
                    }
                    .padding(.horizontal, 40).padding(.top, 37).padding(.bottom, 14)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: section.systemImage).foregroundStyle(section.tint)
                        Text(section.label).fontWeight(.bold)
                        Spacer()
                        Button(action: startSearch) { Image(systemName: "magnifyingglass") }
                            .accessibilityLabel("Search")
                        Menu {
                            Button("New Task") { editing = PlannerItem(title: "") }
                            Button("Quick Capture") { quickCapture = true }
                        } label: { Image(systemName: "ellipsis") }
                        .menuIndicator(.hidden).fixedSize()
                        .accessibilityLabel("More actions")
                    }
                    .font(.system(size: 24))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 44).padding(.top, 38).padding(.bottom, 20)
                }
                if visibleItems.isEmpty && !isSearching {
                    PlannerEmptyState(section: section)
                        .padding(.bottom, 180)
                } else {
                    taskList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var taskList: some View {
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
                    .accessibilityElement(children: .contain)
                    .accessibilityAction { editing = item }
                    .contextMenu { Button("Open") { editing = item } }
                }
                if isSearching {
                    ForEach(searchEvents) { event in
                        Label(event.title, systemImage: "calendar")
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { openEvent(event, day: event.start) }
                            .accessibilityElement(children: .contain)
                            .accessibilityAction { openEvent(event, day: event.start) }
                    }
                }
            }
            .onKeyPress(.return) {
                guard let selectedTask, let item = visibleItems.first(where: { $0.id == selectedTask }) else { return .ignored }
                editing = item
                return .handled
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 32)
    }

    private func closeEditor() {
        editing = nil
        editingEvent = false
        eventToEdit = nil
        eventDraft = nil
    }

    private func openEvent(_ event: PlannerCalendarEvent?, day: Date, draft: PlannerItem? = nil) {
        editing = nil
        eventDay = day
        eventToEdit = event
        eventDraft = draft
        editingEvent = true
    }

    private func startSearch() {
        guard !editorPresented else { return }
        schedulerPresented = false
        searching = true
    }

    private func finishSearch() {
        searching = false
        search = ""
    }

    private func createInSection() {
        guard !editorPresented else { return }
        if !searching && (section == .lists || section == .tags) {
            collectionRequest += 1
        } else {
            var item = PlannerItem(title: "")
            if !searching && section == .schedule { item.day = scheduleDay }
            editing = item
        }
    }

    private func openLink(_ url: URL) {
        guard let link = PlannerLink(url: url) else { return }
        closeEditor()
        quickCapture = false
        eventToEdit = nil
        finishSearch()
        switch link {
        case .today:
            scheduleDay = .now
            section = .schedule
        case .date(let day):
            scheduleDay = day
            section = .schedule
        case .list(let id):
            guard store.lists.contains(where: { $0.id == id }) else { return }
            listToShow = id
            listNavigation = UUID()
            section = .lists
        case .search(let query):
            searching = true
            search = query
        case .item(let id):
            if !store.items.contains(where: { $0.id == id }) { materialize(through: .now) }
            guard let item = store.items.first(where: { $0.id == id }) else { return }
            eventToEdit = nil
            quickCapture = false
            editing = item
        case .add(let title, let notes):
            var item = PlannerItem(title: title)
            item.notes = notes
            if store.save(item) {
                section = .inbox
                search = ""
                selectedTask = item.id
            }
        }
    }

    private func materialize(through day: Date) {
        let occurrences = PlannerRepetition.upcoming(in: store.items, through: day)
        if !occurrences.isEmpty { store.save(occurrences) }
    }
}
