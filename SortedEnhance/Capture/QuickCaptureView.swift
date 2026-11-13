import SwiftUI

struct QuickCaptureView: View {
    @ObservedObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var draft = PlannerItem(title: "")
    @State private var includesDay = false
    @State private var includesTime = false
    @State private var date = Date()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Entry").font(.title2)
            TextField("Task, for example Send invoice tomorrow at 8am", text: $text)
                .focused($focused)
                .onChange(of: text) {
                    let entry = QuickEntry(text)
                    draft.title = entry.title
                    includesDay = entry.day != nil
                    includesTime = entry.start != nil
                    date = entry.start ?? entry.day ?? .now
                }

            if !text.isEmpty {
                TextField("Title", text: $draft.title)
                Toggle("Assign date", isOn: $includesDay)
                if includesDay {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Set start time", isOn: $includesTime)
                    if includesTime {
                        DatePicker("Start time", selection: $date, displayedComponents: .hourAndMinute)
                        TaskAlertPicker(item: $draft)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add Task") {
                    draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft.day = includesDay ? Calendar.current.startOfDay(for: date) : nil
                    draft.start = includesDay && includesTime ? date : nil
                    if draft.start == nil { draft.reminderOffsetMinutes = nil }
                    if store.save(draft) { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(minWidth: 430)
        .onAppear { focused = true }
    }
}

struct TaskAlertPicker: View {
    @Binding var item: PlannerItem
    @State private var error: String?

    var body: some View {
        Picker("Alert", selection: $item.reminderOffsetMinutes) {
            Text("None").tag(Int?.none)
            ForEach(offsets, id: \.self) { offset in
                Text(offset == 0 ? "At start" : "\(offset) minutes before").tag(Optional(offset))
            }
        }
        .onChange(of: item.reminderOffsetMinutes) { _, newValue in
            guard newValue != nil else { return }
            Task {
                do {
                    if try await !PlannerNotifications.requestPermission() {
                        error = "Enable notifications for Sorted Enhance in System Settings."
                    }
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
        .alert("Task alerts", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var offsets: [Int] {
        Array(Set([0, 5, 10, 15, 30, 60] + [item.reminderOffsetMinutes].compactMap { $0 })).sorted()
    }
}
