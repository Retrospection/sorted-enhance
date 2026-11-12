import AppKit
import Combine
import UserNotifications
import OSLog

struct PlannerAlert: Equatable {
    static let prefix = "sorted-enhance.task."
    let identifier: String
    let title: String
    let date: Date
    let repeatingComponents: DateComponents?

    private init(identifier: String, title: String, date: Date, repeatingComponents: DateComponents? = nil) {
        self.identifier = identifier
        self.title = title
        self.date = date
        self.repeatingComponents = repeatingComponents
    }

    init?(_ item: PlannerItem, now: Date) {
        guard !item.deleted, item.status == .active, let start = item.start,
              let offset = item.reminderOffsetMinutes, offset >= 0 else { return nil }
        let fireDate = start.addingTimeInterval(-Double(offset) * 60)
        guard fireDate > now else { return nil }
        identifier = Self.prefix + item.id.uuidString
        title = item.title
        date = fireDate
        repeatingComponents = nil
    }

    func request(sound: TaskAlertSound) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = sound == .system ? .default : nil
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let instant = calendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: repeatingComponents ?? instant,
            repeats: repeatingComponents != nil
        )
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    func matches(_ existing: UNNotificationRequest, sound: TaskAlertSound) -> Bool {
        guard (existing.content.sound != nil) == (sound == .system), existing.content.title == title,
              let trigger = existing.trigger as? UNCalendarNotificationTrigger else { return false }
        if let repeatingComponents {
            return trigger.repeats && trigger.dateComponents == repeatingComponents
        }
        guard !trigger.repeats, let delivery = trigger.nextTriggerDate() else { return false }
        return floor(delivery.timeIntervalSince1970) == floor(date.timeIntervalSince1970)
    }

    static func plan(for items: [PlannerItem], now: Date) -> [PlannerAlert] {
        var explicit = items.filter { $0.seriesID == nil }.compactMap { PlannerAlert($0, now: now) }
        var projected: [PlannerAlert] = []
        let series = Dictionary(grouping: items.filter { $0.seriesID != nil }, by: \.seriesID)
        let requestBudget = 64
        for members in series.values {
            var alerts = members.compactMap { PlannerAlert($0, now: now) }
            guard let tail = members.max(by: { ($0.occurrenceIndex ?? 0) < ($1.occurrenceIndex ?? 0) }),
                  let rule = tail.recurrence, let seriesID = tail.seriesID,
                  let template = rule.template(in: members), template.start != nil,
                  let offset = template.reminderOffsetMinutes, offset >= 0,
                  let next = rule.firstIndex(after: now.addingTimeInterval(Double(offset) * 60)) else {
                explicit += alerts
                continue
            }
            let startIndex = rule.revisionIndex ?? rule.anchorIndex
            let index = max(next, startIndex)
            guard let first = rule.date(at: index) else { explicit += alerts; continue }
            let firstFire = first.addingTimeInterval(-Double(offset) * 60)
            let revision = members.filter { ($0.occurrenceIndex ?? -1) >= startIndex }
            // A repeating notification has no start boundary or exception dates.
            // Use it only if its very next delivery and every known occurrence agree.
            let prefix = Self.prefix + "series." + seriesID.uuidString
            if let pattern = repeatPattern(rule, offset: offset, firstFire: firstFire, now: now),
               revision.allSatisfy({ item in
                   guard let i = item.occurrenceIndex, let expected = rule.date(at: i) else { return false }
                   let expectedFire = expected.addingTimeInterval(-Double(offset) * 60)
                   let actual = PlannerAlert(item, now: now)
                   if expectedFire <= now { return actual == nil }
                   return actual?.date == expectedFire && actual?.title == template.title
               }) {
                let covered = Set(revision.map { Self.prefix + $0.id.uuidString })
                alerts.removeAll { covered.contains($0.identifier) }
                explicit.append(PlannerAlert(identifier: prefix, title: template.title, date: firstFire, repeatingComponents: pattern))
            } else {
                let occupied = Set(revision.compactMap(\.occurrenceIndex))
                var candidate = index
                var count = 0
                while count < requestBudget, let start = rule.date(at: candidate) {
                    if !occupied.contains(candidate) {
                        projected.append(PlannerAlert(identifier: prefix + "." + String(candidate), title: template.title,
                                                      date: start.addingTimeInterval(-Double(offset) * 60)))
                        count += 1
                    }
                    guard candidate < Int.max else { break }
                    candidate += 1
                }
            }
            explicit += alerts
        }
        explicit += projected
        explicit.sort { ($0.date, $0.identifier) < ($1.date, $1.identifier) }
        return Array(explicit.prefix(requestBudget))
    }

    static func changes(
        for candidates: [PlannerAlert], pending: [UNNotificationRequest], sound: TaskAlertSound, now: Date
    ) -> (remove: [String], schedule: [PlannerAlert]) {
        let alerts = candidates.filter { $0.repeatingComponents != nil || $0.date > now }
        let desired = Set(alerts.map(\.identifier))
        let requests = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
        let remove = pending.map(\.identifier).filter { $0.hasPrefix(prefix) && !desired.contains($0) }
        // Adding an existing identifier replaces its request without a cancellation gap.
        let schedule = alerts.filter { alert in
            guard let request = requests[alert.identifier] else { return true }
            return !alert.matches(request, sound: sound)
        }
        return (remove, schedule)
    }

    private static func repeatPattern(
        _ rule: PlannerRecurrence, offset: Int, firstFire: Date, now: Date
    ) -> DateComponents? {
        guard rule.interval == 1 else { return nil }
        let calendar = rule.calendar
        let fire = rule.anchor.addingTimeInterval(-Double(offset) * 60)
        var units: Set<Calendar.Component> = [.hour, .minute, .second, .timeZone]
        // If the offset crosses a day boundary, a DST transition can change its wall-clock time.
        guard calendar.isDate(fire, inSameDayAs: rule.anchor) else { return nil }
        if calendar.timeZone.nextDaylightSavingTimeTransition(after: now) != nil,
           calendar.component(.hour, from: fire) < 4 { return nil }
        switch rule.frequency {
        case .daily: break
        case .weekly: units.insert(.weekday)
        case .monthly:
            guard calendar.component(.day, from: rule.anchor) <= 28 else { return nil }
            units.insert(.day)
        case .yearly:
            if calendar.component(.month, from: rule.anchor) == 2 && calendar.component(.day, from: rule.anchor) == 29 {
                return nil
            }
            units.formUnion([.month, .day])
        }
        var pattern = calendar.dateComponents(units, from: fire)
        pattern.calendar = calendar
        guard let nextFire = calendar.nextDate(after: now, matching: pattern, matchingPolicy: .strict),
              floor(nextFire.timeIntervalSince1970) == floor(firstFire.timeIntervalSince1970)
        else { return nil }
        return pattern
    }

}

@MainActor
final class PlannerNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PlannerNotifications()

    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "SortedEnhance", category: "TaskAlerts")
    private var latest: (alerts: [PlannerAlert], sound: TaskAlertSound)?
    private var feedback = PlannerFeedback()
    private var subscription: AnyCancellable?
    private var items: [PlannerItem]?
    private var refill: Task<Void, Never>?
    private var updating = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesChanged),
                                               name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        let selector = #selector(clockChanged)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: selector, name: NSWorkspace.didWakeNotification, object: nil)
        for name in [NSApplication.didBecomeActiveNotification, .NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
        }
    }

    @objc private nonisolated func preferencesChanged(_ notification: Notification) {
        Task { @MainActor in
            let updated = PlannerFeedback()
            guard updated != feedback else { return }
            feedback = updated
            scheduleRefresh()
        }
    }

    @objc private nonisolated func clockChanged(_ notification: Notification) {
        Task { @MainActor in scheduleRefresh() }
    }

    static func requestPermission() async throws -> Bool {
        let granted = try await shared.center.requestAuthorization(options: [.alert, .sound])
        if granted { shared.scheduleRefresh() }
        return granted
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier.hasPrefix(PlannerAlert.prefix) else { return [.banner, .list, .sound] }
        let preferences = PlannerFeedback()
        guard preferences.alertsEnabled else { return [] }
        return preferences.alertSound == .system ? [.banner, .list, .sound] : [.banner, .list]
    }

    func observe(_ store: PlannerStore) {
        center.delegate = self
        subscription = store.$snapshot.sink { [weak self] snapshot in
            guard let self else { return }
            items = store.libraryIsReadable ? snapshot.items : nil
            scheduleRefresh()
        }
    }

    private func scheduleRefresh() {
        // A damaged library must preserve existing reminders unless the user disabled alerts.
        guard items != nil || !feedback.alertsEnabled else { return }
        let items = items ?? []
        let now = Date.now
        let alerts = feedback.alertsEnabled ? PlannerAlert.plan(for: items, now: now) : []
        let badge = feedback.badgeMode.count(in: items, now: now)
        NSApplication.shared.dockTile.badgeLabel = badge > 0 ? String(badge) : nil

        var nextRefresh = alerts.first?.date
        if feedback.badgeMode == .overdue || feedback.badgeMode == .overdueAndAnytime {
            if let nextStart = items.lazy.filter({ !$0.deleted && $0.status == .active })
                .compactMap(\.start).filter({ $0 > now }).min() {
                nextRefresh = min(nextStart, nextRefresh ?? nextStart)
            }
        }
        refill?.cancel()
        if let nextRefresh {
            // Refill a consumed slot even when no window is active or no task changes.
            let delay = max(1, nextRefresh.timeIntervalSince(now) + 1)
            refill = Task {
                do {
                    try await Task.sleep(for: .seconds(delay))
                    scheduleRefresh()
                } catch is CancellationError {
                    return
                } catch {
                    log.error("Could not wait for the next task alert: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        latest = (alerts, feedback.alertSound)
        guard !updating else { return }
        updating = true
        Task {
            while let pending = latest {
                latest = nil
                await reconcile(pending.alerts, sound: pending.sound)
            }
            updating = false
        }
    }

    private func reconcile(_ candidates: [PlannerAlert], sound: TaskAlertSound) async {
        let pending = await center.pendingNotificationRequests()
        let changes = PlannerAlert.changes(for: candidates, pending: pending, sound: sound, now: Date.now)
        if !changes.remove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: changes.remove)
        }
        for alert in changes.schedule {
            do {
                try await center.add(alert.request(sound: sound))
            } catch {
                log.error("Could not schedule task alert: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
