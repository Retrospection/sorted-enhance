import SwiftUI

struct ScheduleForm: View {
    var day: Date
    var apply: (Date, Date, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var from = ""
    @State private var until = "24:00"
    @AppStorage("scheduleBuffer") private var buffer = 0
    @State private var bufferInput = ""

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

    private var input: (start: Date, end: Date, minutes: Int)? {
        guard let start = time(from), let end = time(until), end > start,
              let minutes = Int(bufferInput), (0...1440).contains(minutes) else { return nil }
        return (start, end, minutes)
    }

    var body: some View {
        Form {
            TextField("Schedule from", text: $from)
            TextField("Finish by", text: $until)
            TextField("Buffer", text: $bufferInput)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply") {
                    guard let input else { return }
                    buffer = input.minutes
                    apply(input.start, input.end, input.minutes)
                    dismiss()
                }
                .disabled(input == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 260)
        .padding()
        .onAppear {
            let now = Date()
            let components = Calendar.current.dateComponents([.hour, .minute], from: now)
            from = Calendar.current.isDateInToday(day) ? String(format: "%02d:%02d", components.hour ?? 9, components.minute ?? 0) : "09:00"
            bufferInput = String(buffer)
        }
    }
}
