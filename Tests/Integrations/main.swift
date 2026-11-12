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
