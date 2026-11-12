import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var store: PlannerStore
    @AppStorage("planner.sidebarWidth") private var preferredSidebarWidth = 300.0
    @State private var section: PlannerSection = .schedule
    @State private var search = ""
    @State private var editing: PlannerItem?
    @State private var quickCapture = false
    @State private var collectionToShow: CollectionFilter?
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
    @State private var eventFields: EventCreationDraft?
    @State private var selectedTask: UUID?
    @Environment(\.scenePhase) private var phase

    private var editorPresented: Bool { editing != nil || editingEvent }

    private var visibleItems: [PlannerItem] {
        store.items.filter { item in
            switch section {
            case .history: return !item.deleted && item.status != .active
            case .trash: return item.deleted
            default: return !item.deleted && item.status == .active && item.day == nil
            }
        }.sorted { ($0.order, $0.title) < ($1.order, $1.title) }
    }

    var body: some View {
        GeometryReader { geometry in
            let sidebarRange = 200.0...max(200, min(500, geometry.size.width - 460))
            let sidebarWidth = min(sidebarRange.upperBound, max(sidebarRange.lowerBound, preferredSidebarWidth))
            HStack(spacing: 0) {
                PlannerSidebar(section: Binding(get: { section }, set: { destination in
                    finishSearch()
                    collectionToShow = nil
                    listNavigation = UUID()
                    section = destination
                }), day: $scheduleDay, onSettings: { finishSearch(); openSettings() },
                               onHelp: { finishSearch(); helpPresented = true })
                    .frame(width: sidebarWidth)
                    .overlay {
                        if searching {
                            Color(nsColor: .textBackgroundColor).opacity(0.8).allowsHitTesting(false)
                        } else if schedulerPresented || editorPresented {
                            Color(nsColor: .textBackgroundColor).opacity(0.8)
                                .onTapGesture { if schedulerPresented { schedulerPresented = false } }
                        }
                    }
                    .overlay(alignment: .trailing) {
                        if !searching && !schedulerPresented && !editorPresented {
                            PlannerSidebarDivider(width: sidebarWidth, range: sidebarRange, availableWidth: geometry.size.width) {
                                preferredSidebarWidth = $0
                            }
                            .frame(width: 8)
                        }
                    }
                ZStack(alignment: .bottomTrailing) {
                    Color(nsColor: .textBackgroundColor)
                    detail
                        .accessibilityHidden(editorPresented || searching)
                        .disabled(editorPresented || searching)
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
                .overlay(alignment: .top) {
                    if searching {
                        ZStack(alignment: .top) {
                            Color(nsColor: .textBackgroundColor).opacity(0.8)
                                .onTapGesture(perform: finishSearch)
                            PlannerQuickSearch(store: store, calendars: calendars, query: $search,
                                               onDone: finishSearch, onOpen: openSearchResult)
                                .frame(width: min(560, geometry.size.width - sidebarWidth - 32), height: 300)
                                .padding(.top, 38)
                        }
                    } else if let item = editing {
                        PlannerEditorOverlay {
                            TaskEditorView(item: item, store: store, onClose: closeEditor, onNewEvent: { draft in
                                openEvent(nil, day: draft.day ?? scheduleDay, draft: draft)
                            }).id(item.id)
                        }
                    } else if editingEvent {
                        PlannerEditorOverlay {
                            CalendarEventEditor(store: calendars, day: eventDay, event: eventToEdit,
                                                taskDraft: eventDraft, eventFields: eventFields, onClose: closeEditor, onSwitchToTask: { draft, fields in
                                closeEditor()
                                eventFields = fields
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
        .focusedSceneValue(\.plannerQuickCapture, { finishSearch(); quickCapture = true })
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
        if section == .schedule {
            DailyScheduleView(store: store, onEdit: { editing = $0 }, onNew: { day in
                var item = PlannerItem(title: "")
                item.day = day
                editing = item
            }, day: $scheduleDay, schedulerPresented: $schedulerPresented,
               onDayChange: { materialize(through: $0) }, onSearch: startSearch,
               onEvent: { event, day in openEvent(event, day: day) })
        } else if section == .lists || section == .tags {
            OrganizationView(store: store, section: section == .lists ? .lists : .tags,
                             onEdit: { editing = $0 }, onSearch: startSearch,
                             newCollectionSignal: collectionRequest, initialFilter: collectionToShow)
                .id(listNavigation)
        } else {
            VStack(alignment: .leading, spacing: 0) {
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
                if section == .history || section == .trash {
                    PlannerArchiveView(section: section, store: store, onEdit: { editing = $0 })
                } else if visibleItems.isEmpty {
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
                PlannerTaskRow(item: item,
                               listName: store.lists.first { $0.id == item.listID }?.name,
                               completionIdentifier: "InboxComplete-" + item.id.uuidString,
                               onToggleCompletion: {
                                   if store.toggleOccurrenceCompletion(id: item.id), selectedTask == item.id {
                                       selectedTask = nil
                                   }
                               },
                               onOpen: { editing = item })
                    .contextMenu { Button("Open") { editing = item } }
                    .tag(item.id)
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
        eventFields = nil
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

    private func openSearchResult(_ result: PlannerSearchResult) {
        finishSearch()
        switch result {
        case .task(let item): editing = item
        case .event(let event): openEvent(event, day: event.start)
        case .list(let list): showCollection(.list(list.id))
        case .tag(let tag): showCollection(.tag(tag))
        }
    }

    private func showCollection(_ filter: CollectionFilter) {
        collectionToShow = filter
        listNavigation = UUID()
        switch filter {
        case .list, .folder: section = .lists
        case .tag: section = .tags
        }
    }

    private func createInSection() {
        guard !editorPresented else { return }
        if searching {
            finishSearch()
            editing = PlannerItem(title: "")
        } else if section == .lists || section == .tags {
            collectionRequest += 1
        } else {
            var item = PlannerItem(title: "")
            if section == .schedule { item.day = scheduleDay }
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
            showCollection(.list(id))
        case .search(let query):
            startSearch()
            search = query
        case .item(let id):
            if !store.items.contains(where: { $0.id == id }) { materialize(through: .now) }
            guard let item = store.items.first(where: { $0.id == id && $0.purged != true }) else { return }
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
