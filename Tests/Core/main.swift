import Foundation

@MainActor
func testBatchUndoRedoAndRelaunch(at file: URL) {
    let store = PlannerStore(fileURL: file)
    let folder = PlannerFolder(name: "Work")
    let list = PlannerList(name: "Release", folderID: folder.id)
    precondition(store.replaceOrganization(folders: [folder], lists: [list]))

    var draft = PlannerItem(title: "Write notes")
    draft.listID = list.id
    draft.attachments = [PlannerAttachment(name: "record.txt", data: Data("record".utf8))]
    var review = PlannerItem(title: "Review")
    precondition(store.save([draft, review]))
    let before = store.snapshot

    draft.title = "Publish notes"
    review.status = .completed
    precondition(store.save([draft, review]))
    let after = store.snapshot
    precondition(after.items.map(\.order) == [0, 1])
    precondition(after.items[0].title == "Publish notes" && after.items[1].status == .completed)
    precondition(store.undo() && store.snapshot == before, "One undo must reverse the entire batch.")
    precondition(store.redo() && store.snapshot == after)
    precondition(PlannerStore(fileURL: file).snapshot == after, "Relaunch lost the restored library.")
}

@MainActor
func testInvalidBackupPreservesLibrary(at file: URL) throws {
    let store = PlannerStore(fileURL: file)
    let task = PlannerItem(title: "Keep this item")
    precondition(store.save(task))
    let before = try Data(contentsOf: file)
    let invalid = PlannerSnapshot(items: [task, task])
    precondition(!store.restore(invalid))
    let after = try Data(contentsOf: file)
    precondition(before == after && store.items.count == 1 && store.errorMessage != nil)
}

@MainActor
func testRecoverDamagedLibrary(at file: URL) throws {
    let damaged = Data([0xff])
    try damaged.write(to: file)
    let store = PlannerStore(fileURL: file)
    precondition(store.errorMessage != nil)
    precondition(!store.save(PlannerItem(title: "Retry")))
    let retained = try Data(contentsOf: file)
    precondition(retained == damaged, "A routine edit overwrote unreadable data.")
    let backup = PlannerSnapshot(items: [PlannerItem(title: "Recovered")])
    precondition(store.restore(backup))
    precondition(PlannerStore(fileURL: file).snapshot == backup)
}

@MainActor
func testFailedWritePreservesUndoHistory(at file: URL) throws {
    let store = PlannerStore(fileURL: file)
    var task = PlannerItem(title: "Initial state")
    precondition(store.save(task))
    task.title = "Edited state"
    precondition(store.save(task))
    let movedFile = file.appendingPathExtension("saved")
    try FileManager.default.moveItem(at: file, to: movedFile)
    try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
    precondition(!store.undo() && store.items[0].title == "Edited state" && store.canUndo)
    try FileManager.default.removeItem(at: file)
    try FileManager.default.moveItem(at: movedFile, to: file)
    precondition(store.undo() && store.items[0].title == "Initial state")
}

let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
defer { try? FileManager.default.removeItem(at: directory) }
testBatchUndoRedoAndRelaunch(at: directory.appending(path: "batch.json"))
try testInvalidBackupPreservesLibrary(at: directory.appending(path: "restore.json"))
try testRecoverDamagedLibrary(at: directory.appending(path: "damaged.json"))
try testFailedWritePreservesUndoHistory(at: directory.appending(path: "undo.json"))
print("All four planner store cases passed.")
