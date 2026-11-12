import SwiftUI

struct RecoveryView: View {
    @ObservedObject var recovery: PlannerRecovery
    @State private var selection: RecoveryPoint?

    var body: some View {
        Form {
            Section("iCloud Drive") {
                if let folder = recovery.syncFolder {
                    LabeledContent("Sync folder", value: folder.lastPathComponent)
                    if let date = recovery.lastSync {
                        LabeledContent("Last sync") { Text(date.formatted()) }
                    }
                    HStack {
                        Button("Sync Now") { recovery.refresh() }
                        Button("Stop Sync") { recovery.stopSync() }
                    }
                } else {
                    Button("Choose iCloud Drive Folder…") { recovery.chooseSyncFolder() }
                }
            }
            Section("Automatic Backups") {
                if recovery.backups.isEmpty { Text("No backups available.") }
                ForEach(recovery.backups.prefix(30)) { point in
                    HStack {
                        Text(point.date.formatted(date: .abbreviated, time: .standard))
                        Spacer()
                        Button("Restore…") { selection = point }
                    }
                }
            }
            if let message = recovery.message { Text(message).foregroundStyle(.secondary) }
        }
        .formStyle(.grouped)
        .alert("Restore this backup?", isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } }),
               presenting: selection) { point in
            Button("Restore", role: .destructive) { Task { await recovery.restore(point) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This replaces the library on this Mac. If sync is enabled, these changes will also sync to your other Macs.")
        }
    }
}
