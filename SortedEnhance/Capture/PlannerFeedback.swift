import AppKit
import Foundation

enum PlannerFeedbackKey {
    static let alerts = "planner.alerts.enabled"
    static let sound = "planner.alerts.sound"
    static let completion = "planner.sounds.completion"
    static let badge = "planner.dock.badge"
}

enum TaskAlertSound: String {
    case system, silent
}

enum PlannerBadgeMode: String {
    case off, overdue, overdueAndAnytime, today

    func count(in items: [PlannerItem], now: Date, calendar: Calendar = .current) -> Int {
        guard self != .off else { return 0 }
        let today = calendar.startOfDay(for: now)
        return items.lazy.filter { item in
            guard item.status == .active, !item.deleted,
                  let day = item.start ?? item.day else { return false }
            let isToday = calendar.isDate(day, inSameDayAs: now)
            if self == .today { return isToday }
            if let start = item.start { return start <= now }
            return day < today || (self == .overdueAndAnytime && isToday)
        }.count
    }
}

struct PlannerFeedback: Equatable {
    let alertsEnabled: Bool
    let alertSound: TaskAlertSound
    let badgeMode: PlannerBadgeMode

    init(defaults: UserDefaults = .standard) {
        alertsEnabled = defaults.object(forKey: PlannerFeedbackKey.alerts) as? Bool ?? true
        alertSound = defaults.string(forKey: PlannerFeedbackKey.sound).flatMap(TaskAlertSound.init(rawValue:)) ?? .system
        badgeMode = defaults.string(forKey: PlannerFeedbackKey.badge).flatMap(PlannerBadgeMode.init(rawValue:)) ?? .overdue
    }

    @MainActor static func playCompletion() {
        guard UserDefaults.standard.object(forKey: PlannerFeedbackKey.completion) as? Bool ?? true else { return }
        NSSound(named: NSSound.Name("Pop"))?.play()
    }
}
