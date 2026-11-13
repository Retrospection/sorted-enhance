import AppIntents
import Foundation

struct AddPlannerTask: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Create a task in Sorted Enhance.")

    @Parameter(title: "Title") var titleText: String
    @Parameter(title: "Start") var start: Date?
    @Parameter(title: "Duration in Minutes") var duration: Int?
    @Parameter(title: "List Name") var listName: String?
    @Parameter(title: "Tags") var tags: [String]?
    @Parameter(title: "Notes") var notes: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = PlannerStore.shared
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw CaptureError.emptyTitle }
        var item = PlannerItem(title: title)
        if let duration {
            guard duration > 0 && duration <= 1440 else { throw CaptureError.invalidDuration }
            item.duration = duration
        }
        if let listName {
            let matches = store.lists.filter { $0.name.localizedCaseInsensitiveCompare(listName) == .orderedSame }
            guard matches.count == 1 else { throw CaptureError.unknownList(listName) }
            item.listID = matches[0].id
        }
        item.start = start
        item.day = start.map { Calendar.current.startOfDay(for: $0) }
        item.notes = notes ?? ""
        item.tags = (tags ?? []).reduce(into: []) { values, input in
            let tag = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tag.isEmpty && !values.contains(tag) { values.append(tag) }
        }
        guard store.save(item) else { throw CaptureError.save(store.errorMessage) }
        return .result(value: "sorted-enhance://item/\(item.id.uuidString)")
    }
}

struct AddPlannerEvent: AppIntent {
    static let title: LocalizedStringResource = "Add Event"
    static let description = IntentDescription("Create an event in your default calendar.")

    @Parameter(title: "Title") var titleText: String
    @Parameter(title: "Start") var start: Date
    @Parameter(title: "Duration in Minutes", default: 30) var duration: Int
    @Parameter(title: "Alert Minutes Before Start") var alertMinutesBefore: Int?

    @MainActor
    func perform() async throws -> some IntentResult {
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw CaptureError.emptyTitle }
        guard duration > 0 && duration <= 1440 else { throw CaptureError.invalidDuration }
        if let alertMinutesBefore, alertMinutesBefore < 0 { throw CaptureError.invalidAlert }
        _ = try await SystemCalendarStore().addEvent(
            title: title, start: start, duration: duration, alertMinutesBefore: alertMinutesBefore
        )
        return .result()
    }
}

private enum CaptureError: LocalizedError {
    case emptyTitle
    case invalidDuration
    case invalidAlert
    case unknownList(String)
    case save(String?)

    var errorDescription: String? {
        switch self {
        case .emptyTitle: "Enter a title."
        case .invalidDuration: "Choose a duration between 1 and 1440 minutes."
        case .invalidAlert: "Choose a nonnegative alert interval."
        case .unknownList(let name): "Specify a single existing list matching “\(name)”."
        case .save(let message): message ?? "The task could not be saved."
        }
    }
}
