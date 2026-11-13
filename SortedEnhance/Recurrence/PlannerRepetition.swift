import CryptoKit
import Foundation

enum RecurrenceScope: Hashable {
    case occurrence, future
}

enum PlannerRepetition {
    static func edit(
        _ edited: PlannerItem,
        original: PlannerItem,
        in items: [PlannerItem],
        scope: RecurrenceScope,
        now: Date = .now
    ) -> [PlannerItem] {
        if original.seriesID == nil {
            guard var rule = edited.recurrence else { return [edited] }
            var first = edited
            first.revisionDefaults = PlannerOccurrenceDefaults(edited)
            first.seriesID = first.id
            first.occurrenceIndex = 0
            anchor(&rule, on: &first)
            return [first] + following(first, through: now)
        }
        guard let index = original.occurrenceIndex else { return [edited] }
        let siblings = items.filter { $0.seriesID == original.seriesID }
        // Freeze a legacy revision before an edit can overwrite the only surviving baseline.
        var legacyOwner: PlannerItem?
        if let oldRule = original.recurrence {
            let revision = siblings.filter { $0.recurrence == oldRule }
            if !revision.contains(where: { $0.revisionDefaults != nil }),
               var owner = revision.min(by: { ($0.occurrenceIndex ?? 0) < ($1.occurrenceIndex ?? 0) }),
               let source = oldRule.template(in: revision) {
                owner.revisionDefaults = PlannerOccurrenceDefaults(source)
                legacyOwner = owner
            }
        }
        if scope == .occurrence {
            var occurrence = edited
            occurrence.recurrence = original.recurrence
            occurrence.revisionDefaults = original.revisionDefaults
            if let owner = legacyOwner {
                if owner.id != occurrence.id { return [owner, occurrence] }
                occurrence.revisionDefaults = owner.revisionDefaults
            }
            return [occurrence]
        }

        let retained = legacyOwner.flatMap { ($0.occurrenceIndex ?? 0) < index ? [$0] : nil } ?? []
        var first = edited
        let later = siblings.filter { ($0.occurrenceIndex ?? 0) > index }
        guard !edited.deleted, var rule = first.recurrence else {
            first.recurrence = nil
            first.revisionDefaults = nil
            return retained + [first] + later.map { item in
                var stopped = item
                stopped.recurrence = nil
                stopped.revisionDefaults = nil
                if stopped.status == .active { stopped.deleted = true }
                return stopped
            }
        }
        if first.day != original.day || first.start != original.start || rule != original.recurrence {
            anchor(&rule, on: &first)
        }
        first.revisionDefaults = PlannerOccurrenceDefaults(first)
        rule.revisionIndex = index
        first.recurrence = rule
        let generated = following(first, through: now, including: later.compactMap(\.occurrenceIndex))
        let byIndex = Dictionary(grouping: later, by: \.occurrenceIndex)
        return retained + [first] + generated.map { next in
            guard var existing = byIndex[next.occurrenceIndex]?.first else { return next }
            if existing.status != .active || existing.deleted {
                existing.recurrence = rule
                existing.revisionDefaults = nil
                return existing
            }
            var replacement = next
            replacement.id = existing.id
            return replacement
        }
    }

    static func upcoming(in items: [PlannerItem], through date: Date = .now) -> [PlannerItem] {
        let series = Dictionary(grouping: items.filter { $0.seriesID != nil }, by: \.seriesID)
        return series.values.flatMap { members -> [PlannerItem] in
            let ordered = members.sorted { ($0.occurrenceIndex ?? 0) < ($1.occurrenceIndex ?? 0) }
            let occupied = Set(ordered.compactMap(\.occurrenceIndex))
            var additions: [PlannerItem] = []
            var upperBound: Int?
            for template in ordered.reversed() {
                guard let index = template.occurrenceIndex else { continue }
                guard let rule = template.recurrence else {
                    upperBound = index
                    continue
                }
                let lowerBound = rule.revisionIndex ?? rule.anchorIndex
                guard upperBound.map({ lowerBound < $0 }) ?? true else { continue }
                let indices = window(for: rule, around: date).filter { candidate in
                    candidate >= lowerBound && !occupied.contains(candidate) &&
                        (upperBound.map { candidate < $0 } ?? true)
                }
                if !indices.isEmpty, let source = rule.template(in: members) {
                    additions += occurrences(source, indices: indices)
                }
                upperBound = lowerBound
            }
            return additions
        }
    }

    private static func anchor(_ rule: inout PlannerRecurrence, on item: inout PlannerItem) {
        rule.anchor = item.start ?? item.day ?? rule.anchor
        rule.anchorIndex = item.occurrenceIndex ?? 0
        item.day = rule.calendar.startOfDay(for: rule.anchor)
        item.recurrence = rule
    }

    private static func following(
        _ template: PlannerItem,
        through date: Date,
        including existingIndices: [Int] = []
    ) -> [PlannerItem] {
        guard let rule = template.recurrence, let index = template.occurrenceIndex, index < Int.max - 3 else { return [] }
        var indices = Set(existingIndices)
        indices.formUnion((index + 1)...(index + 3))
        indices.formUnion(window(for: rule, around: date).filter { $0 > index })
        return occurrences(template, indices: indices.sorted())
    }

    // Generate a bounded window. Selecting an older date can fill that part of the series later.
    private static func window(for rule: PlannerRecurrence, around date: Date) -> [Int] {
        guard let next = rule.firstIndex(after: date), next < Int.max - 3 else { return [] }
        let index = next - 1
        // Include missed work near the selected date and three upcoming occurrences.
        return Array(max(rule.anchorIndex, index - 31)...(index + 3))
    }

    private static func occurrences(_ template: PlannerItem, indices: [Int]) -> [PlannerItem] {
        guard let rule = template.recurrence, let seriesID = template.seriesID else { return [] }
        let calendar = rule.calendar
        return indices.compactMap { index in
            guard let date = rule.date(at: index) else { return nil }
            var item = template
            item.revisionDefaults = nil
            item.id = occurrenceID(seriesID: seriesID, index: index)
            item.occurrenceIndex = index
            item.day = calendar.startOfDay(for: date)
            item.start = template.start == nil ? nil : date
            item.status = .active
            item.deleted = false
            item.closedAt = nil
            item.deletedAt = nil
            item.purged = nil
            return item
        }
    }

    // Two offline devices must give the same occurrence the same identity.
    private static func occurrenceID(seriesID: UUID, index: Int) -> UUID {
        let bytes = Array(SHA256.hash(data: Data("\(seriesID.uuidString)/\(index)".utf8)).prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5],
            (bytes[6] & 0x0f) | 0x80, bytes[7], (bytes[8] & 0x3f) | 0x80,
            bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
