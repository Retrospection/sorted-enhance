import Foundation

enum PlannerStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active, completed, canceled
}

struct PlannerAttachment: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var data: Data
}

struct PlannerItem: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var notes = ""
    var richNotes: Data?
    var attachments: [PlannerAttachment]?
    var day: Date?
    var start: Date?
    var duration = 30
    var locked = false
    var status = PlannerStatus.active
    var deleted = false
    var listID: UUID?
    var tags: [String] = []
    var order = Int.max
    var recurrence: PlannerRecurrence?
    var seriesID: UUID?
    var occurrenceIndex: Int?
    var reminderOffsetMinutes: Int?
}

struct PlannerFolder: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var order = 0
}

struct PlannerList: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var folderID: UUID?
    var order = 0
}

struct PlannerSnapshot: Codable, Hashable, Sendable {
    var items: [PlannerItem] = []
    var folders: [PlannerFolder] = []
    var lists: [PlannerList] = []

    func validate() throws {
        let folderIDs = Set(folders.map(\.id))
        let listIDs = Set(lists.map(\.id))
        guard folderIDs.count == folders.count,
              listIDs.count == lists.count,
              Set(items.map(\.id)).count == items.count,
              lists.allSatisfy({ $0.folderID.map(folderIDs.contains) ?? true }),
              items.allSatisfy({ $0.listID.map(listIDs.contains) ?? true }) else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [
                NSLocalizedDescriptionKey: "The planner contains duplicate IDs or missing folders or lists."
            ])
        }
        var occurrences: [UUID: Set<Int>] = [:]
        for item in items {
            if let series = item.seriesID, let index = item.occurrenceIndex,
               index >= 0, occurrences[series, default: []].insert(index).inserted {
                if let rule = item.recurrence, rule.interval <= 0 || rule.anchorIndex < 0 {
                    throw CocoaError(.fileReadCorruptFile)
                }
            } else if item.seriesID != nil || item.occurrenceIndex != nil || item.recurrence != nil {
                throw CocoaError(.fileReadCorruptFile)
            }
        }
    }
}
