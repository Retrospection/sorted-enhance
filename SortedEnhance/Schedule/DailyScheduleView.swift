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
    @Environment(\.locale) private var locale
    @Binding private var day: Date
    @State private var dayInput: String
    @State private var selection: Set<String> = []
    @State private var showOrder = false
    @State private var appliedPlanCount = 0
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
            ScrollViewReader { scroll in
                Group {
                    if showOrder { orderList } else { timelineList }
                }
                .onChange(of: appliedPlanCount) {
                    if let first = timeline.first {
                        scroll.scrollTo(first.entry.id, anchor: .top)
                    }
                }
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
                        appliedPlanCount += 1
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

    private let navigationInk = Color(red: 0.39, green: 0.45, blue: 0.51)

    private var navigation: some View {
        HStack(spacing: 14) {
            Button {
                dayInput = Self.dateString(day)
                showDate.toggle()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 23, weight: .medium))
                        .foregroundStyle(PlannerSection.schedule.tint)
                    Text(dayHeading)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)
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
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .resizable().scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(navigationInk)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
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
                Color.clear.frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            .overlay {
                Image(systemName: "ellipsis")
                    .resizable().scaledToFit()
                    .frame(width: 20, height: 8)
                    .foregroundStyle(navigationInk)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
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
        let monthDay = day.formatted(.dateTime.month(.abbreviated).day().locale(locale))
        if calendar.isDateInToday(day) || calendar.isDateInTomorrow(day) || calendar.isDateInYesterday(day) {
            if locale.language.languageCode?.identifier == "zh" {
                let weekday = day.formatted(.dateTime.weekday(.abbreviated).locale(locale))
                return weekday + " " + monthDay
            }
            return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(locale))
        }
        return monthDay
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
                    HStack(alignment: .top, spacing: 12) {
                        Group {
                            if let start = row.entry.start {
                                Text(start, format: .dateTime.hour().minute())
                            } else {
                                Color.clear.frame(height: 1).accessibilityHidden(true)
                            }
                        }
                        .font(.system(size: 14)).monospacedDigit().foregroundStyle(.secondary)
                        .frame(width: 68, alignment: .trailing)
                        .onTapGesture(count: 2) { edit(row.entry) }

                        switch row.entry {
                        case .task(let item):
                            scheduleTask(item)
                        case .event(let event):
                            eventRow(event)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowInsets(.init(top: 2, leading: 20, bottom: 2, trailing: 40))
                .listRowSeparator(.hidden)
                .contentShape(Rectangle())
                .tag(row.entry.id)
                .id(row.entry.id)
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
                scheduleTask(item)
                    .padding(.vertical, 6)
                    .listRowSeparator(.hidden)
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
            }
        }
    }

    private func scheduleTask(_ item: PlannerItem) -> some View {
        PlannerTaskRow(
            item: item, listName: store.lists.first { $0.id == item.listID }?.name,
            durationMinutes: DayPlanner.occupiedMinutes(item, defaultDuration: defaultDuration),
            completionIdentifier: "ScheduleComplete-" + item.id.uuidString,
            onToggleCompletion: { PlannerFeedback.toggleCompletion(id: item.id, in: store) },
            onOpen: { onEdit(item) }
        )
    }

    private func eventRow(_ event: PlannerCalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar")
                .foregroundStyle(PlannerSection.schedule.tint)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    Label(event.calendarTitle, systemImage: "circle.fill")
                        .foregroundStyle(PlannerSection.schedule.tint)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(PlannerSection.schedule.tint.opacity(0.1), in: Capsule())
                    Group {
                        if event.isAllDay {
                            Text("All day")
                        } else {
                            HStack(spacing: 3) {
                                Text("\(Int(event.end.timeIntervalSince(event.start) / 60)) min")
                                Image(systemName: "arrow.right").accessibilityHidden(true)
                                Text(event.end, format: .dateTime.hour().minute())
                            }
                        }
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEvent(event, day) }
        .accessibilityElement(children: .contain)
        .accessibilityAction { onEvent(event, day) }
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
