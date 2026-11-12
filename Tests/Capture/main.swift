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
precondition(original.matches(original.request))

task.start = now.addingTimeInterval(1200)
let postponed = PlannerAlert(task, now: now)!
precondition(postponed.identifier == original.identifier)
precondition(!postponed.matches(original.request))
precondition(postponed.date == now.addingTimeInterval(900))
task.status = .completed
precondition(PlannerAlert(task, now: now) == nil)
task.status = .active
task.deleted = true
precondition(PlannerAlert(task, now: now) == nil)
