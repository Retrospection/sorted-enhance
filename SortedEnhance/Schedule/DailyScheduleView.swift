import SwiftUI

struct DailyScheduleView: View {
    @ObservedObject var store: PlannerStore
    let onEdit: (PlannerItem) -> Void
    let onNew: (Date) -> Void
    let onDayChange: (Date) -> Void

    @StateObject private var calendars = SystemCalendarStore()
    @State private var day: Date
    @State private var dayInput: String
    @State private var selection: Set<String> = []
    @State private var showOrder = false
    @State private var showCalendars = false
    @State private var showScheduler = false
    @State private var eventEditor: EventEditorRequest?
    @State private var notice: String?

    init(store: PlannerStore, onEdit: @escaping (PlannerItem) -> Void, onNew: @escaping (Date) -> Void,
         initialDay: Date = Date(), onDayChange: @escaping (Date) -> Void = { _ in }) {
        self.store = store
        self.onEdit = onEdit
        self.onNew = onNew
        self.onDayChange = onDayChange
        _day = State(initialValue: initialDay)
        _dayInput = State(initialValue: Self.dateString(initialDay))
    }

    private struct EventEditorRequest: Identifiable {
        let id = UUID()
        var event: PlannerCalendarEvent?
    }

    private enum Entry: Identifiable {
        case task(PlannerItem)
        case event(PlannerCalendarEvent)

        var id: String {
            switch self {
            case .task(let item): "task:" + item.id.uuidString
            case .event(let event): "event:" + event.id
            }
        }

        var title: String {
            switch self {
            case .task(let item): item.title
            case .event(let event): event.title
            }
        }

        var start: Date? {
            switch self {
            case .task(let item): item.start
            case .event(let event): event.isAllDay ? nil : event.start
            }
        }

        var end: Date? {
            switch self {
            case .task(let item): DayPlanner.end(of: item)
            case .event(let event): event.isAllDay ? nil : event.end
            }
        }
    }

    private var dayTasks: [PlannerItem] {
        DayPlanner.items(on: day, in: store.items).sorted { $0.order < $1.order }
    }

    private var selectedTasks: [PlannerItem] {
        dayTasks.filter { selection.contains(Entry.task($0).id) }
    }

    private var timeline: [(entry: Entry, gap: Int?)] {
        let tasks = dayTasks.map(Entry.task)
        let events = calendars.events(on: day).map(Entry.event)
        let entries = (tasks + events).sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
        var lastEnd: Date?
        return entries.map { entry in
            var gap: Int?
            if let start = entry.start, let finish = entry.end {
                if let lastEnd {
                    let boundary = min(lastEnd, finish)
                    gap = Int(start.timeIntervalSince(boundary) / 60)
                }
                lastEnd = max(lastEnd ?? finish, finish)
            }
            return (entry, gap)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            navigation
            actions
            if let notice {
                HStack {
                    Text(notice).foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { self.notice = nil }.buttonStyle(.link)
                }
            }
            if showOrder { orderList } else { timelineList }
            if !selectedTasks.isEmpty { batchActions }
        }
        .padding()
        .sheet(isPresented: $showScheduler) {
            ScheduleForm(day: day) { start, end, buffer in
                let occupied = calendars.events(on: day)
                    .filter { !$0.isAllDay && $0.end > $0.start }
                    .map { DateInterval(start: $0.start, end: $0.end) }
                let result = DayPlanner.plan(items: store.items, from: start, until: end, buffer: buffer, busy: occupied)
                store.save(result.changes)
                notice = result.overflowCount > 0 ? "\(result.overflowCount) tasks did not fit and have no start time." : nil
                showOrder = false
            }
        }
        .sheet(item: $eventEditor) { request in
            CalendarEventEditor(store: calendars, day: day, event: request.event)
        }
        .onChange(of: day, initial: true) { _, date in
            dayInput = Self.dateString(date)
            selection.removeAll()
            notice = nil
            onDayChange(date)
        }
    }

    private var navigation: some View {
        HStack {
            Button { navigate(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous day")
            Button("Today") { day = Calendar.current.startOfDay(for: Date()) }
            Button { navigate(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next day")
            TextField("Schedule date", text: $dayInput)
                .frame(width: 100)
                .onSubmit {
                    if let date = Self.dateFormatter.date(from: dayInput), Self.dateString(date) == dayInput {
                        day = date
                    } else {
                        notice = "Enter a date in YYYY-MM-DD format."
                    }
                }
            Text(Self.dateString(day)).font(.headline)
            Spacer()
            Button("Calendars", systemImage: "calendar") { showCalendars.toggle() }
                .popover(isPresented: $showCalendars) { CalendarSourcesView(store: calendars) }
        }
    }

    private var actions: some View {
        HStack {
            Button("New Task", systemImage: "plus") { onNew(day) }
            Button("New Event") { eventEditor = EventEditorRequest() }
            Button("Auto Schedule") { showScheduler = true }
            Spacer()
            Picker("View", selection: $showOrder) {
                Text("Timeline").tag(false)
                Text("Task Order").tag(true)
            }
            .labelsHidden().pickerStyle(.segmented).fixedSize()
        }
    }

    private var timelineList: some View {
        let rows = timeline
        return List(selection: $selection) {
            ForEach(rows, id: \.entry.id) { row in
                VStack(alignment: .leading, spacing: 4) {
                    if let gap = row.gap, gap != 0 {
                        Text(gap > 0 ? "\(gap) min free" : "\(-gap) min overlap")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        if let start = row.entry.start {
                            Text(start, format: .dateTime.hour().minute()).monospacedDigit()
                        }
                        switch row.entry {
                        case .task(let item):
                            if item.locked { Image(systemName: "lock.fill").accessibilityLabel("Locked") }
                            Text(item.title).strikethrough(item.status != .active)
                            if item.status != .active {
                                Text(item.status == .completed ? "Completed" : "Canceled").font(.caption)
                            }
                            Spacer()
                            Text("\(item.duration) min").foregroundStyle(.secondary)
                        case .event(let event):
                            Image(systemName: "calendar")
                            Text(event.title)
                            Spacer()
                            Text(event.isAllDay ? "All day" : "\(Int(event.end.timeIntervalSince(event.start) / 60)) min")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
                .tag(row.entry.id)
                .onTapGesture(count: 2) { edit(row.entry) }
                .accessibilityElement(children: .contain)
                .accessibilityAction { edit(row.entry) }
            }
        }
        .overlay { if rows.isEmpty { Text("No scheduled items").foregroundStyle(.secondary) } }
        .simultaneousGesture(MagnifyGesture().onEnded { gesture in
            guard selectedTasks.count > 1 else { return }
            let scale = gesture.magnification
            guard scale > 1.1 || scale < 0.9 else { return }
            store.save(DayPlanner.shift(selectedTasks, minutes: scale > 1 ? 5 : -5, changeSpacing: true))
        })
        .onKeyPress(.return) {
            guard selection.count == 1, let row = rows.first(where: { selection.contains($0.entry.id) }) else { return .ignored }
            edit(row.entry)
            return .handled
        }
    }

    private var orderList: some View {
        List(selection: $selection) {
            ForEach(dayTasks) { item in
                Text(item.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .tag(Entry.task(item).id)
                    .draggable(item.id.uuidString)
                    .dropDestination(for: String.self) { identifiers, _ in
                        guard let first = identifiers.first, let id = UUID(uuidString: first) else { return false }
                        let selected = Set(selectedTasks.map(\.id))
                        let ids = selected.contains(id) ? selected : Set(identifiers.compactMap(UUID.init(uuidString:)))
                        guard dayTasks.contains(where: { ids.contains($0.id) }) else { return false }
                        store.save(DayPlanner.reorder(dayTasks, selection: ids, before: item.id))
                        return true
                    }
                    .onTapGesture(count: 2) { onEdit(item) }
            }
        }
    }

    private var batchActions: some View {
        let items = selectedTasks
        return HStack {
            CalendarDrawerButton(store: store, items: items)
            Menu("Time Ruler") {
                ForEach([-60, -5, 5, 60], id: \.self) { amount in
                    Button("\(amount > 0 ? "+" : "")\(amount) min") {
                        store.save(DayPlanner.shift(items, minutes: amount))
                    }
                }
                Divider()
                Button("Spread by 5 minutes") { store.save(DayPlanner.shift(items, minutes: 5, changeSpacing: true)) }
                Button("Contract by 5 minutes") { store.save(DayPlanner.shift(items, minutes: -5, changeSpacing: true)) }
            }
            .fixedSize()
            if showOrder {
                Menu("Move") {
                    let ids = Set(items.map(\.id))
                    ForEach(dayTasks.filter { !ids.contains($0.id) }) { target in
                        Button("Before \(target.title)") {
                            store.save(DayPlanner.reorder(dayTasks, selection: ids, before: target.id))
                        }
                    }
                    Button("To End") { store.save(DayPlanner.reorder(dayTasks, selection: ids, before: nil)) }
                }
                .fixedSize()
            }
        }
    }

    private func edit(_ entry: Entry) {
        switch entry {
        case .task(let item): onEdit(item)
        case .event(let event): eventEditor = EventEditorRequest(event: event)
        }
    }

    private func navigate(_ offset: Int) {
        day = Calendar.current.date(byAdding: .day, value: offset, to: day) ?? day
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dateString(_ date: Date) -> String { dateFormatter.string(from: date) }
}
