import Foundation

struct PlannerRecurrence: Codable, Hashable, Sendable {
    enum Frequency: String, Codable, CaseIterable, Sendable {
        case daily, weekly, monthly, yearly
    }

    var frequency: Frequency
    var interval = 1
    var anchor: Date
    var anchorIndex = 0
    var revisionIndex: Int?
    var timeZoneID: String

    init(frequency: Frequency, anchor: Date, timeZone: TimeZone = .current) {
        self.frequency = frequency
        self.anchor = anchor
        timeZoneID = timeZone.identifier
    }

    func template(in members: [PlannerItem]) -> PlannerItem? {
        let revision = members.filter { $0.recurrence == self }
        if let owner = revision.first(where: { $0.revisionDefaults != nil }),
           let defaults = owner.revisionDefaults {
            return defaults.applying(to: owner)
        }
        // Older snapshots did not store revision defaults. Prefer the earliest surviving
        // active member until the next edit freezes the best available baseline.
        let surviving = revision.filter { !$0.deleted }
        let active = surviving.filter { $0.status == .active }
        return (active.isEmpty ? surviving : active).min {
            ($0.occurrenceIndex ?? Int.max) < ($1.occurrenceIndex ?? Int.max)
        }
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }

    func date(at index: Int) -> Date? {
        guard index >= anchorIndex, anchorIndex >= 0, interval > 0 else { return nil }
        let (distance, overflow) = (index - anchorIndex).multipliedReportingOverflow(by: interval)
        guard !overflow else { return nil }
        let unit: Calendar.Component
        switch frequency {
        case .daily: unit = .day
        case .weekly: unit = .weekOfYear
        case .monthly: unit = .month
        case .yearly: unit = .year
        }
        return calendar.date(byAdding: unit, value: distance, to: anchor)
    }

    func firstIndex(after instant: Date) -> Int? {
        guard interval > 0, anchorIndex >= 0 else { return nil }
        if instant < anchor { return anchorIndex }
        let unit: Calendar.Component
        switch frequency {
        case .daily, .weekly: unit = .day
        case .monthly: unit = .month
        case .yearly: unit = .year
        }
        let calendar = calendar
        guard let origin = calendar.dateInterval(of: unit, for: anchor)?.start,
              let target = calendar.dateInterval(of: unit, for: instant)?.start,
              let units = calendar.dateComponents([unit], from: origin, to: target).value(for: unit)
        else { return nil }
        let steps = frequency == .weekly ? units / 7 : units
        let (index, overflow) = anchorIndex.addingReportingOverflow(steps / interval)
        guard !overflow, index < Int.max, let occurrence = date(at: index) else { return nil }
        return occurrence > instant ? index : index + 1
    }
}

/// Content inherited by new occurrences. Store one copy on the revision's first member.
struct PlannerOccurrenceDefaults: Codable, Hashable, Sendable {
    let title: String
    let notes: String
    let richNotes: Data?
    let attachments: [PlannerAttachment]?
    let hasStartTime: Bool
    let duration: Int
    let locked: Bool
    let listID: UUID?
    let tags: [String]
    let reminderOffsetMinutes: Int?

    init(_ item: PlannerItem) {
        title = item.title
        notes = item.notes
        richNotes = item.richNotes
        attachments = item.attachments
        hasStartTime = item.start != nil
        duration = item.duration
        locked = item.locked
        listID = item.listID
        tags = item.tags
        reminderOffsetMinutes = item.reminderOffsetMinutes
    }

    func applying(to owner: PlannerItem) -> PlannerItem {
        var template = owner
        template.title = title
        template.notes = notes
        template.richNotes = richNotes
        template.attachments = attachments
        template.start = hasStartTime ? owner.recurrence?.anchor : nil
        template.duration = duration
        template.locked = locked
        template.listID = listID
        template.tags = tags
        template.reminderOffsetMinutes = reminderOffsetMinutes
        return template
    }
}
