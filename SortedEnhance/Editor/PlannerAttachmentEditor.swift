import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct PlannerAttachmentEditor: View {
    @Binding var attachments: [PlannerAttachment]
    @State private var preview: URL?
    @State private var previewDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlannerAttachment-" + UUID().uuidString, isDirectory: true)
    @State private var importing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Attachments").font(.headline)
                Spacer()
                Button("Add file…") { importing = true }
            }
            ForEach(attachments) { attachment in
                HStack {
                    Button(attachment.name) { open(attachment) }
                        .buttonStyle(.link)
                    Spacer()
                    Button {
                        if preview?.deletingLastPathComponent().lastPathComponent == attachment.id.uuidString {
                            preview = nil
                        }
                        attachments.removeAll { $0.id == attachment.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .accessibilityLabel("Remove " + attachment.name)
                }
            }
        }
        .quickLookPreview($preview)
        .onChange(of: preview) { previous, current in
            if let previous, previous != current {
                try? FileManager.default.removeItem(at: previous)
            }
        }
        .onDisappear {
            preview = nil
            try? FileManager.default.removeItem(at: previewDirectory)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            do {
                let imported = try result.get().map { url in
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    return PlannerAttachment(name: url.lastPathComponent, data: try Data(contentsOf: url))
                }
                attachments.append(contentsOf: imported)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Attachment error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func open(_ attachment: PlannerAttachment) {
        do {
            let directory = previewDirectory.appendingPathComponent(attachment.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let filename = (attachment.name as NSString).lastPathComponent
            guard !["", ".", "..", "/"].contains(filename) else { throw CocoaError(.fileReadInvalidFileName) }
            let url = directory.appendingPathComponent(filename)
            try attachment.data.write(to: url, options: .atomic)
            preview = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
