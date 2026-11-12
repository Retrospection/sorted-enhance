import CryptoKit
import Foundation

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

func occurrence(_ localID: String, timeZone: String, day: Int = 13, calendarID: String = "work") -> EventAnnotationIdentity {
    let zone = TimeZone(identifier: timeZone)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: day))!
    return EventAnnotationIdentity(localID: localID, externalID: "uid-42", sourceID: "test-account",
                                   calendarID: calendarID, occurrence: midnight, floating: true, timeZone: zone)
}

let files = EventAnnotationStore(directory: directory)
let original = occurrence("local-A", timeZone: "Asia/Tokyo")
let legacyName = SHA256.hash(data: Data(original.legacyKey.utf8)).map { String(format: "%02x", $0) }.joined() + ".json"
let note = EventAnnotation(notes: "Agenda", richNotes: Data([1]), attachments: [
    PlannerAttachment(name: "agenda.txt", data: Data("discuss proposal".utf8))
])
try JSONEncoder().encode(note).write(to: directory.appendingPathComponent(legacyName))
let migrated = try files.load(original, uniqueProviderMatch: true)
precondition(migrated == note)
precondition(!FileManager.default.fileExists(atPath: directory.appendingPathComponent(legacyName).path))

let shifted = try files.load(occurrence("local-A", timeZone: "America/New_York"), uniqueProviderMatch: true)
precondition(shifted == note)
let nextDay = try files.load(occurrence("local-A", timeZone: "America/New_York", day: 14), uniqueProviderMatch: true)
precondition(nextDay == EventAnnotation())

let replacement = occurrence("local-B", timeZone: "Europe/Helsinki")
let ambiguous = try files.load(replacement, uniqueProviderMatch: false)
precondition(ambiguous == EventAnnotation())
let resynced = try files.load(replacement, uniqueProviderMatch: true)
precondition(resynced == note)
let otherCalendar = try files.load(occurrence("local-C", timeZone: "Europe/Helsinki", calendarID: "copy"),
                                   uniqueProviderMatch: true)
precondition(otherCalendar == EventAnnotation())
