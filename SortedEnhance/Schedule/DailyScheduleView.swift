import SwiftUI

struct DailyScheduleView: View {
    @ObservedObject var store: PlannerStore
    let onEdit: (PlannerItem) -> Void
    let onNew: (Date) -> Void
    let onDayChange: (Date) -> Void
    let onSearch: () -> Void
    let onEvent: (PlannerCalendarEvent?, Date) -> Void

    @AppStorage("scheduleDefaultDuration") private var defaultDuration = DayPlanner.standardDuration
    @StateObject private var calendars = SystemCalendarStore()
    @Binding private var day: Date
    @State private var dayInput: String
    @State private var selection: Set<String> = []
    @State private var showOrder = false
    @State private var showCalendars = false
    @State private var showDate = false
    @Binding private var showScheduler: Bool
    @State private var scheduleSelection: Set<UUID>?
    @State private var notice: String?

    init(store: PlannerStore, onEdit: @escaping (PlannerItem) -> Void, onNew: @escaping (Date) -> Void,
         day: Binding<Date>, schedulerPresented: Binding<Bool>, onDayChange: @escaping (Date) -> Void, onSearch: @escaping () -> Void,
         onEvent: @escaping (PlannerCalendarEvent?, Date) -> Void) {
        self.store = store
        self.onEdit = onEdit
        self.onNew = onNew
        self.onDayChange = onDayChange
        self.onSearch = onSearch
        self.onEvent = onEvent
        _day = day
        _showScheduler = schedulerPresented
        _dayInput = State(initialValue: Self.dateString(day.wrappedValue))
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

        func end(defaultDuration: Int) -> Date? {
            switch self {
            case .task(let item): DayPlanner.end(of: item, defaultDuration: defaultDuration)
            case .event(let event): event.isAllDay ? nil : event.end
            }
        }
    }

    private var dayTasks: [PlannerItem] {
        DayPlanner.items(on: day, in: store.items, defaultDuration: defaultDuration).sorted { $0.order < $1.order }
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
            if let start = entry.start, let finish = entry.end(defaultDuration: defaultDuration) {
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
        VStack(alignment: .leading, spacing: 0) {
            navigation
                .padding(.horizontal, 40)
                .padding(.top, 32)
            Button { onNew(day) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Task")
            .accessibilityIdentifier("newScheduleTask")
            .help("New task on this day")
            .padding(.leading, 44)
            .padding(.top, 22)
            if let notice {
                HStack {
                    Text(notice).foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") { self.notice = nil }.buttonStyle(.link)
                }
            }
            Group {
                if showOrder { orderList } else { timelineList }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            if !selectedTasks.isEmpty { batchActions.padding(.horizontal, 40).padding(.vertical, 10) }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay {
            if !showOrder && timeline.isEmpty {
                PlannerEmptyState(section: .schedule)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("emptySchedule")
                    .offset(y: -75)
                    .allowsHitTesting(false)
            }
        }
        .disabled(showScheduler || showDate)
        .accessibilityHidden(showScheduler || showDate)
        .overlay(alignment: .topLeading) {
            if showDate {
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { showDate = false }
                        .accessibilityHidden(true)
                    datePicker
                        .frame(width: 260)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
                        .padding(.top, 72)
                        .padding(.leading, 40)
                        .onExitCommand { showDate = false }
                }
            }
        }
        .overlay {
            if showScheduler {
                ZStack {
                    Color(nsColor: .textBackgroundColor).opacity(0.8)
                        .contentShape(Rectangle())
                        .onTapGesture { showScheduler = false }
                        .accessibilityHidden(true)
                    ScheduleForm(day: day, cancel: { showScheduler = false }) { start, end, buffer, duration in
                        let occupied = calendars.events(on: day)
                            .filter { !$0.isAllDay && $0.end > $0.start }
                            .map { DateInterval(start: $0.start, end: $0.end) }
                        let result = DayPlanner.plan(items: store.items, from: start, until: end, buffer: buffer,
                                                     busy: occupied, defaultDuration: duration, selectedIDs: scheduleSelection)
                        store.save(result.changes)
                        notice = result.overflowCount > 0 ? "\(result.overflowCount) tasks did not fit and have no start time." : nil
                        showOrder = false
                        showScheduler = false
                    }
                    .padding(.horizontal, 12)
                }
            }
        }

        .onChange(of: day, initial: true) { _, date in
            dayInput = Self.dateString(date)
            selection.removeAll()
            notice = nil
            onDayChange(date)
        }
    }

    private var navigation: some View {
        HStack(spacing: 14) {
            Button {
                dayInput = Self.dateString(day)
                showDate.toggle()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    Text(dayHeading)
                        .font(.system(size: 24, weight: .bold))
                    Text(dateCaption)
                        .font(.system(size: 19))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schedule date")
            .accessibilityValue(Self.dateString(day))
            .accessibilityIdentifier("scheduleDatePicker")
            Spacer(minLength: 8)
            Button(action: onSearch) { Image(systemName: "magnifyingglass") }
                .buttonStyle(.plain)
                .accessibilityLabel("Search")
                .help("Search")
            Menu {
                Button("New Event") { onEvent(nil, day) }
                Button("Auto Schedule") {
                    scheduleSelection = nil
                    showScheduler = true
                }
                Button("Calendars") { showCalendars = true }
                Divider()
                Picker("View", selection: $showOrder) {
                    Text("Timeline").tag(false)
                    Text("Task Order").tag(true)
                }
                Divider()
                Button("Previous day") { navigate(-1) }.keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Today") { day = Calendar.current.startOfDay(for: Date()) }
                Button("Next day") { navigate(1) }.keyboardShortcut(.rightArrow, modifiers: .command)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Schedule options")
            .accessibilityIdentifier("scheduleOptions")
            .popover(isPresented: $showCalendars) { CalendarSourcesView(store: calendars) }
        }
        .font(.system(size: 18))
        .frame(height: 36)
    }

    private var dayHeading: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(day) { return String(localized: "Tomorrow") }
        if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
        return day.formatted(.dateTime.weekday(.wide))
    }

    private var dateCaption: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) || calendar.isDateInTomorrow(day) || calendar.isDateInYesterday(day) {
            return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
        return day.formatted(.dateTime.month(.abbreviated).day())
    }

    private var datePicker: some View {
        VStack(spacing: 10) {
            DatePicker("Choose a day", selection: $day, displayedComponents: .date)
                .datePickerStyle(.graphical)
            TextField("Schedule date", text: $dayInput)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Schedule date")
                .accessibilityIdentifier("scheduleDateInput")
                .onSubmit {
                    guard let date = Self.dateFormatter.date(from: dayInput), Self.dateString(date) == dayInput else {
                        notice = "Enter a date in YYYY-MM-DD format."
                        return
                    }
                    day = date
                    showDate = false
                }
            Button("Today") { day = Calendar.current.startOfDay(for: Date()); showDate = false }
        }
        .padding()
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
                    HStack(spacing: 12) {
                        Group {
                            if let start = row.entry.start {
                                Text(start, format: .dateTime.hour().minute())
                            } else {
                                Text(verbatim: "")
                            }
                        }
                            .font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                            .frame(minWidth: 54, alignment: .trailing)
                        switch row.entry {
                        case .task(let item):
                            Image(systemName: statusSymbol(for: item))
                                .foregroundStyle(item.status == .active ? Color.secondary : .accentColor)
                                .accessibilityLabel(item.status.rawValue.localizedCapitalized)
                            Text(item.title)
                                .strikethrough(item.status != .active)
                            if item.locked {
                                Image(systemName: "lock.fill")
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .accessibilityLabel("Locked")
                            }
                            Spacer()
                            Text("\(DayPlanner.occupiedMinutes(item, defaultDuration: defaultDuration)) min")
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        case .event(let event):
                            Image(systemName: "calendar").foregroundStyle(Color.accentColor)
                            Text(event.title)
                            Spacer()
                            Text(event.isAllDay ? "All day" : "\(Int(event.end.timeIntervalSince(event.start) / 60)) min")
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 15))
                    .padding(.vertical, 5)
                }
                .listRowInsets(.init(top: 2, leading: 28, bottom: 2, trailing: 40))
                .contentShape(Rectangle())
                .tag(row.entry.id)
                .onTapGesture(count: 2) { edit(row.entry) }
                .accessibilityElement(children: .contain)
                .accessibilityAction { edit(row.entry) }
            }
        }
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
            Button("Schedule Selection") {
                scheduleSelection = Set(items.map(\.id))
                showScheduler = true
            }
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

    private func statusSymbol(for item: PlannerItem) -> String {
        switch item.status {
        case .active: "circle"
        case .completed: "checkmark.circle.fill"
        case .canceled: "xmark.circle"
        }
    }

    private func edit(_ entry: Entry) {
        switch entry {
        case .task(let item): onEdit(item)
        case .event(let event): onEvent(event, day)
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
