import CryptoKit
import Foundation

struct PlannerBackup: Codable {
    let version: Int
    let digest: String
    let payload: Data

    init(snapshot: PlannerSnapshot) throws {
        version = 1
        payload = try JSONEncoder().encode(snapshot)
        digest = Self.hash(payload)
    }

    func snapshot() throws -> PlannerSnapshot {
        guard version == 1, Self.hash(payload) == digest else { throw CocoaError(.fileReadCorruptFile) }
        let result = try JSONDecoder().decode(PlannerSnapshot.self, from: payload)
        try result.validate()
        return result
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct RecoveryPoint: Identifiable, Sendable {
    let id: URL
    let date: Date
}

actor RecoveryFiles {
    struct Replica: Codable, Sendable {
        let format: Int
        let writer: UUID
        var baseline: PlannerSnapshot
        var document: SyncDocument
    }

    private let root: URL
    private let fm = FileManager.default
    private var previousBackup: PlannerSnapshot?

    init(directory: URL) { root = directory }

    func backup(_ snapshot: PlannerSnapshot?) throws -> [RecoveryPoint] {
        let backups = root.appending(path: "Backups", directoryHint: .isDirectory)
        try fm.createDirectory(at: backups, withIntermediateDirectories: true)
        func points() throws -> [RecoveryPoint] {
            try fm.contentsOfDirectory(at: backups, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "sortedbackup" }
                .map { url in
                    let date = try url.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
                    return RecoveryPoint(id: url, date: date)
                }
                .sorted { $0.date > $1.date }
        }
        var existing = try points()
        if previousBackup == nil, let latest = existing.first {
            previousBackup = try? readBackup(at: latest.id)
        }
        if let snapshot, previousBackup != snapshot {
            let destination = backups.appending(path: UUID().uuidString + ".sortedbackup")
            let data = try JSONEncoder().encode(PlannerBackup(snapshot: snapshot))
            try data.write(to: destination, options: .atomic)
            previousBackup = snapshot
            existing = try points()
            for old in existing.dropFirst(30) { try fm.removeItem(at: old.id) }
        }
        return Array(existing.prefix(30))
    }

    func readBackup(at file: URL) throws -> PlannerSnapshot {
        try JSONDecoder().decode(PlannerBackup.self, from: Data(contentsOf: file)).snapshot()
    }

    private func ledgerURL(_ folder: URL) -> URL {
        let key = PlannerBackup.hash(Data(folder.standardizedFileURL.path.utf8))
        return root.appending(path: "replica-" + key + ".json")
    }

    func prepare(snapshot: PlannerSnapshot, folder: URL) throws -> Replica {
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let ledger = ledgerURL(folder)
        var replica: Replica
        if fm.fileExists(atPath: ledger.path) {
            replica = try JSONDecoder().decode(Replica.self, from: Data(contentsOf: ledger))
            guard replica.format == 1 else { throw CocoaError(.fileReadUnknown) }
        } else {
            replica = Replica(format: 1, writer: UUID(), baseline: PlannerSnapshot(), document: SyncDocument())
        }
        if snapshot != replica.baseline || !fm.fileExists(atPath: ledger.path) {
            try replica.document.record(snapshot, after: replica.baseline, writer: replica.writer)
            replica.baseline = snapshot
            try store(replica, folder: folder)
        }

        let cloud = folder.appending(path: "SortedEnhanceSync", directoryHint: .isDirectory)
        try fm.createDirectory(at: cloud, withIntermediateDirectories: true)
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey]
        for file in try fm.contentsOfDirectory(at: cloud, includingPropertiesForKeys: Array(keys)) {
            guard file.pathExtension == "sortedreplica" else {
                if file.lastPathComponent.hasSuffix(".sortedreplica.icloud") {
                    let name = file.lastPathComponent.dropFirst().dropLast(".icloud".count)
                    try fm.startDownloadingUbiquitousItem(at: cloud.appending(path: String(name)))
                }
                continue
            }
            if try file.resourceValues(forKeys: keys).ubiquitousItemDownloadingStatus == .notDownloaded {
                try fm.startDownloadingUbiquitousItem(at: file)
                continue
            }
            let data = try coordinatedRead(file)
            let remote = try JSONDecoder().decode(CloudReplica.self, from: data)
            guard remote.format == 1 else { throw CocoaError(.fileReadUnknown) }
            replica.document.merge(remote.document)
        }
        return replica
    }

    func publish(_ replica: Replica, folder: URL) throws {
        let file = folder.appending(path: "SortedEnhanceSync")
            .appending(path: replica.writer.uuidString + ".sortedreplica")
        let payload = CloudReplica(format: 1, document: replica.document)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(payload)
        var failure: NSError?
        var result: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forReplacing, error: &failure) { url in
            result = Result {
                if fm.fileExists(atPath: url.path), try Data(contentsOf: url) == data { return }
                try data.write(to: url, options: .atomic)
            }
        }
        if let failure { throw failure }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        try result.get()
    }

    func store(_ replica: Replica, folder: URL) throws {
        let url = ledgerURL(folder)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(replica)
        if fm.fileExists(atPath: url.path), try Data(contentsOf: url) == data { return }
        try data.write(to: url, options: .atomic)
    }

    private struct CloudReplica: Codable {
        let format: Int
        let document: SyncDocument
    }

    private func coordinatedRead(_ file: URL) throws -> Data {
        var failure: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &failure) { url in
            result = Result { try Data(contentsOf: url) }
        }
        if let failure { throw failure }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }
}
