import SwiftUI

struct RecoveryView: View {
    @ObservedObject var recovery: PlannerRecovery
    @State private var selection: RecoveryPoint?

    var body: some View {
        SettingsSection("iCloud Drive") {
            if let folder = recovery.syncFolder {
                SettingsRow("Sync folder", icon: "folder", color: .blue) {
                    Text(verbatim: folder.lastPathComponent)
                }
                if let date = recovery.lastSync {
                    SettingsRow("Last sync", icon: "clock", color: .teal) {
                        Text(date.formatted())
                    }
                }
                action("Sync Now", icon: "arrow.triangle.2.circlepath", color: .blue) { recovery.refresh() }
                action("Stop Sync", icon: "pause", color: .orange) { recovery.stopSync() }
            } else {
                action("Choose iCloud Drive Folder…", icon: "icloud", color: .blue) { recovery.chooseSyncFolder() }
            }
            if let message = recovery.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }

        SettingsSection("Automatic Backups") {
            if recovery.backups.isEmpty {
                SettingsRow("No backups available.", icon: "archivebox", color: .gray) { EmptyView() }
            }
            ForEach(recovery.backups.prefix(30)) { point in
                Button {
                    selection = point
                } label: {
                    SettingsRow(title: Text(point.date.formatted(date: .abbreviated, time: .standard)),
                                icon: "clock.arrow.circlepath", color: .purple) {
                        Text("Restore…")
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .alert("Restore this backup?", isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } }),
               presenting: selection) { point in
            Button("Restore", role: .destructive) { Task { await recovery.restore(point) } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This replaces the library on this Mac. If sync is enabled, these changes will also sync to your other Macs.")
        }
    }

    private func action(_ title: LocalizedStringKey, icon: String, color: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            SettingsRow(title, icon: icon, color: color) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
    }
}
