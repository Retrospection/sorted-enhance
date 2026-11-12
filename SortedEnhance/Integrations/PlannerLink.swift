import Foundation

enum PlannerLink: Equatable {
    case today
    case date(Date)
    case list(UUID)
    case search(String)
    case item(UUID)
    case add(title: String, notes: String)

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme?.lowercased() == "sorted-enhance",
              parts.user == nil, parts.password == nil, parts.port == nil else { return nil }

        let path = String(parts.path.dropFirst())
        switch parts.host?.lowercased() {
        case "today" where parts.path.isEmpty:
            self = .today
        case "date":
            let formatter = Self.dayFormatter
            guard let day = formatter.date(from: path), formatter.string(from: day) == path else { return nil }
            self = .date(day)
        case "list":
            guard let id = UUID(uuidString: path) else { return nil }
            self = .list(id)
        case "search" where parts.path.isEmpty:
            guard let query = Self.queryValue("q", in: parts) else { return nil }
            self = .search(query)
        case "item":
            guard let id = UUID(uuidString: path) else { return nil }
            self = .item(id)
        case "add" where parts.path.isEmpty:
            guard let title = Self.queryValue("title", in: parts) else { return nil }
            self = .add(title: title, notes: parts.queryItems?.first { $0.name == "notes" }?.value ?? "")
        default:
            return nil
        }
    }

    var url: URL {
        var parts = URLComponents()
        parts.scheme = "sorted-enhance"
        switch self {
        case .today:
            parts.host = "today"
        case .date(let date):
            parts.host = "date"
            parts.path = "/" + Self.dayFormatter.string(from: date)
        case .list(let id):
            parts.host = "list"
            parts.path = "/" + id.uuidString
        case .search(let query):
            parts.host = "search"
            parts.queryItems = [URLQueryItem(name: "q", value: query)]
        case .item(let id):
            parts.host = "item"
            parts.path = "/" + id.uuidString
        case .add(let title, let notes):
            parts.host = "add"
            parts.queryItems = [URLQueryItem(name: "title", value: title), URLQueryItem(name: "notes", value: notes)]
        }
        return parts.url!
    }

    private static func queryValue(_ name: String, in parts: URLComponents) -> String? {
        let matches = parts.queryItems?.filter { $0.name == name } ?? []
        guard matches.count == 1, let text = matches[0].value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
