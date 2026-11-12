import Foundation

extension WidgetSnapshot {
    static func export(_ library: PlannerSnapshot, to file: URL) throws -> Bool {
        let snapshot = Self(
            tasks: library.items
                .filter { !$0.deleted && $0.status == .active }
                .sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
                .map(WidgetTask.init),
            lists: library.lists.map { WidgetList(id: $0.id, name: $0.name) },
            occurrences: library.items.compactMap(WidgetOccurrence.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(snapshot)
        guard data != (try? Data(contentsOf: file)) else { return false }
        try data.write(to: file, options: .atomic)
        return true
    }
}
