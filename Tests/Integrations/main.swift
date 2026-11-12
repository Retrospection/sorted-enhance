import Foundation

guard let link = URL(string: "sorted-enhance://add?title=Milk%20%26%20tea&notes=50%25%20off%3F"),
      case let .add(title, notes) = PlannerLink(url: link) else { fatalError("Expected a creation link") }
precondition(title == "Milk & tea" && notes == "50% off?")

let id = UUID()
guard case .item(id) = PlannerLink(url: URL(string: "sorted-enhance://item/\(id)")!) else {
    fatalError("Expected the existing task")
}
for invalid in [
    "https://add?title=New", "sorted-enhance://add?title=%20", "sorted-enhance://add?title=A&title=B",
    "sorted-enhance://item/not-a-uuid", "sorted-enhance://add/unexpected?title=Lost"
] {
    guard case nil = PlannerLink(url: URL(string: invalid)!) else { fatalError("Unexpected action for " + invalid) }
}

let calendar = Calendar.current
let day = calendar.startOfDay(for: Date())
for route in [PlannerLink.date(day), .list(id), .search("milk & tea + 50%?")] {
    precondition(PlannerLink(url: route.url) == route)
}
for invalid in ["date/2026-02-30", "date/2026-1-1", "list/unknown", "search?q=A&q=B", "search?q=%20"] {
    precondition(PlannerLink(url: URL(string: "sorted-enhance://" + invalid)!) == nil)
}
