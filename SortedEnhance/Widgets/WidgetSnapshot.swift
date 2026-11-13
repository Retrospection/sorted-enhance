import Foundation

struct WidgetTask: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let day: Date?
    let start: Date?
    let listID: UUID?
    let tags: [String]

    init(_ item: PlannerItem) {
        id = item.id
        title = item.title
        day = item.day
        start = item.start
        listID = item.listID
        tags = item.tags
    }

    var link: URL {
        URL(string: "sorted-enhance://item/\(id.uuidString)")!
    }
}

struct WidgetList: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
}

struct WidgetOccurrence: Codable, Hashable {
    let task: WidgetTask
    let seriesID: UUID
    let index: Int
    let rule: PlannerRecurrence?
    let ownsRevisionDefaults: Bool?
    let status: PlannerStatus?
    let deleted: Bool?

    init?(_ item: PlannerItem) {
        guard let seriesID = item.seriesID, let index = item.occurrenceIndex else { return nil }
        // The tasks array holds what is visible for this occurrence. Projection needs its revision baseline.
        task = WidgetTask(item.revisionDefaults?.applying(to: item) ?? item)
        ownsRevisionDefaults = item.revisionDefaults == nil ? nil : true
        status = item.status == .active ? nil : item.status
        deleted = item.deleted ? true : nil
        self.seriesID = seriesID
        self.index = index
        rule = item.recurrence
    }

    var template: PlannerItem {
        var item = PlannerItem(title: task.title)
        item.id = task.id
        item.day = task.day
        item.start = task.start
        item.listID = task.listID
        item.tags = task.tags
        item.seriesID = seriesID
        item.occurrenceIndex = index
        item.recurrence = rule
        item.status = status ?? .active
        item.deleted = deleted ?? false
        if ownsRevisionDefaults == true { item.revisionDefaults = PlannerOccurrenceDefaults(item) }
        return item
    }
}

struct WidgetSnapshot: Codable, Equatable {
    let tasks: [WidgetTask]
    let lists: [WidgetList]

    // Include occupied and stopped occurrences so projection respects exceptions.
    var occurrences: [WidgetOccurrence]?

    func tasks(on date: Date, calendar: Calendar = .current) -> [WidgetTask] {
        let projected = PlannerRepetition.upcoming(in: (occurrences ?? []).map(\.template), through: date)
        return (tasks + projected.map(WidgetTask.init)).filter { task in
            guard let day = task.start ?? task.day else { return false }
            return calendar.isDate(day, inSameDayAs: date)
        }.sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }

    static let empty = WidgetSnapshot(tasks: [], lists: [])

    static var fileURL: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PlannerAppGroup") as? String else { return nil }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("WidgetSnapshot.json")
    }
}
