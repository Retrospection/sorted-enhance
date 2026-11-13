import Foundation

let calendar: Calendar = {
    var result = Calendar(identifier: .gregorian)
    result.timeZone = TimeZone(identifier: "America/New_York")!
    return result
}()

func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour, minute: minute))!
}

func task(_ title: String, _ minutes: Int, order: Int, start: Date? = nil) -> PlannerItem {
    var item = PlannerItem(title: title)
    item.day = date(8, 0)
    item.duration = minutes
    item.order = order
    item.start = start
    return item
}

let outline = task("Outline", 30, order: 1)
let draft = task("Draft", 60, order: 2)
let finish = task("Finish", 15, order: 3)
let meeting = DateInterval(start: date(8, 10), end: date(8, 11))
let overlap = DateInterval(start: date(8, 10, 30), end: date(8, 11, 15))
var locked = task("Locked", 15, order: 4, start: date(8, 11, 15))
locked.locked = true
let result = DayPlanner.plan(items: [draft, finish, locked, outline], from: date(8, 9, 30),
                             until: date(8, 12, 35), buffer: 10, busy: [overlap, meeting], calendar: calendar)
precondition(result.changes.map(\.id) == [outline.id, draft.id, finish.id])
precondition(result.changes.map(\.start) == [date(8, 9, 30), date(8, 11, 30), nil])
precondition(result.overflowCount == 1)

let protectedTask = task("Keep this appointment", 45, order: 0, start: date(8, 9))
let omitted = task("Unscheduled", 15, order: 3)
let selectedResult = DayPlanner.plan(
    items: [omitted, draft, outline, protectedTask, locked], from: date(8, 9), until: date(8, 13),
    buffer: 0, busy: [], selectedIDs: [outline.id, draft.id, locked.id], calendar: calendar
)
precondition(selectedResult.changes.map(\.id) == [outline.id, draft.id])
precondition(selectedResult.changes.map(\.start) == [date(8, 9, 45), date(8, 10, 15)])

let overnight = task("Carry over", 90, order: 0, start: date(7, 23, 30))
let midnight = DayPlanner.plan(items: [overnight, draft], from: date(8, 0), until: date(8, 4),
                               buffer: 0, busy: [], calendar: calendar)
precondition(midnight.changes.map(\.id) == [draft.id])
precondition(midnight.changes.first?.start == date(8, 1))

let resequenced = DayPlanner.reorder([outline, draft, finish, locked], selection: [outline.id, finish.id], before: nil)
precondition(resequenced.map(\.id) == [draft.id, locked.id, outline.id, finish.id])
precondition(resequenced.map(\.order) == [0, 1, 2, 3])

let saturday = task("Review", 30, order: 1, start: date(7, 9))
let moved = DayPlanner.move([saturday, outline], to: date(8, 0), calendar: calendar)
precondition(moved.map(\.start) == [date(8, 9), nil])
precondition(moved.map(\.day) == [date(8, 0), date(8, 0)])

@MainActor
func testReplanAfterMeetingAndRelaunch() {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "planner.json")
    let store = PlannerStore(fileURL: file)
    let outline = task("Outline", 30, order: 0)
    let writing = task("Write", 60, order: 1)
    let meeting = DateInterval(start: date(8, 14), end: date(8, 15))
    precondition(store.save([outline, writing]))

    let first = DayPlanner.plan(items: store.items, from: date(8, 13), until: date(8, 18),
                                buffer: 0, busy: [meeting], calendar: calendar)
    precondition(store.save(first.changes))
    guard var completed = store.items.first(where: { $0.id == outline.id }) else {
        preconditionFailure("Lost the outline during the initial schedule.")
    }
    precondition(completed.start == date(8, 13))
    precondition(store.items.first { $0.id == writing.id }?.start == date(8, 15))

    completed.status = .completed
    precondition(store.save(completed))
    guard let closure = store.items.first(where: { $0.id == outline.id })?.closedAt else {
        preconditionFailure("Completing a task must record its closing time.")
    }
    completed.closedAt = closure
    let next = DayPlanner.plan(items: store.items, from: date(8, 15, 30), until: date(8, 18),
                               buffer: 0, busy: [meeting], calendar: calendar)
    precondition(store.save(next.changes))

    let reopened = PlannerStore(fileURL: file)
    precondition(reopened.items.count == 2)
    precondition(reopened.items.first { $0.id == outline.id } == completed)
    let remaining = reopened.items.first { $0.id == writing.id }
    precondition(remaining?.status == .active && remaining?.start == date(8, 15, 30))
}

testReplanAfterMeetingAndRelaunch()
func testDefaultDurationAndLegacyLibrary() throws {
    let legacyJSON = """
    {"items":[
      {"id":"22DD9556-DD38-4340-8889-3CB44067C56F","title":"Read","notes":"","locked":false,
       "status":"active","deleted":false,"tags":[],"order":0},
      {"id":"AD828281-9AEA-4F0F-ADDF-4DCE42F2408B","title":"Call","notes":"","duration":30,"locked":false,
       "status":"active","deleted":false,"tags":[],"order":1}
    ],"folders":[],"lists":[]}
    """
    var items = try JSONDecoder().decode(PlannerSnapshot.self, from: Data(legacyJSON.utf8)).items
    for index in items.indices { items[index].day = date(8, 0) }
    let initial = DayPlanner.plan(items: items, from: date(8, 9), until: date(8, 10),
                                  buffer: 0, busy: [], calendar: calendar).changes
    precondition(initial.map(\.start) == [date(8, 9), date(8, 9, 15)])
    precondition(initial.map(\.duration) == [nil, 30])
    precondition(initial.map(\.scheduledDuration) == [15, nil])
    let replanned = DayPlanner.plan(items: initial, from: date(8, 9), until: date(8, 10),
                                    buffer: 0, busy: [], defaultDuration: 20, calendar: calendar).changes
    precondition(replanned.map(\.start) == [date(8, 9), date(8, 9, 20)])
    precondition(replanned.map(\.scheduledDuration) == [20, nil])
    precondition(DayPlanner.end(of: replanned[0], defaultDuration: 5) == date(8, 9, 20))
    precondition(DayPlanner.end(of: replanned[1], defaultDuration: 5) == date(8, 9, 50))
}

try testDefaultDurationAndLegacyLibrary()
print("Day planner checks passed.")
