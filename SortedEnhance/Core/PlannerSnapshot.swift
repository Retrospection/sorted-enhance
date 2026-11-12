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
    var duration: Int?
    var scheduledDuration: Int?
    var locked = false
    var status = PlannerStatus.active
    var deleted = false
    var closedAt: Date?
    var deletedAt: Date?
    var purged: Bool?

    var inTrash: Bool { deleted && purged != true }
    var listID: UUID?
    var tags: [String] = []
    var order = Int.max
    var recurrence: PlannerRecurrence?
    var seriesID: UUID?
    var occurrenceIndex: Int?
    var revisionDefaults: PlannerOccurrenceDefaults?
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

struct PlannerTag: Codable, Hashable, Sendable {
    let id: String
    let name: String

    init(_ name: String) {
        self.name = name
        id = Self.key(name)
    }

    static func key(_ name: String) -> String {
        name.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
    }
}

struct PlannerSnapshot: Codable, Hashable, Sendable {
    var items: [PlannerItem] = []
    var folders: [PlannerFolder] = []
    var lists: [PlannerList] = []
    var savedTags: [PlannerTag] = []

    func validate() throws {
        let folderIDs = Set(folders.map(\.id))
        let listIDs = Set(lists.map(\.id))
        let validTagNames = savedTags.allSatisfy { tag in
            let trimmed = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && trimmed == tag.name && PlannerTag.key(trimmed) == tag.id
        }
        guard validTagNames, Set(savedTags.map(\.id)).count == savedTags.count else {
            throw CocoaError(.fileReadCorruptFile)
        }
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

// Earlier libraries and backups did not store tags independently of tasks.
extension PlannerSnapshot {
    init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        items = try fields.decode([PlannerItem].self, forKey: .items)
        folders = try fields.decode([PlannerFolder].self, forKey: .folders)
        lists = try fields.decode([PlannerList].self, forKey: .lists)
        savedTags = try fields.decodeIfPresent([PlannerTag].self, forKey: .savedTags) ?? []
    }
}
