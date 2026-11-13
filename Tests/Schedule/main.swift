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

print("Day planner checks passed.")
