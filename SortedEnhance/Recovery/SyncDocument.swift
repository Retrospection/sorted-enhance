import Foundation

/// A device changes only the fields that differ from its last applied snapshot.
/// Lamport counters preserve causal order; the writer ID breaks concurrent ties.
struct SyncDocument: Codable, Equatable, Sendable {
    struct Field: Codable, Equatable {
        var counter: Int
        var writer: UUID
        var value: Data?

        func precedes(_ other: Self) -> Bool {
            counter == other.counter ? writer.uuidString < other.writer.uuidString : counter < other.counter
        }
    }

    private var groups: [String: [String: [String: Field]]] = [:]
    private var clock = 0

    mutating func record(_ snapshot: PlannerSnapshot, after previous: PlannerSnapshot, writer: UUID) throws {
        let before = try Self.records(previous)
        let after = try Self.records(snapshot)
        guard before != after else { return }
        guard clock < Int.max else { throw CocoaError(.coderInvalidValue) }
        clock += 1
        for group in Self.groupNames {
            let old = before[group] ?? [:]
            let new = after[group] ?? [:]
            for id in Set(old.keys).union(new.keys) where old[id] != new[id] {
                let original = old[id] ?? [:]
                let updated = new[id] ?? [:]
                let changed = group == "items"
                    ? PlannerItemEdit.changedKeys(from: original, to: updated)
                    : Set(original.keys).union(updated.keys).filter { original[$0] != updated[$0] }
                for key in changed {
                    groups[group, default: [:]][id, default: [:]][key] =
                        Field(counter: clock, writer: writer, value: updated[key])
                }
            }
        }
    }

    mutating func merge(_ other: Self) {
        clock = max(clock, other.clock)
        for (group, records) in other.groups {
            for (id, fields) in records {
                for (key, incoming) in fields {
                    if let current = groups[group]?[id]?[key], !current.precedes(incoming) { continue }
                    groups[group, default: [:]][id, default: [:]][key] = incoming
                }
            }
        }
    }

    func snapshot() throws -> PlannerSnapshot {
        var result: [String: [[String: Any]]] = [:]
        for name in Self.groupNames {
            let records = groups[name] ?? [:]
            result[name] = try records.keys.sorted().compactMap { id in
                guard let fields = records[id], fields["id"]?.value != nil else { return nil }
                return try fields.compactMapValues {
                    try $0.value.map { try JSONSerialization.jsonObject(with: $0, options: .fragmentsAllowed) }
                }
            }
        }
        var snapshot = try JSONDecoder().decode(PlannerSnapshot.self, from: JSONSerialization.data(withJSONObject: result))
        // A concurrent deletion of a collection must not make another Mac's new task unreadable.
        let listIDs = Set(snapshot.lists.map(\.id))
        let folderIDs = Set(snapshot.folders.map(\.id))
        for index in snapshot.items.indices {
            if let id = snapshot.items[index].listID, !listIDs.contains(id) { snapshot.items[index].listID = nil }
        }
        for index in snapshot.lists.indices {
            if let id = snapshot.lists[index].folderID, !folderIDs.contains(id) { snapshot.lists[index].folderID = nil }
        }
        try snapshot.validate()
        return snapshot
    }

    private typealias Records = [String: [String: [String: Data]]]
    private static let groupNames = ["items", "folders", "lists"]

    private static func records(_ snapshot: PlannerSnapshot) throws -> Records {
        let data = try JSONEncoder().encode(snapshot)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]] else {
            throw CocoaError(.coderReadCorrupt)
        }
        var result: Records = [:]
        for group in groupNames {
            guard let rows = object[group] else { throw CocoaError(.coderReadCorrupt) }
            for row in rows {
                guard let id = row["id"] as? String, result[group]?[id] == nil else { throw CocoaError(.coderReadCorrupt) }
                result[group, default: [:]][id] = try row.mapValues {
                    try JSONSerialization.data(withJSONObject: $0, options: [.fragmentsAllowed, .sortedKeys])
                }
            }
        }
        return result
    }
}
