import AppKit
import Combine
import EventKit
import Foundation

struct PlannerCalendarEvent: Identifiable, Hashable {
    let id: String
    let calendarID: String
    let calendarTitle: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let isRecurring: Bool
    let isWritable: Bool
    let notes: String
    let modified: Date?

    fileprivate init(_ event: EKEvent) {
        let calendar = event.calendar!
        calendarID = calendar.calendarIdentifier
        calendarTitle = calendar.title
        let occurrence: Date? = event.occurrenceDate
        let occurrenceKey = occurrence.map { String($0.timeIntervalSinceReferenceDate) } ?? "single"
        id = "\(event.calendarItemIdentifier):\(occurrenceKey)"
        title = event.title ?? ""
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        isRecurring = event.hasRecurrenceRules || event.isDetached
        isWritable = calendar.allowsContentModifications
        notes = event.notes ?? ""
        modified = event.lastModifiedDate
    }
}

enum CalendarEditError: LocalizedError {
    case accessDenied, unavailableCalendar, staleEvent, invalidEvent

    var errorDescription: String? {
        switch self {
        case .accessDenied: "Allow calendar access in System Settings to use calendar events."
        case .unavailableCalendar: "Choose a writable calendar."
        case .staleEvent: "This event changed in Calendar. Close the editor and reopen the event."
        case .invalidEvent: "Enter a title and an end time after the start time."
        }
    }
}

@MainActor
final class SystemCalendarStore: ObservableObject {
    @Published private(set) var authorization = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var calendars: [EKCalendar] = []
    private let database = EKEventStore()
    private var observers: Set<AnyCancellable> = []
    private var dayCache: [Date: [PlannerCalendarEvent]] = [:]
    private let hiddenKey = "hiddenEventCalendars"
    private static let visibilityChanged = Notification.Name("SortedEnhanceCalendarVisibilityChanged")

    init() {
        refresh()
        for name in [Notification.Name.EKEventStoreChanged, NSApplication.didBecomeActiveNotification, Self.visibilityChanged, .NSSystemTimeZoneDidChange] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refresh() }
                .store(in: &observers)
        }
    }

    private func refresh() {
        dayCache.removeAll()
        authorization = EKEventStore.authorizationStatus(for: .event)
        calendars = authorization == .fullAccess
            ? database.calendars(for: .event).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            : []
    }

    func requestAccess() async throws {
        if authorization != .fullAccess {
            guard try await database.requestFullAccessToEvents() else {
                refresh()
                throw CalendarEditError.accessDenied
            }
        }
        refresh()
    }

    func shows(_ calendar: EKCalendar) -> Bool {
        !(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? []).contains(calendar.calendarIdentifier)
    }

    func setVisible(_ visible: Bool, calendar: EKCalendar) {
        var hidden = Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
        if visible { hidden.remove(calendar.calendarIdentifier) } else { hidden.insert(calendar.calendarIdentifier) }
        UserDefaults.standard.set(Array(hidden), forKey: hiddenKey)
        NotificationCenter.default.post(name: Self.visibilityChanged, object: nil)
    }

    var writableCalendars: [EKCalendar] { calendars.filter(\.allowsContentModifications) }

    var defaultCalendarID: String? {
        guard authorization == .fullAccess else { return nil }
        return database.defaultCalendarForNewEvents?.calendarIdentifier ?? writableCalendars.first?.calendarIdentifier
    }

    func events(on day: Date) -> [PlannerCalendarEvent] {
        guard let interval = Calendar.current.dateInterval(of: .day, for: day) else { return [] }
        if let result = dayCache[interval.start] { return result }
        let result = visibleEvents(in: interval)
        if dayCache.count >= 32 { dayCache.removeAll() }
        dayCache[interval.start] = result
        return result
    }

    // EventKit date predicates have a four-year maximum range.
    func search(_ text: String, around date: Date = .now) -> [PlannerCalendarEvent] {
        guard !text.isEmpty,
              let start = Calendar.current.date(byAdding: .year, value: -1, to: date),
              let end = Calendar.current.date(byAdding: .year, value: 1, to: date) else { return [] }
        return visibleEvents(in: DateInterval(start: start, end: end)).filter {
            $0.title.localizedCaseInsensitiveContains(text) || $0.notes.localizedCaseInsensitiveContains(text)
        }
    }

    private func visibleEvents(in interval: DateInterval) -> [PlannerCalendarEvent] {
        let visible = calendars.filter(shows)
        guard authorization == .fullAccess, !visible.isEmpty else { return [] }
        let predicate = database.predicateForEvents(withStart: interval.start, end: interval.end, calendars: visible)
        return database.events(matching: predicate)
            .filter { $0.status != .canceled && $0.startDate < interval.end && $0.endDate > interval.start }
            .map(PlannerCalendarEvent.init)
            .sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    private func current(_ snapshot: PlannerCalendarEvent) throws -> EKEvent {
        guard authorization == .fullAccess, let calendar = database.calendar(withIdentifier: snapshot.calendarID),
              calendar.allowsContentModifications else { throw CalendarEditError.unavailableCalendar }
        let predicate = database.predicateForEvents(withStart: snapshot.start.addingTimeInterval(-1),
            end: snapshot.start.addingTimeInterval(1), calendars: [calendar])
        guard let event = database.events(matching: predicate).first(where: { PlannerCalendarEvent($0).id == snapshot.id }),
              event.lastModifiedDate == snapshot.modified else { throw CalendarEditError.staleEvent }
        return event
    }

    @discardableResult
    func save(_ original: PlannerCalendarEvent?, title: String, start: Date, end: Date,
              allDay: Bool, calendarID: String, notes: String, repeatFrequency: EKRecurrenceFrequency? = nil,
              alertMinutesBefore: Int? = nil) throws -> PlannerCalendarEvent {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, end > start else { throw CalendarEditError.invalidEvent }
        guard authorization == .fullAccess, let calendar = database.calendar(withIdentifier: calendarID),
              calendar.allowsContentModifications else { throw CalendarEditError.unavailableCalendar }

        let event = try original.map(current) ?? EKEvent(eventStore: database)
        event.calendar = calendar
        event.title = title
        event.isAllDay = allDay
        event.startDate = start
        event.endDate = end
        event.notes = notes.isEmpty ? nil : notes
        if original == nil, let frequency = repeatFrequency {
            event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: frequency, interval: 1, end: nil))
        }
        if let minutes = alertMinutesBefore {
            event.addAlarm(EKAlarm(relativeOffset: -TimeInterval(minutes) * 60))
        }
        try database.save(event, span: .thisEvent)
        let saved = PlannerCalendarEvent(event)
        refresh()
        return saved
    }

    func delete(_ event: PlannerCalendarEvent) throws {
        try database.remove(current(event), span: .thisEvent)
        refresh()
    }

    func addEvent(title: String, start: Date, duration: Int, calendarID: String? = nil,
                  alertMinutesBefore: Int? = nil) async throws -> PlannerCalendarEvent {
        try await requestAccess()
        guard duration > 0, alertMinutesBefore.map({ $0 >= 0 }) ?? true else { throw CalendarEditError.invalidEvent }
        guard let id = calendarID ?? defaultCalendarID else { throw CalendarEditError.unavailableCalendar }
        return try save(nil, title: title, start: start, end: start.addingTimeInterval(TimeInterval(duration) * 60),
                        allDay: false, calendarID: id, notes: "", alertMinutesBefore: alertMinutesBefore)
    }
}
