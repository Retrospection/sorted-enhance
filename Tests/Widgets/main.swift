import Foundation

let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
defer { try? FileManager.default.removeItem(at: file) }

let list = PlannerList(name: "Launch")
var task = PlannerItem(title: "Review notes")
task.listID = list.id
task.tags = ["Work"]
var hidden = PlannerItem(title: "Discarded")
hidden.deleted = true
var library = PlannerSnapshot(items: [task, hidden], lists: [list])
let firstExport = try WidgetSnapshot.export(library, to: file)
precondition(firstExport)
library.items[0].title = "Review release"
_ = try WidgetSnapshot.export(library, to: file)

let exported = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: file))
precondition(exported.tasks.map(\.title) == ["Review release"])
precondition(exported.tasks.first?.listID == list.id && exported.lists.first?.name == "Launch")
precondition(exported.tasks.first?.tags == ["Work"])
precondition(exported.tasks.first?.link.absoluteString == "sorted-enhance://item/\(task.id.uuidString)")

library.items[0].status = .completed
_ = try WidgetSnapshot.export(library, to: file)
let afterCompletion = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: file))
precondition(afterCompletion.tasks.isEmpty)

// Keep the exported file fixed while the widget advances beyond the app's last generated week.
let anchor = ISO8601DateFormatter().date(from: "2026-01-01T10:00:00Z")!
var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(secondsFromGMT: 0)!
var weekly = PlannerItem(title: "Stand-up")
weekly.day = utc.startOfDay(for: anchor)
weekly.start = anchor
weekly.recurrence = PlannerRecurrence(frequency: .weekly, anchor: anchor, timeZone: utc.timeZone)
let members = PlannerRepetition.edit(weekly, original: PlannerItem(title: weekly.title), in: [], scope: .future, now: anchor)
_ = try WidgetSnapshot.export(PlannerSnapshot(items: members), to: file)
let frozen = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: file))
let weekTen = utc.date(byAdding: .weekOfYear, value: 10, to: anchor)!
let result = frozen.tasks(on: weekTen, calendar: utc)
precondition(result.count == 1 && result[0].title == "Stand-up" && result[0].start == weekTen)
let materialized = PlannerRepetition.upcoming(in: members, through: weekTen).first { $0.start == weekTen }!
precondition(result[0].link.lastPathComponent == materialized.id.uuidString)

var skipped = materialized
skipped.status = .canceled
_ = try WidgetSnapshot.export(PlannerSnapshot(items: members + [skipped]), to: file)
let afterSkip = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: file))
precondition(afterSkip.tasks(on: weekTen, calendar: utc).isEmpty)
