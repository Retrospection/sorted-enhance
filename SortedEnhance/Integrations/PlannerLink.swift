import Foundation

enum PlannerLink {
    case today
    case item(UUID)
    case add(title: String, notes: String)

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "sorted-enhance",
              parts.user == nil, parts.password == nil, parts.port == nil else { return nil }

        switch parts.host?.lowercased() {
        case "today" where parts.path.isEmpty:
            self = .today
        case "item":
            guard parts.path.hasPrefix("/"), let id = UUID(uuidString: String(parts.path.dropFirst())) else { return nil }
            self = .item(id)
        case "add" where parts.path.isEmpty:
            let fields = parts.queryItems ?? []
            let titles = fields.filter { $0.name == "title" }
            guard titles.count == 1, let title = titles[0].value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { return nil }
            self = .add(title: title, notes: fields.first { $0.name == "notes" }?.value ?? "")
        default:
            return nil
        }
    }
}
