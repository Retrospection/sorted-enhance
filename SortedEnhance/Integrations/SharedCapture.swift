import Foundation

struct SharedCapture: Codable {
    static let notification = Notification.Name("local.sorted-enhance.sharedCapture")
    let id: UUID
    let text: String

    static func inbox() throws -> URL {
        guard let groupID = Bundle.main.object(forInfoDictionaryKey: "PlannerAppGroup") as? String,
              let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = group.appendingPathComponent("Shared Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func enqueue() throws {
        let file = try Self.inbox().appendingPathComponent(id.uuidString).appendingPathExtension("json")
        try JSONEncoder().encode(self).write(to: file, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            Self.notification, object: nil, userInfo: nil, deliverImmediately: true
        )
    }
}
