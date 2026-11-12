import Foundation

extension WidgetSnapshot {
    static func export(_ library: PlannerSnapshot, to file: URL) throws -> Bool {
        let snapshot = Self(
            tasks: library.items
                .filter { !$0.deleted && $0.status == .active }
                .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
                .map { WidgetTask(id: $0.id, title: $0.title, day: $0.day, start: $0.start, listID: $0.listID, tags: $0.tags) },
            lists: library.lists.map { WidgetList(id: $0.id, name: $0.name) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(snapshot)
        guard data != (try? Data(contentsOf: file)) else { return false }
        try data.write(to: file, options: .atomic)
        return true
    }
}
