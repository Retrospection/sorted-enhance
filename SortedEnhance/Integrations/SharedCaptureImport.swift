import Foundation

extension PlannerStore {
    @MainActor
    func importSharedCaptures() {
        do {
            let folder = try SharedCapture.inbox()
            let files = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
            )
            for file in files where file.pathExtension == "json" {
                do {
                    let capture = try JSONDecoder().decode(SharedCapture.self, from: Data(contentsOf: file))
                    if !items.contains(where: { $0.id == capture.id }) {
                        let title = capture.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? capture.text
                        var item = PlannerItem(title: String(title.prefix(100)))
                        item.id = capture.id
                        if item.title != capture.text { item.notes = capture.text }
                        guard save(item) else { return }
                    }
                    try FileManager.default.removeItem(at: file)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // An installation without an app group has no shared inbox.
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
