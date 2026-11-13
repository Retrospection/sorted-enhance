import Foundation

struct PlannerRecurrence: Codable, Hashable, Sendable {
    enum Frequency: String, Codable, CaseIterable, Sendable {
        case daily, weekly, monthly, yearly
    }

    var frequency: Frequency
    var interval = 1
    var anchor: Date
    var anchorIndex = 0
    var timeZoneID: String

    init(frequency: Frequency, anchor: Date, timeZone: TimeZone = .current) {
        self.frequency = frequency
        self.anchor = anchor
        timeZoneID = timeZone.identifier
    }
}
