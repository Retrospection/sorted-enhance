import AppKit
import UniformTypeIdentifiers

final class ShareViewController: NSViewController {
    private let textView = NSTextView()
    private let feedback = NSTextField(wrappingLabelWithString: "")
    private lazy var addButton = NSButton(title: "Add to Inbox", target: self, action: #selector(add))
    private var didFinish = false

    override func loadView() {
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        let buttons = NSStackView(views: [cancelButton, addButton])
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        addButton.isEnabled = false
        addButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [NSTextField(labelWithString: "New Inbox Task"), scroll, feedback, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        view = stack
        preferredContentSize = NSSize(width: 400, height: 235)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 110).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        Task {
            do {
                var parts: [String] = []
                for item in items {
                    for provider in item.attachments ?? [] {
                        if let text = try await Self.content(from: provider) { parts.append(text) }
                    }
                    if (item.attachments ?? []).isEmpty, let text = item.attributedContentText?.string {
                        parts.append(text)
                    }
                }
                guard !didFinish else { return }
                textView.string = parts.joined(separator: "\n")
                addButton.isEnabled = true
            } catch {
                feedback.stringValue = error.localizedDescription
            }
        }
    }

    private static func content(from provider: NSItemProvider) async throws -> String? {
        guard let type = [UTType.url.identifier, UTType.plainText.identifier].first(where: {
            provider.hasItemConformingToTypeIdentifier($0)
        }) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = value as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else if let text = value as? String {
                    continuation.resume(returning: text)
                } else if let data = value as? Data, let text = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadInapplicableStringEncoding))
                }
            }
        }
    }

    @objc private func add() {
        guard !didFinish else { return }
        let text = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            feedback.stringValue = "Enter a task or share a link."
            return
        }
        do {
            try SharedCapture(id: UUID(), text: text).enqueue()
            didFinish = true
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            feedback.stringValue = error.localizedDescription
        }
    }

    @objc private func cancel() {
        didFinish = true
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }
}
