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
