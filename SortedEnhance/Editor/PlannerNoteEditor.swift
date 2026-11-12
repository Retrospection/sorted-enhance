import AppKit
import SwiftUI

struct PlannerNoteEditor: View {
    @Binding var notes: String
    @Binding var richNotes: Data?
    var onExtract: (([String]) -> Void)?

    @StateObject private var session = NoteSession()

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Notes").font(.headline)
                Spacer()
                Button {
                    session.toggleBold()
                } label: {
                    Image(systemName: "bold")
                }
                .accessibilityLabel("Bold").help("Bold")
                Button {
                    session.toggleChecklist()
                } label: {
                    Image(systemName: "checklist")
                }
                .accessibilityLabel("Toggle checklist item").help("Toggle checklist item")
                if let onExtract {
                    Button("Extract lines") { session.extractLines(onExtract) }
                        .help("Turn selected note lines into tasks when you save")
                }
            }
            NoteTextView(notes: $notes, richNotes: $richNotes, session: session)
                .frame(minHeight: 96, idealHeight: 130)
                .border(.secondary.opacity(0.25))
        }
    }
}

@MainActor
private final class NoteSession: ObservableObject {
    weak var textView: NSTextView?

    func toggleBold() {
        guard let view = textView, let storage = view.textStorage else { return }
        view.window?.makeFirstResponder(view)
        let range = view.selectedRange()
        let manager = NSFontManager.shared
        let defaultFont = view.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let attributes = range.length == 0 ? view.typingAttributes : storage.attributes(at: range.location, effectiveRange: nil)
        let removeBold = manager.traits(of: attributes[.font] as? NSFont ?? defaultFont).contains(.boldFontMask)
        func toggled(_ font: NSFont) -> NSFont {
            removeBold ? manager.convert(font, toNotHaveTrait: .boldFontMask) : manager.convert(font, toHaveTrait: .boldFontMask)
        }
        if range.length == 0 {
            view.typingAttributes[.font] = toggled(attributes[.font] as? NSFont ?? defaultFont)
            return
        }
        guard view.shouldChangeText(in: range, replacementString: nil) else { return }
        let original = NSAttributedString(attributedString: storage)
        storage.beginEditing()
        original.enumerateAttribute(.font, in: range) { value, span, _ in
            storage.addAttribute(.font, value: toggled(value as? NSFont ?? defaultFont), range: span)
        }
        storage.endEditing()
        view.didChangeText()
    }

    func toggleChecklist() {
        guard let view = textView else { return }
        let text = view.string as NSString
        let line = text.lineRange(for: NSRange(location: view.selectedRange().location, length: 0))
        let prefix = text.substring(with: line)
        let hasMarker = prefix.hasPrefix("☐ ") || prefix.hasPrefix("☑ ")
        let range = NSRange(location: line.location, length: hasMarker ? 2 : 0)
        let marker = prefix.hasPrefix("☐ ") ? "☑ " : "☐ "
        view.insertText(marker, replacementRange: range)
    }

    func extractLines(_ extract: ([String]) -> Void) {
        guard let view = textView else { return }
        let text = view.string as NSString
        let range = text.lineRange(for: view.selectedRange())
        let titles = text.substring(with: range).components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !titles.isEmpty else { return }
        view.insertText("", replacementRange: range)
        extract(titles)
    }
}

private struct NoteTextView: NSViewRepresentable {
    @Binding var notes: String
    @Binding var richNotes: Data?
    let session: NoteSession

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 5, height: 5)
        textView.setAccessibilityLabel("Notes")
        textView.setAccessibilityIdentifier("Notes")
        textView.delegate = context.coordinator
        session.textView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView,
              view.string != notes || context.coordinator.lastRichNotes != richNotes else { return }
        context.coordinator.lastRichNotes = richNotes
        if let richNotes, let formatted = NSAttributedString(rtf: richNotes, documentAttributes: nil),
           formatted.string == notes {
            view.textStorage?.setAttributedString(formatted)
        } else {
            view.string = notes
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextView
        var lastRichNotes: Data?

        init(_ parent: NoteTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            let content = view.attributedString()
            lastRichNotes = content.rtf(from: NSRange(location: 0, length: content.length),
                                        documentAttributes: [:])
            parent.notes = content.string
            parent.richNotes = lastRichNotes
        }
    }
}
