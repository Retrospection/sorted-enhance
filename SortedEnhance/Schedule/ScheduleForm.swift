import SwiftUI

struct ScheduleForm: View {
    var day: Date
    let cancel: () -> Void
    var apply: (Date, Date, Int, Int) -> Void

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

    private func minutes(_ text: String) -> Int? {
        if let count = Int(text) { return count }
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hours = Int(parts[0]), (0...24).contains(hours),
              parts[1].count == 2, let minutes = Int(parts[1]), (0..<60).contains(minutes) else { return nil }
        return hours * 60 + minutes
    }

    private func durationString(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private var input: (start: Date, end: Date, buffer: Int, duration: Int)? {
        guard let start = time(from), let end = time(until), end > start,
              let minutes = minutes(bufferInput), (0...1440).contains(minutes),
              let duration = self.minutes(durationInput), (1...1440).contains(duration) else { return nil }
        return (start, end, minutes, duration)
    }

    private let secondaryText = Color(red: 0.73, green: 0.79, blue: 0.85)

    var body: some View {
        VStack(spacing: 0) {
            Text("Auto Schedule")
                .font(.system(size: 16, weight: .bold))
                .frame(height: 39)
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
            VStack(alignment: .leading, spacing: 0) {
                row("Start at", identifier: "Schedule from", text: $from)
                row("End at", identifier: "Finish by", text: $until)
                row("Buffer", identifier: "Buffer", text: $bufferInput)
                explanation("Time to leave between scheduled items.")
                row("Default duration", identifier: "Default duration", text: $durationInput)
                explanation("Time to allow for tasks without a duration.")
            }
            .padding(.top, 26)
            Spacer(minLength: 6)
            Button {
                guard let input else { return }
                buffer = input.buffer
                defaultDuration = input.duration
                apply(input.start, input.end, input.buffer, input.duration)
            } label: {
                Text("Start")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.10, green: 0.15, blue: 0.20))
            .background(Color(red: 0.36, green: 0.87, blue: 0.98), in: RoundedRectangle(cornerRadius: 6))
            .disabled(input == nil)
            .opacity(input == nil ? 0.55 : 1)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("Apply")
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: 440)
        .frame(height: 400)
        .background(Color(red: 0.153, green: 0.204, blue: 0.267), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.22), radius: 12, y: 4)
        .onExitCommand(perform: cancel)
        .accessibilityAction(.escape, cancel)
        .onAppear {
            durationInput = durationString(defaultDuration)
            bufferInput = durationString(buffer)
        }
    }

    private func row(_ label: LocalizedStringKey, identifier: String, text: Binding<String>) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .foregroundStyle(secondaryText)
                .frame(width: 146, alignment: .trailing)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
            Spacer(minLength: 0)
        }
        .font(.system(size: 15))
        .padding(.horizontal, 6)
        .frame(height: 40)
    }

    private func explanation(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(secondaryText)
            .frame(maxWidth: 220, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 166)
            .frame(minHeight: 48, alignment: .topLeading)
    }
}
