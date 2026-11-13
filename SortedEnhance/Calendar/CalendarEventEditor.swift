import EventKit
import SwiftUI

struct CalendarEventEditor: View {
    @ObservedObject var store: SystemCalendarStore
    @Environment(\.dismiss) private var dismiss
    @State private var original: PlannerCalendarEvent?
    @State private var title: String
    @State private var day: Date
    @State private var clock: String
    @State private var duration: Int
    @State private var calendarID: String
    @State private var allDay: Bool
    @State private var lastDay: Date
    @State private var notes: String
    @State private var repeatFrequency: EKRecurrenceFrequency?
    @State private var annotation = EventAnnotation()
    @State private var loadedAnnotation = EventAnnotation()
    @State private var annotationOwner: PlannerCalendarEvent?
    @State private var annotationLoaded = false
    @State private var error: String?

    init(store: SystemCalendarStore, day: Date, event: PlannerCalendarEvent? = nil) {
        self.store = store
        let calendar = Calendar.current
        let start = event?.start ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        _original = State(initialValue: event)
        _annotationOwner = State(initialValue: event)
        _title = State(initialValue: event?.title ?? "")
        _day = State(initialValue: start)
        _clock = State(initialValue: String(format: "%02d:%02d", calendar.component(.hour, from: start),
                                           calendar.component(.minute, from: start)))
        _duration = State(initialValue: event.map { max(1, Int($0.end.timeIntervalSince($0.start) / 60)) } ?? 30)
        _calendarID = State(initialValue: event?.calendarID ?? store.defaultCalendarID ?? "")
        _allDay = State(initialValue: event?.isAllDay ?? false)
        _lastDay = State(initialValue: event.flatMap { $0.isAllDay ? $0.end.addingTimeInterval(-1) : nil } ?? start)
        _notes = State(initialValue: event?.notes ?? "")
    }

    var body: some View {
        VStack {
            if store.authorization != .fullAccess {
                CalendarSourcesView(store: store)
            } else {
                Form {
                    Section("Calendar Event") {
                        Picker("Calendar", selection: $calendarID) {
                            ForEach(store.calendars.filter { $0.allowsContentModifications || $0.calendarIdentifier == original?.calendarID },
                                    id: \.calendarIdentifier) { calendar in
                                Text(calendar.title).tag(calendar.calendarIdentifier)
                            }
                        }
                        TextField("Title", text: $title)
                        DatePicker("Date", selection: $day, displayedComponents: .date)
                        Toggle("All day", isOn: $allDay)
                        if allDay {
                            DatePicker("Last day", selection: $lastDay, in: Calendar.current.startOfDay(for: day)...,
                                       displayedComponents: .date)
                        } else {
                            TextField("Start time", text: $clock)
                            TextField("Duration", value: $duration, format: .number)
                        }
                        if original == nil {
                            Picker("Repeat", selection: $repeatFrequency) {
                                Text("Never").tag(nil as EKRecurrenceFrequency?)
                                Text("Daily").tag(Optional(EKRecurrenceFrequency.daily))
                                Text("Weekly").tag(Optional(EKRecurrenceFrequency.weekly))
                                Text("Monthly").tag(Optional(EKRecurrenceFrequency.monthly))
                                Text("Yearly").tag(Optional(EKRecurrenceFrequency.yearly))
                            }
                        } else if original?.isRecurring == true {
                            Text("Changes apply to this occurrence.").foregroundStyle(.secondary)
                        }
                        TextField("Calendar notes", text: $notes, axis: .vertical)
                    }
                    .disabled(original?.isWritable == false)
                    Section("Planner Notes") {
                        PlannerNoteEditor(notes: $annotation.notes, richNotes: $annotation.richNotes)
                        PlannerAttachmentEditor(attachments: $annotation.attachments)
                    }
                    .disabled(!annotationLoaded)
                }
                .formStyle(.grouped)
            }
            if let error { Text(error).foregroundStyle(.red).padding(.horizontal) }
            HStack {
                if let event = original, event.isWritable {
                    Button("Delete", role: .destructive) { remove(event) }
                }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .disabled(store.authorization != .fullAccess || !annotationLoaded)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 480)
        .onAppear {
            do {
                if let event = original {
                    annotation = try store.annotation(for: event)
                    loadedAnnotation = annotation
                }
                annotationLoaded = true
            } catch { self.error = error.localizedDescription }
        }
        .onChange(of: store.defaultCalendarID) { _, id in
            if calendarID.isEmpty { calendarID = id ?? "" }
        }
    }

    private func save() {
        do {
            let calendar = Calendar.current
            let start: Date
            let end: Date
            if allDay {
                start = calendar.startOfDay(for: day)
                guard let next = calendar.date(byAdding: .day, value: 1,
                                               to: calendar.startOfDay(for: max(day, lastDay))) else {
                    throw CalendarEditError.invalidEvent
                }
                end = next
            } else {
                let originalStart = original.flatMap { $0.isAllDay ? nil : $0.start }
                guard duration > 0, let time = calendar.date(on: day, at: clock, preserving: originalStart) else {
                    throw CalendarEditError.invalidEvent
                }
                start = time
                if let original, !original.isAllDay, duration == max(1, Int(original.end.timeIntervalSince(original.start) / 60)) {
                    end = start.addingTimeInterval(original.end.timeIntervalSince(original.start))
                } else {
                    end = start.addingTimeInterval(TimeInterval(duration) * 60)
                }
            }
            if original?.isWritable != false, original?.title != title || original?.start != start ||
                original?.end != end || original?.isAllDay != allDay || original?.notes != notes ||
                original?.calendarID != calendarID {
                original = try store.save(original, title: title, start: start, end: end, allDay: allDay,
                                          calendarID: calendarID, notes: notes, repeatFrequency: repeatFrequency)
            }
            if let event = original, annotation != loadedAnnotation || event.annotationIdentity != annotationOwner?.annotationIdentity {
                let files = try EventAnnotationStore.applicationStore()
                try files.write(annotation, for: event.annotationIdentity)
                if let previous = annotationOwner?.annotationIdentity,
                   files.record(for: previous) != files.record(for: event.annotationIdentity) {
                    try files.write(EventAnnotation(), for: previous)
                }
                loadedAnnotation = annotation
                annotationOwner = event
            }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func remove(_ event: PlannerCalendarEvent) {
        do {
            try store.delete(event)
            try EventAnnotationStore.applicationStore().write(EventAnnotation(), for: event.annotationIdentity)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
