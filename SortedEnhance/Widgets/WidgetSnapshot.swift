import Foundation

struct WidgetTask: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let day: Date?
    let start: Date?
    let listID: UUID?
    let tags: [String]

    var link: URL {
        URL(string: "sorted-enhance://item/\(id.uuidString)")!
    }
}

struct WidgetList: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
}

struct WidgetSnapshot: Codable, Equatable {
    let tasks: [WidgetTask]
    let lists: [WidgetList]

    static let empty = WidgetSnapshot(tasks: [], lists: [])

    static var fileURL: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PlannerAppGroup") as? String else { return nil }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("WidgetSnapshot.json")
    }
}
