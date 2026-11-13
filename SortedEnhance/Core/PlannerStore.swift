import Combine
import Foundation

@MainActor
final class PlannerStore: ObservableObject {
    static let shared = PlannerStore()

    @Published private(set) var snapshot = PlannerSnapshot()
    @Published var errorMessage: String?

    var items: [PlannerItem] { snapshot.items }
    var folders: [PlannerFolder] { snapshot.folders }
    var lists: [PlannerList] { snapshot.lists }
    var tags: [String] {
        var names = Dictionary(uniqueKeysWithValues: snapshot.savedTags.map { ($0.id, $0.name) })
        for item in items where !item.deleted {
            for name in item.tags {
                let key = PlannerTag.key(name)
                if names[key] == nil { names[key] = name }
            }
        }
        return names.values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var canUndo: Bool { !past.isEmpty }
    var canRedo: Bool { !future.isEmpty }
    var libraryIsReadable: Bool { !readFailed }

    private let fileURL: URL
    private var past: [PlannerSnapshot] = []
    private var future: [PlannerSnapshot] = []
    private var readFailed = false

    convenience init() {
        let directory = URL.applicationSupportDirectory
            .appending(path: "SortedEnhance", directoryHint: .isDirectory)
        self.init(fileURL: directory.appending(path: "planner.json"))
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        do {
            let data = try Data(contentsOf: fileURL)
            let saved = try JSONDecoder().decode(PlannerSnapshot.self, from: data)
            try saved.validate()
            snapshot = saved
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // An empty library has no file until its first edit.
        } catch {
            readFailed = true
            errorMessage = "Could not open the planner. Restore a backup to continue. " + error.localizedDescription
        }
    }

    @discardableResult
    func save(_ item: PlannerItem) -> Bool {
        save([item])
    }

    @discardableResult
    func save(_ changed: [PlannerItem]) -> Bool {
        var next = snapshot
        var positions = Dictionary(uniqueKeysWithValues: next.items.indices.map { (next.items[$0].id, $0) })
        var largestOrder = next.items.lazy.map(\.order).filter { $0 < Int.max }.max() ?? -1
        let now = Date.now
        for var item in changed {
            let previous = positions[item.id].map { next.items[$0] }
            if item.status == .active {
                item.closedAt = nil
            } else if previous?.status != item.status {
                item.closedAt = now
            } else {
                item.closedAt = previous?.closedAt
            }
            if !item.deleted {
                item.deletedAt = nil
            } else if previous?.deleted != true {
                item.deletedAt = now
            } else {
                item.deletedAt = previous?.deletedAt
            }
            if item.order == Int.max {
                if let position = positions[item.id] {
                    item.order = next.items[position].order
                } else {
                    largestOrder = min(largestOrder, Int.max - 2) + 1
                    item.order = largestOrder
                }
            }
            if let position = positions[item.id] {
                next.items[position] = item
            } else {
                positions[item.id] = next.items.count
                next.items.append(item)
            }
            if item.order < Int.max {
                largestOrder = max(largestOrder, item.order)
            }
        }
        return commit(next)
    }

    @discardableResult
    func emptyTrash() -> Bool {
        var next = snapshot
        next.items = next.items.compactMap { item in
            guard item.inTrash else { return item }
            guard item.seriesID != nil else { return nil }
            // Keep the occupied index and revision boundary so this occurrence stays deleted.
            var marker = PlannerItem(title: "")
            marker.id = item.id
            marker.order = item.order
            marker.deleted = true
            marker.purged = true
            marker.seriesID = item.seriesID
            marker.occurrenceIndex = item.occurrenceIndex
            marker.recurrence = item.recurrence
            marker.revisionDefaults = item.revisionDefaults
            return marker
        }
        return commit(next)
    }

    @discardableResult
    func addTag(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let tag = PlannerTag(trimmed)
        guard !tags.contains(where: { PlannerTag.key($0) == tag.id }) else { return true }
        var next = snapshot
        next.savedTags.append(tag)
        return commit(next)
    }

    @discardableResult
    func replaceOrganization(folders: [PlannerFolder], lists: [PlannerList]) -> Bool {
        var next = snapshot
        next.folders = folders
        next.lists = lists
        return commit(next)
    }

    @discardableResult
    func restore(_ items: [PlannerItem]) -> Bool {
        restore(PlannerSnapshot(items: items, folders: folders, lists: lists, savedTags: snapshot.savedTags))
    }

    @discardableResult
    func restore(_ items: [PlannerItem], folders: [PlannerFolder], lists: [PlannerList]) -> Bool {
        restore(PlannerSnapshot(items: items, folders: folders, lists: lists, savedTags: snapshot.savedTags))
    }

    @discardableResult
    func restore(_ saved: PlannerSnapshot) -> Bool {
        commit(saved, recovery: true)
    }

    @discardableResult
    func applySyncedSnapshot(_ merged: PlannerSnapshot) -> Bool {
        // Timeline and collection order are explicit record fields. JSON array order
        // can change in transit without representing a remote edit.
        if Set(merged.items) == Set(items), Set(merged.folders) == Set(folders),
           Set(merged.lists) == Set(lists), Set(merged.savedTags) == Set(snapshot.savedTags) {
            return true
        }
        guard libraryIsReadable, write(merged) else { return false }
        past.removeAll()
        future.removeAll()
        snapshot = merged
        return true
    }

    @discardableResult
    func undo() -> Bool {
        guard let previous = past.last, write(previous) else { return false }
        past.removeLast()
        future.append(snapshot)
        snapshot = previous
        return true
    }

    @discardableResult
    func redo() -> Bool {
        guard let next = future.last, write(next) else { return false }
        future.removeLast()
        past.append(snapshot)
        snapshot = next
        return true
    }

    private func commit(_ next: PlannerSnapshot, recovery: Bool = false) -> Bool {
        guard !readFailed || recovery else {
            errorMessage = "Restore a backup before changing this library."
            return false
        }
        guard next != snapshot || readFailed else { return true }
        guard write(next) else { return false }
        if !readFailed {
            past.append(snapshot)
            if past.count > 50 { past.removeFirst() }
        }
        readFailed = false
        future.removeAll()
        snapshot = next
        return true
    }

    private func write(_ next: PlannerSnapshot) -> Bool {
        do {
            try next.validate()
            let data = try JSONEncoder().encode(next)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Could not save the planner. " + error.localizedDescription
            return false
        }
    }
}
