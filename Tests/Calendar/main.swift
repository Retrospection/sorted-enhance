import CryptoKit
import EventKit
import Foundation

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

var newYork = Calendar(identifier: .gregorian)
newYork.timeZone = TimeZone(identifier: "America/New_York")!
let iso = ISO8601DateFormatter()
let fallBack = iso.date(from: "2026-11-01T12:00:00Z")!
let secondOccurrence = iso.date(from: "2026-11-01T06:30:37Z")!
precondition(newYork.date(on: fallBack, at: "01:30", preserving: secondOccurrence) == secondOccurrence,
             "Unchanged wall time must preserve the second occurrence and its seconds.")
precondition(newYork.date(on: fallBack, at: "02:15", preserving: secondOccurrence) ==
             iso.date(from: "2026-11-01T07:15:00Z"))
let followingDay = iso.date(from: "2026-11-02T12:00:00Z")!
precondition(newYork.date(on: followingDay, at: "01:30", preserving: secondOccurrence) ==
             iso.date(from: "2026-11-02T06:30:00Z"))
let springForward = iso.date(from: "2026-03-08T12:00:00Z")!
precondition(newYork.date(on: springForward, at: "02:30", preserving: nil) == nil)

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

let task = PlannerItem(title: "Trip")
let first = Date(timeIntervalSince1970: 1_800_000_000)
let last = first.addingTimeInterval(3 * 86_400)
let options = EventCreationDraft(taskID: task.id, calendarID: "travel", repeatFrequency: .weekly,
                                 allDay: true, lastDay: last, calendarNotes: "Provider note")
var editedTask = task
editedTask.title = "New trip"
let resumed = EventCreationDraft.fields(for: editedTask, previous: options, defaultCalendarID: "default", start: first)
precondition(resumed.calendarID == "travel" && resumed.repeatFrequency == .weekly && resumed.allDay)
precondition(resumed.lastDay == last && resumed.calendarNotes == "Provider note")
let unrelated = EventCreationDraft.fields(for: PlannerItem(title: "Next"), previous: options,
                                         defaultCalendarID: "default", start: first)
precondition(unrelated.calendarID == "default" && unrelated.repeatFrequency == nil && !unrelated.allDay)
precondition(unrelated.lastDay == first && unrelated.calendarNotes.isEmpty)

let event = EKEvent(eventStore: EKEventStore())
event.addAlarm(EKAlarm(relativeOffset: -300))
event.addAlarm(EKAlarm(relativeOffset: -900))
event.addAlarm(EKAlarm(absoluteDate: first))
let audio = EKAlarm(relativeOffset: -1_200)
audio.soundName = "Basso"
event.addAlarm(audio)
precondition(EventAlerts.editable(in: event).count == 2)
EventAlerts.replace(in: event, minutesBefore: nil)
precondition(EventAlerts.editable(in: event).isEmpty)
precondition(event.alarms?.count == 2 && event.alarms?.contains(where: { $0.absoluteDate == first }) == true)
precondition(event.alarms?.contains(where: { $0.soundName == "Basso" }) == true)
