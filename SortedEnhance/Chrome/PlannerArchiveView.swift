import SwiftUI

struct PlannerArchiveView: View {
    let section: PlannerSection
    @ObservedObject var store: PlannerStore
    let onEdit: (PlannerItem) -> Void
    @Environment(\.calendar) private var calendar
    @State private var confirmingPurge = false
    @State private var selection: UUID?

    private var entries: [PlannerItem] {
        store.items.filter { section == .trash ? $0.inTrash : !$0.deleted && $0.status != .active }
    }

    private enum Period: Hashable {
        case recent, earlier, month(Date), undated
    }

    private func date(of item: PlannerItem) -> Date? {
        section == .trash ? item.deletedAt : item.closedAt
    }

    private func groups(_ items: [PlannerItem]) -> [(period: Period, rows: [PlannerItem])] {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let buckets = Dictionary(grouping: items) { item -> Period in
            guard let date = date(of: item) else { return .undated }
            if section == .trash { return date >= start ? .recent : .earlier }
            guard let month = calendar.dateInterval(of: .month, for: date)?.start else { return .undated }
            return .month(month)
        }
        let periods: [Period]
        if section == .trash {
            periods = [.recent, .earlier, .undated]
        } else {
            periods = buckets.keys.compactMap { if case .month(let date) = $0 { date } else { nil } }
                .sorted(by: >).map(Period.month) + [.undated]
        }
        return periods.compactMap { period in
            guard let rows = buckets[period] else { return nil }
            return (period, rows.sorted {
                let left = date(of: $0) ?? .distantPast, right = date(of: $1) ?? .distantPast
                if left != right { return left > right }
                return ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString)
            })
        }
    }

    var body: some View {
        let items = entries
        VStack(alignment: .leading, spacing: 0) {
            if section == .trash {
                HStack {
                    Text("Last 7 days").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button("Empty Trash", role: .destructive) { confirmingPurge = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .disabled(items.isEmpty)
                }
                .padding(.horizontal, 44).padding(.vertical, 8)
                Divider().padding(.horizontal, 44)
            }
            if items.isEmpty {
                PlannerEmptyState(section: section)
            } else {
                List(selection: $selection) {
                    ForEach(groups(items), id: \.period) { group in
                        Section {
                            ForEach(group.rows) { item in
                                row(item).tag(item.id)
                            }
                        } header: { groupHeading(group.period) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 32)
                .onKeyPress(.return) {
                    guard let item = items.first(where: { $0.id == selection }) else { return .ignored }
                    onEdit(item)
                    return .handled
                }
            }
        }
        .confirmationDialog("Empty Trash?", isPresented: $confirmingPurge, titleVisibility: .visible) {
            Button("Empty Trash", role: .destructive) { store.emptyTrash() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Remove all tasks from Trash? You can undo this change.") }
    }

    @ViewBuilder private func groupHeading(_ period: Period) -> some View {
        switch period {
        case .month(let month):
            Text(month, format: .dateTime.month(.wide).year())
                .font(.system(size: 13, weight: .semibold))
        case .earlier: Text("Earlier")
        case .undated: Text("Date unknown")
        case .recent: EmptyView()
        }
    }

    private func row(_ item: PlannerItem) -> some View {
        HStack(spacing: 14) {
            if item.status == .active {
                Image(systemName: "circle").foregroundStyle(.secondary)
            } else {
                Image(systemName: item.status == .completed ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(item.status == .completed ? Color.blue : Color.secondary)
                    .accessibilityLabel(item.status == .completed ? Text("Completed") : Text("Canceled"))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.system(size: 15, weight: .semibold))
                HStack(spacing: 8) {
                    if let date = date(of: item) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                    }
                    if let id = item.listID, let list = store.lists.first(where: { $0.id == id }) {
                        Text(list.name).lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onEdit(item) }
        .accessibilityElement(children: .contain)
        .accessibilityAction { onEdit(item) }
        .contextMenu { Button("Open") { onEdit(item) } }
    }
}
