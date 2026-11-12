import Foundation

enum PlannerEditError: LocalizedError {
    case deleted, conflict

    var errorDescription: String? {
        switch self {
        case .deleted: "This task was removed. Close the editor to see the updated library."
        case .conflict: "The same fields changed elsewhere. Reopen the task to review the latest changes."
        }
    }
}

enum PlannerItemEdit {
    // Time, date and their dependent values must describe a single scheduling decision.
    static let linkedFields = [
        ["day", "start", "locked", "reminderOffsetMinutes", "scheduledDuration"],
        ["notes", "richNotes"],
    ]

    static func changedKeys<Value: Equatable>(from old: [String: Value], to new: [String: Value]) -> Set<String> {
        var changes = Set(old.keys).union(new.keys).filter { old[$0] != new[$0] }
        for group in linkedFields where !changes.isDisjoint(with: group) {
            changes.formUnion(group)
        }
        return changes
    }

    static func reconcile(_ draft: PlannerItem, opening: PlannerItem, current: PlannerItem?) throws -> PlannerItem {
        guard let current, current.deleted == opening.deleted, current.id == draft.id else {
            throw PlannerEditError.deleted
        }
        if current == opening { return draft }
        func fields(_ item: PlannerItem) throws -> [String: NSObject] {
            let data = try JSONEncoder().encode(item)
            guard let fields = try JSONSerialization.jsonObject(with: data) as? [String: NSObject] else {
                throw CocoaError(.coderInvalidValue)
            }
            return fields
        }
        let original = try fields(opening)
        let edited = try fields(draft)
        var latest = try fields(current)
        let localChanges = changedKeys(from: original, to: edited)
        let remoteChanges = changedKeys(from: original, to: latest)
        for key in localChanges.intersection(remoteChanges) where latest[key] != edited[key] {
            throw PlannerEditError.conflict
        }
        for key in localChanges { latest[key] = edited[key] }
        return try JSONDecoder().decode(PlannerItem.self, from: JSONSerialization.data(withJSONObject: latest))
    }
}
