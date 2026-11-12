import SwiftUI

struct ScheduleForm: View {
    var day: Date
    var apply: (Date, Date, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var from = "09:00"
    @State private var until = "23:55"
    @AppStorage("scheduleBuffer") private var buffer = 0
    @State private var bufferInput = ""
    @AppStorage("scheduleDefaultDuration") private var defaultDuration = DayPlanner.standardDuration
    @State private var durationInput = ""

    private func time(_ text: String) -> Date? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        let calendar = Calendar.current
        if hour == 24 && minute == 0 {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))
        }
        guard (0..<24).contains(hour), (0..<60).contains(minute),
              let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
              calendar.component(.hour, from: date) == hour else { return nil }
        return date
    }

    private var input: (start: Date, end: Date, buffer: Int, duration: Int)? {
        guard let start = time(from), let end = time(until), end > start,
              let minutes = Int(bufferInput), (0...1440).contains(minutes),
              let duration = Int(durationInput), (1...1440).contains(duration) else { return nil }
        return (start, end, minutes, duration)
    }

    var body: some View {
        Form {
            TextField("Schedule from", text: $from)
                .accessibilityLabel("Schedule from")
                .accessibilityIdentifier("Schedule from")
            TextField("Finish by", text: $until)
                .accessibilityLabel("Finish by")
                .accessibilityIdentifier("Finish by")
            TextField("Buffer", text: $bufferInput)
                .accessibilityLabel("Buffer")
                .accessibilityIdentifier("Buffer")
            TextField("Default duration", text: $durationInput)
                .accessibilityLabel("Default duration")
                .accessibilityIdentifier("Default duration")
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply") {
                    guard let input else { return }
                    buffer = input.buffer
                    defaultDuration = input.duration
                    apply(input.start, input.end, input.buffer, input.duration)
                    dismiss()
                }
                .disabled(input == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 260)
        .padding()
        .onAppear {
            durationInput = String(defaultDuration)
            bufferInput = String(buffer)
        }
    }
}
