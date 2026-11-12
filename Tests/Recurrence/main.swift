import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!

@MainActor
func date(_ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
}

@MainActor
func makeSeries(_ frequency: PlannerRecurrence.Frequency, start: Date) -> [PlannerItem] {
    let task = PlannerItem(title: "Planning")
    var scheduled = task
    scheduled.start = start
    scheduled.recurrence = PlannerRecurrence(frequency: frequency, anchor: start, timeZone: calendar.timeZone)
    return PlannerRepetition.edit(scheduled, original: task, in: [], scope: .future, now: start)
}

let monthly = makeSeries(.monthly, start: date(1, 31))
precondition(monthly.map(\.start) == [date(1, 31), date(2, 28), date(3, 31), date(4, 30)])

for transition in [(3, 7), (10, 31)] {
    let start = date(transition.0, transition.1)
    let daily = makeSeries(.daily, start: start)
    precondition(daily.allSatisfy { calendar.component(.hour, from: $0.start!) == 9 })
    let gap = daily[1].start!.timeIntervalSince(start)
    precondition(gap == (transition.0 == 3 ? 23 : 25) * 3600)
}

let daily = makeSeries(.daily, start: date(5, 1))
let missed = PlannerRepetition.upcoming(in: daily, through: date(5, 6))
precondition(missed.map(\.start) == [date(5, 5), date(5, 6), date(5, 7), date(5, 8), date(5, 9)])
precondition(PlannerRepetition.upcoming(in: daily + missed, through: date(5, 6)).isEmpty)
precondition(PlannerRepetition.upcoming(in: daily, through: date(5, 6)) == missed)

var moved = daily[1]
moved.start = date(5, 2, 15)
let single = PlannerRepetition.edit(moved, original: daily[1], in: daily, scope: .occurrence)
precondition(single.count == 1 && single[0].start == date(5, 2, 15))

let weekly = makeSeries(.weekly, start: date(6, 1))
var tuesday = weekly[1]
tuesday.start = date(6, 9)
let shifted = PlannerRepetition.edit(tuesday, original: weekly[1], in: weekly, scope: .future, now: date(6, 8))
precondition(shifted.map(\.start) == [date(6, 9), date(6, 16), date(6, 23), date(6, 30)])
precondition(Array(shifted.prefix(3)).map(\.id) == Array(weekly.dropFirst()).map(\.id))
var completed = weekly[0]
completed.status = .completed
let completion = PlannerRepetition.edit(completed, original: weekly[0], in: weekly, scope: .occurrence)
precondition(completion.count == 1 && completion[0].status == .completed && completion[0].start == date(6, 1))
var skippedItem = weekly[2]
skippedItem.status = .canceled
let skipped = PlannerRepetition.edit(skippedItem, original: weekly[2], in: weekly, scope: .occurrence)
precondition(skipped.count == 1 && skipped[0].id == weekly[2].id && skipped[0].status == .canceled)
var stopped = weekly[1]
stopped.recurrence = nil
let ended = PlannerRepetition.edit(stopped, original: weekly[1], in: weekly, scope: .future)
precondition(ended.dropFirst().allSatisfy(\.deleted))
precondition(PlannerRepetition.upcoming(in: [weekly[0]] + ended, through: date(7, 1)).isEmpty)
let longInactive = PlannerRepetition.upcoming(in: daily, through: date(5, 7000))
precondition(longInactive.count < 40)
precondition(longInactive.contains { $0.start == date(5, 7000) })
let gap = PlannerRepetition.upcoming(in: daily + longInactive, through: date(5, 100))
precondition(gap.contains { $0.start == date(5, 100) })
precondition(Set(gap.map(\.id)).isDisjoint(with: Set((daily + longInactive).map(\.id))))

var alreadyFinished = weekly[2]
alreadyFinished.status = .completed
alreadyFinished.notes = "Recorded work"
var corrected = weekly[1]
corrected.start = date(6, 10)
let changedSeries = PlannerRepetition.edit(
    corrected, original: weekly[1], in: [weekly[0], weekly[1], alreadyFinished, weekly[3]],
    scope: .future, now: date(6, 8)
)
let historical = changedSeries.first { $0.id == alreadyFinished.id }!
precondition(historical.status == .completed && historical.notes == "Recorded work" && historical.start == date(6, 15))
print("Recurrence contracts passed.")

var retired = daily.last!
retired.deleted = true
retired.title = "Old series name"
retired.reminderOffsetMinutes = 45
let resumed = PlannerRepetition.upcoming(in: Array(daily.dropLast()) + [retired], through: date(6, 6))
precondition(resumed.contains { $0.start == date(6, 6) && $0.title == daily[0].title && $0.reminderOffsetMinutes == nil })
