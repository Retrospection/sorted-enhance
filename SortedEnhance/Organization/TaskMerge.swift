import AppKit

enum TaskMerge {
    /// The first visible task keeps its identity, list, schedule, and repeat rule.
    static func changes(for items: [PlannerItem]) throws -> [PlannerItem] {
        guard var target = items.first, items.count > 1 else { return [] }
        let note = NSMutableAttributedString(string: "")
        var hasFormatting = false

        for (index, item) in items.enumerated() {
            if index > 0 {
                if note.length > 0 { note.append(NSAttributedString(string: "\n\n")) }
                note.append(NSAttributedString(string: item.title))
                if !item.notes.isEmpty { note.append(NSAttributedString(string: "\n")) }
                for tag in item.tags where !target.tags.contains(tag) {
                    target.tags.append(tag)
                }
                for attachment in item.attachments ?? [] {
                    if !(target.attachments ?? []).contains(where: { $0.id == attachment.id }) {
                        target.attachments = (target.attachments ?? []) + [attachment]
                    }
                }
            }
            if let data = item.richNotes {
                let rich = try NSAttributedString(
                    data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                )
                note.append(rich)
                hasFormatting = true
            } else {
                note.append(NSAttributedString(string: item.notes))
            }
        }
        target.notes = note.string
        if hasFormatting {
            target.richNotes = try note.data(
                from: NSRange(location: 0, length: note.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        }
        return [target] + items.dropFirst().map { source in
            var removed = source
            removed.deleted = true
            return removed
        }
    }
}
