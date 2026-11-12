import EventKit
import SwiftUI

struct CalendarSourcesView: View {
    @ObservedObject var store: SystemCalendarStore
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendars").font(.headline)
            if store.authorization == .fullAccess {
                if store.calendars.isEmpty {
                    Text("No calendars available.").foregroundStyle(.secondary)
                }
                ForEach(store.calendars, id: \.calendarIdentifier) { calendar in
                    Toggle(isOn: Binding(get: { store.shows(calendar) },
                                         set: { store.setVisible($0, calendar: calendar) })) {
                        VStack(alignment: .leading) {
                            Text(calendar.title)
                            Text(calendar.source?.title ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else if store.authorization == .denied || store.authorization == .restricted {
                Text("Calendar access is disabled in System Settings.")
                Button("Open Calendar Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                Button("Connect Calendars") {
                    Task {
                        do { try await store.requestAccess() } catch { self.error = error.localizedDescription }
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .padding()
    }
}
