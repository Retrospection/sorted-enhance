import CryptoKit
import Foundation

/// Calendar notes can sync with calendar providers. Rich text and files stay in the planner.
struct EventAnnotation: Codable, Equatable {
    var notes = ""
    var richNotes: Data?
    var attachments: [PlannerAttachment] = []

    static func load(for event: PlannerCalendarEvent) throws -> Self {
        let url = try file(for: event)
        do {
            return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Self()
        }
    }

    func write(for event: PlannerCalendarEvent) throws {
        let url = try Self.file(for: event)
        if self == Self() {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }

    private static func file(for event: PlannerCalendarEvent) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        let key = SHA256.hash(data: Data(event.id.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("SortedEnhance/EventNotes/\(key).json")
    }
}
