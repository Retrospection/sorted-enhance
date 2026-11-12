import SwiftUI

enum PlannerSearchResult: Identifiable {
    case task(PlannerItem), event(PlannerCalendarEvent), list(PlannerList), tag(String)

    var id: String {
        switch self {
        case .task(let item): "task/" + item.id.uuidString
        case .event(let event): "event/" + event.id
        case .list(let list): "list/" + list.id.uuidString
        case .tag(let tag): "tag/" + tag
        }
    }

    var title: String {
        switch self {
        case .task(let item): item.title
        case .event(let event): event.title
        case .list(let list): list.name
        case .tag(let tag): tag
        }
    }

    var category: LocalizedStringKey {
        switch self {
        case .task: "Task"
        case .event: "Event"
        case .list: "List"
        case .tag: "Tag"
        }
    }

    var icon: String {
        switch self {
        case .task: "circle"
        case .event: "calendar"
        case .list: "list.bullet"
        case .tag: "tag"
        }
    }
}

struct PlannerQuickSearch: View {
    @ObservedObject var store: PlannerStore
    @ObservedObject var calendars: SystemCalendarStore
    @Binding var query: String
    let onDone: () -> Void
    let onOpen: (PlannerSearchResult) -> Void
    @State private var events: [PlannerCalendarEvent] = []
    @State private var selection: String?

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var matches: [PlannerSearchResult] {
        guard !term.isEmpty else { return [] }
        let tasks = store.items.filter { item in
            !item.deleted && ([item.title, item.notes] + item.tags).contains { $0.localizedCaseInsensitiveContains(term) }
        }.sorted { ($0.order, $0.title) < ($1.order, $1.title) }
        let lists = store.lists.filter { $0.name.localizedCaseInsensitiveContains(term) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return tasks.map(PlannerSearchResult.task) + events.map(PlannerSearchResult.event)
            + lists.map(PlannerSearchResult.list)
            + store.tags.filter { $0.localizedCaseInsensitiveContains(term) }.map(PlannerSearchResult.tag)
    }

    var body: some View {
        let rows = matches
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                PlannerSearchField(text: $query, onCancel: onDone) {
                    openSelection(in: rows)
                } onMove: { offset in
                    moveSelection(by: offset, in: rows)
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                Button("Done", action: onDone)
                    .buttonStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 13)

            if rows.isEmpty {
                Text(term.isEmpty ? LocalizedStringKey("Search tasks, events, lists and tags.") : LocalizedStringKey("No results"))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 185)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(rows, selection: $selection) { result in
                        HStack(spacing: 10) {
                            Image(systemName: result.icon)
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                                .accessibilityHidden(true)
                            Text(result.title).lineLimit(1)
                            Spacer(minLength: 12)
                            Text(result.category).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .tag(result.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onOpen(result) }
                        .accessibilityElement(children: .contain)
                        .accessibilityAction { onOpen(result) }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onKeyPress(.return) {
                        openSelection(in: rows)
                        return .handled
                    }
                    .onChange(of: selection) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onChange(of: term, initial: true) {
            selection = nil
            events = calendars.search(term)
        }
        .onReceive(calendars.$calendars.receive(on: RunLoop.main)) { _ in events = calendars.search(term) }
    }

    private func openSelection(in rows: [PlannerSearchResult]) {
        if let result = rows.first(where: { $0.id == selection }) ?? rows.first { onOpen(result) }
    }

    private func moveSelection(by offset: Int, in rows: [PlannerSearchResult]) {
        guard !rows.isEmpty else { return }
        let index = rows.firstIndex { $0.id == selection } ?? (offset > 0 ? -1 : rows.count)
        selection = rows[min(max(index + offset, 0), rows.count - 1)].id
    }
}
