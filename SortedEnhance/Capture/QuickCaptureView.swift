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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Quick Entry")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel")
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 18)
            .frame(height: 48)

            TextField("Task, for example Send invoice tomorrow at 8am", text: $text)
                .font(.system(size: 16, weight: .medium))
                .textFieldStyle(.plain)
                .focused($focused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .onChange(of: text) {
                    let entry = QuickEntry(text)
                    draft.title = entry.title
                    includesDay = entry.day != nil
                    includesTime = entry.start != nil
                    date = entry.start ?? entry.day ?? .now
                }

            if !text.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Title", systemImage: "pencil")
                            .foregroundStyle(.secondary)
                        TextField("Title", text: $draft.title)
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Title")
                    }
                    HStack {
                        Toggle("Assign date", isOn: $includesDay)
                        Spacer()
                        if includesDay {
                            DatePicker("Date", selection: $date, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    if includesDay {
                        HStack {
                            Toggle("Set start time", isOn: $includesTime)
                            Spacer()
                            if includesTime {
                                DatePicker("Start time", selection: $date, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        if includesTime { TaskAlertPicker(item: $draft) }
                    }
                }
                .controlSize(.small)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }

            Divider()
            HStack {
                Spacer()
                Button("Add Task", action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(width: 470)
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear { focused = true }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.day = includesDay ? Calendar.current.startOfDay(for: date) : nil
        draft.start = includesDay && includesTime ? date : nil
        if draft.start == nil { draft.reminderOffsetMinutes = nil }
        if store.save(draft) { dismiss() }
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
