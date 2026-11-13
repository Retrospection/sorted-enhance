import AppKit
import Combine
import SwiftUI

@MainActor
final class PlannerRecovery: ObservableObject {
    @Published private(set) var backups: [RecoveryPoint] = []
    @Published private(set) var syncFolder: URL?
    @Published private(set) var lastSync: Date?
    @Published private(set) var message: String?

    private let store: PlannerStore
    private let files: RecoveryFiles
    private let bookmarkKey = "plannerSyncFolderBookmark"
    private let requests: AsyncStream<Void>.Continuation
    private var changes: AnyCancellable?
    private var timer: AnyCancellable?

    init(store: PlannerStore) {
        self.store = store
        let support = URL.applicationSupportDirectory.appending(path: "SortedEnhance/Recovery")
        files = RecoveryFiles(directory: support)
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        requests = continuation
        if let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) {
            do {
                var stale = false
                let folder = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                                     relativeTo: nil, bookmarkDataIsStale: &stale)
                if stale { try saveBookmark(for: folder) }
                syncFolder = folder
            } catch { message = error.localizedDescription }
        }
        changes = store.$snapshot.sink { _ in continuation.yield(()) }
        timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect().sink { _ in continuation.yield(()) }
        Task { [weak self] in
            for await _ in stream {
                guard let self else { return }
                await self.service()
            }
        }
    }

    deinit { requests.finish() }

    func refresh() { requests.yield(()) }

    func chooseSyncFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        panel.message = "Select the same folder in iCloud Drive on each Mac."
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        do {
            guard FileManager.default.isUbiquitousItem(at: folder) else {
                throw RecoveryError.chooseCloudFolder
            }
            try saveBookmark(for: folder)
            syncFolder = folder
            lastSync = nil
            refresh()
        } catch { message = error.localizedDescription }
    }

    func stopSync() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        syncFolder = nil
        lastSync = nil
    }

    func restore(_ point: RecoveryPoint) async {
        do {
            let candidate = try await files.readBackup(at: point.id)
            _ = try await files.backup(store.libraryIsReadable ? store.snapshot : nil)
            guard store.restore(candidate) else { throw RecoveryError.restoreFailed }
            message = nil
            refresh()
        } catch { message = error.localizedDescription }
    }

    private func saveBookmark(for folder: URL) throws {
        let data = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    private func service() async {
        do {
            let snapshot = store.snapshot
            backups = try await files.backup(store.libraryIsReadable ? snapshot : nil)
            guard store.libraryIsReadable, let folder = syncFolder else { return }
            let access = folder.startAccessingSecurityScopedResource()
            defer { if access { folder.stopAccessingSecurityScopedResource() } }
            guard FileManager.default.isUbiquitousItem(at: folder) else { throw RecoveryError.unavailable }
            var replica = try await files.prepare(snapshot: snapshot, folder: folder)
            let merged = try replica.document.snapshot()
            guard folder == syncFolder, store.snapshot == snapshot else { refresh(); return }
            if merged != snapshot, !store.applySyncedSnapshot(merged) { throw RecoveryError.restoreFailed }
            replica.baseline = merged
            try await files.store(replica, folder: folder)
            try await files.publish(replica, folder: folder)
            lastSync = Date()
            message = nil
        } catch { message = error.localizedDescription }
    }

    private enum RecoveryError: LocalizedError {
        case chooseCloudFolder, unavailable, restoreFailed

        var errorDescription: String? {
            switch self {
            case .chooseCloudFolder: "Choose a folder inside iCloud Drive."
            case .unavailable: "The iCloud Drive folder is unavailable. Changes are saved locally."
            case .restoreFailed: "The library could not be restored. Check the library error for details."
            }
        }
    }
}
