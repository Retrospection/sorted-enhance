import SwiftUI

struct PlannerFeedbackSettingsRows: View {
    @AppStorage(PlannerFeedbackKey.alerts) private var alertsEnabled = true
    @AppStorage(PlannerFeedbackKey.sound) private var sound = TaskAlertSound.system
    @AppStorage(PlannerFeedbackKey.completion) private var completion = true
    @AppStorage(PlannerFeedbackKey.badge) private var badge = PlannerBadgeMode.overdue
    @State private var requesting = false
    @State private var permissionError: LocalizedStringKey?

    var body: some View {
        Group {
            SettingsRow("Task alerts", icon: "bell.fill", color: .green) {
                Toggle("Task alerts", isOn: Binding(get: { alertsEnabled }, set: { setAlertsEnabled($0) }))
                    .disabled(requesting)
            }
            SettingsRow("Alert sound", icon: "speaker.wave.2.fill", color: .purple) {
                Picker("Alert sound", selection: $sound) {
                    Text("System default").tag(TaskAlertSound.system)
                    Text("Silent").tag(TaskAlertSound.silent)
                }
                .disabled(!alertsEnabled)
            }
            SettingsRow("App badge", icon: "app.badge", color: .red) {
                Picker("App badge", selection: $badge) {
                    Text("Off").tag(PlannerBadgeMode.off)
                    Text("Overdue").tag(PlannerBadgeMode.overdue)
                    Text("Overdue + Anytime").tag(PlannerBadgeMode.overdueAndAnytime)
                    Text("Today").tag(PlannerBadgeMode.today)
                }
            }
            SettingsRow("Completion sound", icon: "speaker.wave.1.fill", color: .yellow) {
                Toggle("Completion sound", isOn: $completion)
            }
        }
        .toggleStyle(.switch)
        .labelsHidden()
        .alert("Task alerts", isPresented: Binding(
            get: { permissionError != nil },
            set: { if !$0 { permissionError = nil } }
        )) {
            Button("OK") { permissionError = nil }
        } message: {
            if let permissionError { Text(permissionError) }
        }
    }

    private func setAlertsEnabled(_ enabled: Bool) {
        guard enabled else {
            alertsEnabled = false
            return
        }
        requesting = true
        Task {
            defer { requesting = false }
            do {
                alertsEnabled = try await PlannerNotifications.requestPermission()
                if !alertsEnabled {
                    permissionError = "Allow task alerts in System Settings to receive reminders."
                }
            } catch {
                permissionError = "Could not change notification authorization."
            }
        }
    }
}
