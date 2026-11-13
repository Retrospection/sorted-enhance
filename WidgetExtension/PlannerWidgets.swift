import AppIntents
import SwiftUI
import WidgetKit

private extension WidgetSnapshot {
    static func load() -> Self {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return .empty }
        return (try? JSONDecoder().decode(Self.self, from: data)) ?? .empty
    }
}

struct ListOption: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "List"
    static let defaultQuery = ListOptions()

    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct ListOptions: EntityQuery {
    func suggestedEntities() async throws -> [ListOption] {
        WidgetSnapshot.load().lists.map { ListOption(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [UUID]) async throws -> [ListOption] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }
}

struct TagOptions: DynamicOptionsProvider {
    func results() async throws -> [String] {
        Array(Set(WidgetSnapshot.load().tasks.flatMap(\.tags))).sorted()
    }
}

struct PlannerEntry: TimelineEntry {
    let date: Date
    let title: String
    let tasks: [WidgetTask]
}

protocol PlannerWidgetIntent: WidgetConfigurationIntent {
    static var widgetKind: String { get }
    static var widgetName: LocalizedStringKey { get }
    static var widgetSummary: LocalizedStringKey { get }
    func entry(from snapshot: WidgetSnapshot, at date: Date) -> PlannerEntry
}

struct TodayIntent: PlannerWidgetIntent {
    static let widgetKind = "SortedEnhance.Today"
    static var widgetName: LocalizedStringKey { "Today" }
    static var widgetSummary: LocalizedStringKey { "Tasks scheduled for today." }
    static let title: LocalizedStringResource = "Today"

    func entry(from snapshot: WidgetSnapshot, at date: Date) -> PlannerEntry {
        PlannerEntry(date: date, title: "Today", tasks: snapshot.tasks(on: date))
    }
}

struct ListIntent: PlannerWidgetIntent {
    static let widgetKind = "SortedEnhance.List"
    static var widgetName: LocalizedStringKey { "List" }
    static var widgetSummary: LocalizedStringKey { "Tasks in a selected list." }
    static let title: LocalizedStringResource = "Tasks in a list"
    @Parameter(title: "List") var selected: ListOption?

    func entry(from snapshot: WidgetSnapshot, at date: Date) -> PlannerEntry {
        let list = snapshot.lists.first { $0.id == selected?.id }
        return PlannerEntry(
            date: date, title: list?.name ?? "Choose a list",
            tasks: list.map { list in snapshot.tasks.filter { $0.listID == list.id } } ?? []
        )
    }
}

struct TagIntent: PlannerWidgetIntent {
    static let widgetKind = "SortedEnhance.Tag"
    static var widgetName: LocalizedStringKey { "Tag" }
    static var widgetSummary: LocalizedStringKey { "Tasks with a selected tag." }
    static let title: LocalizedStringResource = "Tagged tasks"
    @Parameter(title: "Tag", optionsProvider: TagOptions()) var tag: String?

    func entry(from snapshot: WidgetSnapshot, at date: Date) -> PlannerEntry {
        PlannerEntry(
            date: date, title: tag ?? "Choose a tag",
            tasks: tag.map { tag in snapshot.tasks.filter { $0.tags.contains(tag) } } ?? []
        )
    }
}

struct PlannerProvider<Intent: PlannerWidgetIntent>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlannerEntry {
        PlannerEntry(date: .now, title: "Tasks", tasks: [])
    }

    func snapshot(for configuration: Intent, in context: Context) async -> PlannerEntry {
        configuration.entry(from: .load(), at: .now)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<PlannerEntry> {
        let now = Date.now
        let boundary = Calendar.current.dateInterval(of: .day, for: now)!.end
        let snapshot = WidgetSnapshot.load()
        let entries = [now, boundary].map { configuration.entry(from: snapshot, at: $0) }
        return Timeline(entries: entries, policy: .after(boundary))
    }
}

struct PlannerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PlannerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title).font(.headline).lineLimit(1)
            if entry.tasks.isEmpty {
                Text("No tasks").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(entry.tasks.prefix(family == .systemSmall ? 1 : (family == .systemLarge ? 8 : 3))) { task in
                if family == .systemSmall {
                    Text(task.title).lineLimit(1)
                } else {
                    Link(destination: task.link) {
                        HStack {
                            Text(task.title).lineLimit(1)
                            Spacer()
                            if let start = task.start {
                                Text(start, style: .time).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(family == .systemSmall ? entry.tasks.first?.link ?? Self.todayURL : Self.todayURL)
        .containerBackground(.background, for: .widget)
    }

    private static let todayURL = URL(string: "sorted-enhance://today")!
}

struct PlannerWidget<Intent: PlannerWidgetIntent>: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Intent.widgetKind, intent: Intent.self, provider: PlannerProvider<Intent>()) { entry in
            PlannerWidgetView(entry: entry)
        }
        .configurationDisplayName(Intent.widgetName)
        .description(Intent.widgetSummary)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct PlannerWidgetBundle: WidgetBundle {
    var body: some Widget {
        PlannerWidget<TodayIntent>()
        PlannerWidget<ListIntent>()
        PlannerWidget<TagIntent>()
    }
}
