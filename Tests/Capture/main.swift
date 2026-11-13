import Foundation
import UserNotifications

let calendar = Calendar.current
let parsed = QuickEntry("Send invoice tomorrow at 8am")
precondition(parsed.title == "Send invoice")
precondition(calendar.isDateInTomorrow(parsed.day!))
precondition(calendar.component(.hour, from: parsed.start!) == 8)
precondition(QuickEntry("Read the outline tomorrow").start == nil)
let plain = QuickEntry("Review chapter 12")
precondition(plain.title == "Review chapter 12" && plain.day == nil)
let midnight = QuickEntry("Meet tomorrow at 00:00")
precondition(midnight.start != nil && calendar.component(.hour, from: midnight.start!) == 0)

let now = Date()
var task = PlannerItem(title: "Invoice")
task.start = now.addingTimeInterval(900)
task.reminderOffsetMinutes = 5
let original = PlannerAlert(task, now: now)!
precondition(original.date == now.addingTimeInterval(600))
precondition(original.matches(original.request(sound: .system), sound: .system))

task.start = now.addingTimeInterval(1200)
let postponed = PlannerAlert(task, now: now)!
precondition(postponed.identifier == original.identifier)
precondition(!postponed.matches(original.request(sound: .system), sound: .system))
precondition(postponed.date == now.addingTimeInterval(900))
task.status = .completed
precondition(PlannerAlert(task, now: now) == nil)
task.status = .active
task.deleted = true
precondition(PlannerAlert(task, now: now) == nil)

var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(secondsFromGMT: 0)!
let monday = utc.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 10))!
let beforeMonday = monday.addingTimeInterval(-3600)
var recurring = PlannerItem(title: "Morning review")
recurring.start = monday
recurring.recurrence = PlannerRecurrence(frequency: .daily, anchor: monday, timeZone: utc.timeZone)
recurring.seriesID = recurring.id
recurring.occurrenceIndex = 0
recurring.reminderOffsetMinutes = 15
let dailyAlerts = PlannerAlert.plan(for: [recurring], now: beforeMonday)
precondition(dailyAlerts.count == 1)
let dailyAlert = dailyAlerts[0]
let dailyTrigger = dailyAlert.request(sound: .system).trigger as! UNCalendarNotificationTrigger
precondition(dailyTrigger.repeats && dailyTrigger.dateComponents.hour == 9 && dailyTrigger.dateComponents.minute == 45)
precondition(dailyAlert.matches(dailyAlert.request(sound: .system), sound: .system))

var skipped = recurring
skipped.id = UUID()
skipped.start = utc.date(byAdding: .day, value: 1, to: monday)
skipped.occurrenceIndex = 1
skipped.status = .canceled
let adjusted = PlannerAlert.plan(for: [recurring, skipped], now: beforeMonday)
precondition(adjusted.allSatisfy { $0.repeatingComponents == nil })
precondition(!adjusted.contains { $0.date == skipped.start!.addingTimeInterval(-900) })
precondition(adjusted.contains { $0.date == utc.date(byAdding: .day, value: 20, to: monday)!.addingTimeInterval(-900) })

let delayed = PlannerAlert.plan(for: [recurring], now: beforeMonday.addingTimeInterval(-5 * 86400))
precondition(delayed.allSatisfy { $0.repeatingComponents == nil && $0.date >= monday.addingTimeInterval(-900) })
recurring.recurrence?.interval = 2
let alternate = PlannerAlert.plan(for: [recurring], now: beforeMonday)
precondition(alternate.contains { $0.date == monday.addingTimeInterval(12 * 86400 - 900) })
precondition(!alternate.contains { $0.date == monday.addingTimeInterval(11 * 86400 - 900) })

let laterTasks = (0..<70).map { i in
    var item = PlannerItem(title: "Later \(i)")
    item.start = monday.addingTimeInterval(86400 * 150 + Double(i * 60))
    item.reminderOffsetMinutes = 0
    return item
}
let crowded = PlannerAlert.plan(for: [recurring] + laterTasks, now: beforeMonday)
precondition(crowded.count == 64)
precondition(crowded.map(\.date) == (0..<64).map { monday.addingTimeInterval(Double($0) * 2 * 86400 - 900) })
let refilled = PlannerAlert.plan(for: [recurring] + laterTasks, now: monday)
precondition(refilled.count == 64)
precondition(refilled.last?.date == monday.addingTimeInterval(64 * 2 * 86400 - 900))

var retired = recurring
retired.id = UUID()
retired.title = "Removed title"
retired.reminderOffsetMinutes = nil
retired.start = monday.addingTimeInterval(2 * 86400 * 7)
retired.occurrenceIndex = 7
retired.deleted = true
let restarted = PlannerAlert.plan(for: [recurring, retired], now: beforeMonday)
precondition(restarted.contains { $0.title == "Morning review" && $0.date == monday.addingTimeInterval(16 * 86400 - 900) })
precondition(!restarted.contains { $0.date == retired.start!.addingTimeInterval(-900) })

let quietRequest = dailyAlert.request(sound: .silent)
precondition(quietRequest.content.sound == nil)
precondition(dailyAlert.matches(quietRequest, sound: .silent))
precondition(!dailyAlert.matches(quietRequest, sound: .system))
precondition(!dailyAlert.matches(dailyAlert.request(sound: .system), sound: .silent))

let unrelated = UNNotificationRequest(identifier: "another-feature", content: UNMutableNotificationContent(), trigger: nil)
let pending = [quietRequest, unrelated]
let disabled = PlannerAlert.changes(for: [], pending: pending, sound: .system, now: beforeMonday)
precondition(disabled.remove == [dailyAlert.identifier] && disabled.schedule.isEmpty)
let soundChanged = PlannerAlert.changes(for: [dailyAlert], pending: pending, sound: .system, now: beforeMonday)
precondition(soundChanged.remove.isEmpty && soundChanged.schedule == [dailyAlert])
let restored = PlannerAlert.changes(for: [dailyAlert], pending: [unrelated], sound: .silent, now: beforeMonday)
precondition(restored.remove.isEmpty && restored.schedule == [dailyAlert])
let unchanged = PlannerAlert.changes(for: [dailyAlert], pending: pending, sound: .silent, now: beforeMonday)
precondition(unchanged.remove.isEmpty && unchanged.schedule.isEmpty)

var anytime = PlannerItem(title: "Anytime today")
anytime.day = utc.startOfDay(for: monday)
var yesterday = PlannerItem(title: "Yesterday")
yesterday.day = monday.addingTimeInterval(-24 * 3600)
var earlier = PlannerItem(title: "Earlier today")
earlier.start = monday.addingTimeInterval(-1)
var later = PlannerItem(title: "Later today")
later.start = monday.addingTimeInterval(3600)
var finished = earlier
finished.status = .completed
var trashed = earlier
trashed.deleted = true
let badgeItems = [anytime, yesterday, earlier, later, finished, trashed, PlannerItem(title: "Undated")]
precondition(PlannerBadgeMode.off.count(in: badgeItems, now: monday, calendar: utc) == 0)
precondition(PlannerBadgeMode.overdue.count(in: badgeItems, now: monday, calendar: utc) == 2)
precondition(PlannerBadgeMode.overdueAndAnytime.count(in: badgeItems, now: monday, calendar: utc) == 3)
precondition(PlannerBadgeMode.today.count(in: badgeItems, now: monday, calendar: utc) == 3)
let tomorrow = monday.addingTimeInterval(24 * 3600)
precondition(PlannerBadgeMode.overdue.count(in: badgeItems, now: tomorrow, calendar: utc) == 4)
precondition(PlannerBadgeMode.today.count(in: badgeItems, now: tomorrow, calendar: utc) == 0)
