import Foundation

struct QuickEntry {
    let title: String
    let day: Date?
    let start: Date?

    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    private static let timePattern = #"(?i)(\b\d{1,2}\s*:\s*\d{2}\b|\b\d{1,2}\s*[ap]\.?m\.?\b|\b(noon|midnight)\b)"#

    init(_ input: String, calendar: Calendar = .current) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullRange = NSRange(text.startIndex..., in: text)
        let matches = Self.detector?.matches(in: text, range: fullRange) ?? []
        guard let match = matches.last, NSMaxRange(match.range) == fullRange.length,
              let date = match.date, let range = Range(match.range, in: text) else {
            title = text
            day = nil
            start = nil
            return
        }

        let prefix = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
        let stripped = prefix.replacingOccurrences(of: #"(?i)\s+(?:at|on|by)$"#,
                                                   with: "", options: .regularExpression)
        title = stripped.isEmpty ? text : stripped
        day = calendar.startOfDay(for: date)
        let dateText = String(text[range])
        start = dateText.range(of: Self.timePattern, options: .regularExpression) == nil ? nil : date
    }
}
