import CryptoKit
import Foundation

struct EventAnnotationIdentity: Hashable {
    let localID: String
    let externalID: String?
    let sourceID: String
    let calendarID: String
    let occurrenceKey: String
    let legacyKey: String

    init(localID: String, externalID: String?, sourceID: String, calendarID: String,
         occurrence: Date?, floating: Bool, timeZone: TimeZone) {
        self.localID = localID
        self.externalID = externalID.flatMap { $0.isEmpty ? nil : $0 }
        self.sourceID = sourceID
        self.calendarID = calendarID
        let timestamp = occurrence.map { String($0.timeIntervalSinceReferenceDate) } ?? "single"
        legacyKey = "\(localID):\(timestamp)"
        if floating, let occurrence {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: occurrence)
            occurrenceKey = "\(parts.year!)-\(parts.month!)-\(parts.day!)/\(parts.hour!):\(parts.minute!):\(parts.second!)"
        } else {
            occurrenceKey = timestamp
        }
    }
}

struct EventAnnotation: Codable, Equatable {
    var notes = ""
    var richNotes: Data?
    var attachments: [PlannerAttachment] = []
}

/// Scope a provider ID to its account, calendar, and occurrence before reconciling a changed local ID.
struct EventAnnotationStore {
    let directory: URL

    static func applicationStore() throws -> Self {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        return Self(directory: root.appendingPathComponent("SortedEnhance/EventNotes"))
    }

    func load(_ identity: EventAnnotationIdentity, uniqueProviderMatch: Bool) throws -> EventAnnotation {
        let file = record(for: identity)
        if let annotation = try read(file) { return annotation }
        let legacy = legacyFile(identity)
        if let annotation = try read(legacy) {
            try write(annotation, for: identity)
            return annotation
        }

        guard identity.externalID != nil, uniqueProviderMatch else { return EventAnnotation() }
        let siblings: [URL]
        do {
            siblings = try FileManager.default.contentsOfDirectory(at: file.deletingLastPathComponent(),
                                                                    includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return EventAnnotation()
        }
        guard siblings.count == 1, let previous = siblings.first,
              let annotation = try read(previous) else { return EventAnnotation() }
        try FileManager.default.moveItem(at: previous, to: file)
        return annotation
    }

    func write(_ annotation: EventAnnotation, for identity: EventAnnotationIdentity) throws {
        let file = record(for: identity)
        if annotation == EventAnnotation() {
            try removeIfPresent(legacyFile(identity))
            try removeIfPresent(file)
        } else {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(annotation).write(to: file, options: .atomic)
            try removeIfPresent(legacyFile(identity))
        }
    }

    func record(for identity: EventAnnotationIdentity) -> URL {
        let scope = [identity.sourceID, identity.calendarID, identity.externalID ?? identity.localID, identity.occurrenceKey]
            .map { "\($0.utf8.count):\($0)" }.joined()
        return directory.appendingPathComponent(digest(scope)).appendingPathComponent(digest(identity.localID) + ".json")
    }

    private func legacyFile(_ identity: EventAnnotationIdentity) -> URL {
        directory.appendingPathComponent(digest(identity.legacyKey) + ".json")
    }

    private func digest(_ string: String) -> String {
        SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func read(_ url: URL) throws -> EventAnnotation? {
        do { return try JSONDecoder().decode(EventAnnotation.self, from: Data(contentsOf: url)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
    }

    private func removeIfPresent(_ url: URL) throws {
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile {}
    }
}
