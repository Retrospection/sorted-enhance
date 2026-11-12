import Foundation

enum DayPlanner {
    struct Result {
        var changes: [PlannerItem] = []
        var overflowCount = 0
    }

    static let standardDuration = 15

    static func occupiedMinutes(_ item: PlannerItem, defaultDuration: Int) -> Int {
        max(1, item.duration ?? item.scheduledDuration ?? defaultDuration)
    }

    static func end(of item: PlannerItem, defaultDuration: Int = standardDuration) -> Date? {
        item.start?.addingTimeInterval(TimeInterval(occupiedMinutes(item, defaultDuration: defaultDuration)) * 60)
    }

    static func items(on day: Date, in items: [PlannerItem], defaultDuration: Int = standardDuration, calendar: Calendar = .current) -> [PlannerItem] {
        guard let bounds = calendar.dateInterval(of: .day, for: day) else { return [] }
        return items.filter { item in
            guard !item.deleted else { return false }
            if let start = item.start, let end = end(of: item, defaultDuration: defaultDuration) {
                return start < bounds.end && end > bounds.start
            }
            return item.day.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        }
    }

    static func plan(
        items: [PlannerItem],
        from start: Date,
        until end: Date,
        buffer: Int,
        busy: [DateInterval],
        defaultDuration: Int = standardDuration,
        selectedIDs: Set<UUID>? = nil,
        calendar: Calendar = .current
    ) -> Result {
        let visible = self.items(on: start, in: items, defaultDuration: defaultDuration, calendar: calendar)
        let movable = visible.filter { item in
            item.status == .active && !item.locked && (selectedIDs?.contains(item.id) ?? true)
                && item.start.map { calendar.isDate($0, inSameDayAs: start) } != false
        }
        let movingIDs = Set(movable.map(\.id))
        let occupied = (busy + visible.compactMap { item -> DateInterval? in
            guard !movingIDs.contains(item.id), item.status != .canceled,
                  let from = item.start, let until = self.end(of: item, defaultDuration: defaultDuration) else { return nil }
            return DateInterval(start: from, end: until)
        }).sorted { $0.start < $1.start }

        var result = Result()
        var cursor = start
        for var item in movable.sorted(by: { $0.order < $1.order }) {
            let minutes = max(1, item.duration ?? defaultDuration)
            let length = TimeInterval(minutes) * 60
            var candidate = cursor
            for interval in occupied where interval.end > candidate {
                if candidate.addingTimeInterval(length) <= interval.start { break }
                candidate = interval.end
            }
            let finish = candidate.addingTimeInterval(length)
            if finish <= end {
                item.start = candidate
                item.scheduledDuration = item.duration == nil ? minutes : nil
                cursor = finish.addingTimeInterval(TimeInterval(max(0, buffer)) * 60)
            } else {
                item.start = nil
                item.scheduledDuration = nil
                result.overflowCount += 1
            }
            item.day = calendar.startOfDay(for: start)
            result.changes.append(item)
        }
        return result
    }

    static func move(_ items: [PlannerItem], to day: Date, calendar: Calendar = .current) -> [PlannerItem] {
        items.map { item in
            var moved = item
            moved.day = calendar.startOfDay(for: day)
            if let start = item.start {
                let time = calendar.dateComponents([.hour, .minute, .second], from: start)
                moved.start = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0,
                                            second: time.second ?? 0, of: day)
            }
            return moved
        }
    }

    static func shift(_ items: [PlannerItem], minutes: Int, changeSpacing: Bool = false) -> [PlannerItem] {
        let timed = items.filter { !$0.locked && $0.status == .active && $0.start != nil }
            .sorted { ($0.start!, $0.order) < ($1.start!, $1.order) }
        var previous: Date?
        return timed.enumerated().map { index, item in
            var moved = item
            let delta = TimeInterval(minutes) * 60 * (changeSpacing ? Double(index) : 1)
            var start = item.start!.addingTimeInterval(delta)
            if changeSpacing, let previous { start = max(previous, start) }
            previous = start
            moved.start = start
            moved.day = Calendar.current.startOfDay(for: start)
            return moved
        }
    }

    static func reorder(_ ordered: [PlannerItem], selection: Set<UUID>, before target: UUID?) -> [PlannerItem] {
        guard target.map(selection.contains) != true else { return [] }
        var rest = ordered.filter { !selection.contains($0.id) }
        let group = ordered.filter { selection.contains($0.id) }
        let index = rest.firstIndex { $0.id == target } ?? rest.endIndex
        rest.insert(contentsOf: group, at: index)
        return rest.enumerated().map { index, item in
            var updated = item
            updated.order = index
            return updated
        }
    }
}
