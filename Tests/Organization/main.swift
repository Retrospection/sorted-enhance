import AppKit

var minutes = PlannerItem(title: "Meeting minutes")
minutes.notes = "Decisions"
minutes.start = Date(timeIntervalSince1970: 3600)
minutes.tags = ["Review"]
minutes.listID = UUID()

var followUp = PlannerItem(title: "Follow up")
let formatted = NSAttributedString(
    string: "Confirm decision",
    attributes: [.underlineStyle: NSUnderlineStyle.single.rawValue]
)
followUp.notes = formatted.string
followUp.richNotes = try formatted.data(
    from: NSRange(location: 0, length: formatted.length),
    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
)
followUp.tags = ["Review", "Team"]
followUp.attachments = [PlannerAttachment(name: "agenda.txt", data: Data("Agenda".utf8))]

let changes = try TaskMerge.changes(for: [minutes, followUp])
precondition(changes.count == 2)
let merged = changes[0]
precondition(merged.id == minutes.id && merged.start == minutes.start && merged.listID == minutes.listID)
precondition(merged.notes == "Decisions\n\nFollow up\nConfirm decision")
precondition(merged.tags == ["Review", "Team"] && merged.attachments == followUp.attachments)
let rich = try NSAttributedString(
    data: merged.richNotes!, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil
)
precondition(rich.string == merged.notes)
precondition(rich.attribute(.underlineStyle, at: rich.length - 1, effectiveRange: nil) != nil)
followUp.deleted = true
precondition(changes[1] == followUp, "The source must remain restorable from Trash.")
