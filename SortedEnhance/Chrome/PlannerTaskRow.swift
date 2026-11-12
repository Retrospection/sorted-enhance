import SwiftUI

struct PlannerTaskRow: View {
    let item: PlannerItem
    let listName: String?
    var durationMinutes: Int? = nil
    let completionIdentifier: String
    let onToggleCompletion: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Button(action: onToggleCompletion) {
                Image(systemName: statusSymbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.status == .active ? Text("Complete") : Text("Reopen"))
            .accessibilityIdentifier(completionIdentifier)
            .help(item.status == .active ? Text("Complete") : Text("Reopen"))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .frame(minHeight: 22, alignment: .leading)

                if listName != nil || !item.tags.isEmpty || durationMinutes != nil || item.duration != nil || item.locked {
                    HStack(spacing: 4) {
                        if let listName {
                            chip(Image(systemName: "list.bullet"), text: Text(verbatim: listName))
                        }
                        ForEach(item.tags, id: \.self) { tag in
                            chip(Image(systemName: "tag"), text: Text(verbatim: tag))
                        }
                        if let minutes = durationMinutes ?? item.duration {
                            let duration = Duration.seconds(Double(minutes) * 60)
                            let formatted = duration.formatted(.units(allowed: [.hours, .minutes], width: .narrow))
                            if let start = item.start {
                                let end = start.addingTimeInterval(Double(minutes) * 60)
                                chip(Image(systemName: "clock"), text: Text("\(formatted) → \(end, format: .dateTime.hour().minute())"))
                            } else {
                                chip(Image(systemName: "clock"), text: Text(verbatim: formatted))
                            }
                        }
                        if item.locked {
                            Image(systemName: "lock.fill").font(.caption2)
                                .accessibilityLabel("Locked")
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onOpen)
            .accessibilityElement(children: .contain)
            .accessibilityAction { onOpen() }
        }
        .padding(.vertical, 4)
    }

    private var statusSymbol: String {
        switch item.status {
        case .active: "square"
        case .completed: "checkmark.square.fill"
        case .canceled: "xmark.square"
        }
    }

    private func chip(_ image: Image, text: Text) -> some View {
        HStack(spacing: 3) {
            image.accessibilityHidden(true)
            text.lineLimit(1)
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())
    }
}
