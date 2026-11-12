import SwiftUI
import UserNotifications
import OSLog

struct PlannerAlert: Equatable {
    static let prefix = "sorted-enhance.task."
    let identifier: String
    let title: String
    let date: Date

    init?(_ item: PlannerItem, now: Date) {
        guard !item.deleted, item.status == .active, let start = item.start,
              let offset = item.reminderOffsetMinutes, offset >= 0 else { return nil }
        let fireDate = start.addingTimeInterval(-Double(offset) * 60)
        guard fireDate > now else { return nil }
        identifier = Self.prefix + item.id.uuidString
        title = item.title
        date = fireDate
    }

    var request: UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = .default
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let instant = calendar.dateComponents([.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: instant, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    func matches(_ existing: UNNotificationRequest) -> Bool {
        guard existing.content.title == title,
              let trigger = existing.trigger as? UNCalendarNotificationTrigger,
              let delivery = trigger.nextTriggerDate() else { return false }
        return floor(delivery.timeIntervalSince1970) == floor(date.timeIntervalSince1970)
    }
}

@MainActor
final class PlannerNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PlannerNotifications()

    private let center = UNUserNotificationCenter.current()
    private let log = Logger(subsystem: "SortedEnhance", category: "TaskAlerts")
    private var latest: [PlannerAlert]?
    private var desiredAlerts: [PlannerAlert] = []
    private var updating = false

    static func requestPermission() async throws -> Bool {
        let granted = try await shared.center.requestAuthorization(options: [.alert, .sound])
        if granted { shared.scheduleRefresh() }
        return granted
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func update(_ items: [PlannerItem]) {
        center.delegate = self
        let now = Date()
        desiredAlerts = items.compactMap { PlannerAlert($0, now: now) }
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        latest = desiredAlerts
        guard !updating else { return }
        updating = true
        Task {
            while let alerts = latest {
                latest = nil
                await reconcile(alerts)
            }
            updating = false
        }
    }

    private func reconcile(_ candidates: [PlannerAlert]) async {
        let pending = await center.pendingNotificationRequests()
        let now = Date()
        let alerts = candidates.filter { $0.date > now }
        let desired = Dictionary(uniqueKeysWithValues: alerts.map { ($0.identifier, $0) })
        var unchanged: Set<String> = []
        var obsolete: [String] = []
        for request in pending where request.identifier.hasPrefix(PlannerAlert.prefix) {
            if desired[request.identifier]?.matches(request) == true {
                unchanged.insert(request.identifier)
            } else {
                obsolete.append(request.identifier)
            }
        }
        if !obsolete.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: obsolete)
        }
        for alert in alerts where !unchanged.contains(alert.identifier) {
            do {
                try await center.add(alert.request)
            } catch {
                log.error("Could not schedule task alert: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension View {
    func plannerNotifications(for items: [PlannerItem]) -> some View {
        onChange(of: items, initial: true) { _, items in
            PlannerNotifications.shared.update(items)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            PlannerNotifications.shared.update(items)
        }
    }
}
