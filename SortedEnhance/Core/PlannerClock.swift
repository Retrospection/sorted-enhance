import Foundation

extension Calendar {
    func date(on day: Date, at clock: String, preserving original: Date?) -> Date? {
        let parts = clock.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        if let original, isDate(original, inSameDayAs: day),
           component(.hour, from: original) == hour, component(.minute, from: original) == minute {
            return original
        }
        guard let time = date(bySettingHour: hour, minute: minute, second: 0, of: day, matchingPolicy: .strict),
              isDate(time, inSameDayAs: day) else { return nil }
        return time
    }
}
