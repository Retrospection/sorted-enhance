import AppIntents
import AppKit

private func openPlanner(_ link: PlannerLink) async throws {
    _ = try await NSWorkspace.shared.open(
        [link.url], withApplicationAt: Bundle.main.bundleURL, configuration: NSWorkspace.OpenConfiguration()
    )
}

struct ShowPlannerDate: AppIntent {
    static let openAppWhenRun = true
    static let title: LocalizedStringResource = "Show Date"
    @Parameter(title: "Date", kind: .date) var date: Date

    func perform() async throws -> some IntentResult {
        try await openPlanner(.date(date))
        return .result()
    }
}

struct ShowPlannerList: AppIntent {
    static let openAppWhenRun = true
    static let title: LocalizedStringResource = "Show List"
    @Parameter(title: "List") var list: PlannerListEntity

    func perform() async throws -> some IntentResult {
        try await openPlanner(.list(list.id))
        return .result()
    }
}

struct SearchPlanner: AppIntent {
    static let openAppWhenRun = true
    static let title: LocalizedStringResource = "Search"
    @Parameter(title: "Search Term") var query: String

    func perform() async throws -> some IntentResult {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { throw $query.needsValueError() }
        try await openPlanner(.search(term))
        return .result()
    }
}

struct PlannerListEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Task List"
    static let defaultQuery = PlannerListQuery()

    let id: UUID
    let name: String
    let folder: String?

    var displayRepresentation: DisplayRepresentation {
        if let folder {
            DisplayRepresentation(title: "\(name)", subtitle: "\(folder)")
        } else {
            DisplayRepresentation(title: "\(name)")
        }
    }
}

struct PlannerListQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PlannerListEntity] {
        choices.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [PlannerListEntity] {
        choices.filter { string.isEmpty || $0.name.localizedCaseInsensitiveContains(string) }
    }

    @MainActor
    func suggestedEntities() async throws -> [PlannerListEntity] { choices }

    @MainActor
    private var choices: [PlannerListEntity] {
        let store = PlannerStore.shared
        return store.lists.sorted { $0.order < $1.order }.map { list in
            PlannerListEntity(id: list.id, name: list.name, folder: store.folders.first { $0.id == list.folderID }?.name)
        }
    }
}
