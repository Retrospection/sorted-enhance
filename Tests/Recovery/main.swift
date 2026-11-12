import Foundation

let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
defer { try? FileManager.default.removeItem(at: temporary) }

let first = RecoveryFiles(directory: temporary.appending(path: "MacA"))
let second = RecoveryFiles(directory: temporary.appending(path: "MacB"))
let drive = temporary.appending(path: "SharedFolder")
let folder = PlannerFolder(name: "Work")
let list = PlannerList(name: "Project", folderID: folder.id)
var task = PlannerItem(title: "Outline")
task.listID = list.id
task.notes = "Restore this note"
task.order = 1
let initial = PlannerSnapshot(items: [task], folders: [folder], lists: [list])

func sync(_ library: PlannerSnapshot, _ disk: RecoveryFiles) async throws -> PlannerSnapshot {
    var replica = try await disk.prepare(snapshot: library, folder: drive)
    replica.baseline = try replica.document.snapshot()
    try await disk.store(replica, folder: drive)
    try await disk.publish(replica, folder: drive)
    return replica.baseline
}

let original = try await sync(initial, first)
var offline = try await sync(PlannerSnapshot(), second)
precondition(offline == initial)
let attachment = PlannerAttachment(name: "payload.bin", data: Data([42, 0, 18]))
offline.items[0].attachments = [attachment]
offline.items[0].order = 0
var renamed = original
renamed.items[0].title = "Revised"
_ = try await sync(renamed, first)
let reconciled = try await sync(offline, second)
let refreshed = try await sync(renamed, first)
precondition(reconciled == refreshed)
precondition(refreshed.items.count == 1 && refreshed.items[0].title == "Revised")
precondition(refreshed.items[0].order == 0 && refreshed.items[0].attachments == [attachment])

// Both devices independently rename the same task before exchanging changes.
var a = try await first.prepare(snapshot: refreshed, folder: drive)
var b = try await second.prepare(snapshot: reconciled, folder: drive)
var titleA = refreshed
var titleB = reconciled
titleA.items[0].title = "A"
titleB.items[0].title = "B"
try a.document.record(titleA, after: refreshed, writer: a.writer)
try b.document.record(titleB, after: reconciled, writer: b.writer)
let independentB = b.document
b.document.merge(a.document)
a.document.merge(independentB)
let titleWinner = try a.document.snapshot()
let sameWinner = try b.document.snapshot()
precondition(titleWinner == sameWinner && ["A", "B"].contains(titleWinner.items[0].title))

var removed = refreshed
removed.items.removeAll()
_ = try await sync(removed, first)
let afterDeletion = try await sync(reconciled, second)
precondition(afterDeletion.items.isEmpty)

let points = try await first.backup(refreshed)
let file = points[0].id
_ = try await first.backup(removed)
let restored = try await first.readBackup(at: file)
precondition(restored == refreshed && restored.items[0].attachments?.first?.data == attachment.data)

let data = try Data(contentsOf: file)
try data.prefix(data.count / 2).write(to: file)
do {
    _ = try await first.readBackup(at: file)
    fatalError("A partial backup must not decode.")
} catch is DecodingError {
    let intact = try await sync(removed, first)
    precondition(intact == removed)
}
