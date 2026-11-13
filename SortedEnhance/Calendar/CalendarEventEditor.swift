import EventKit
import SwiftUI

struct CalendarEventEditor: View {
    @ObservedObject var store: SystemCalendarStore
    private let initialStart: Date
    let taskDraft: PlannerItem?
    let onClose: (() -> Void)?
    let onSwitchToTask: ((PlannerItem, EventCreationDraft) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool
    @State private var alertMinutes: Int?
    @State private var showNotes = false
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

    init(store: SystemCalendarStore, day: Date, event: PlannerCalendarEvent? = nil,
         taskDraft: PlannerItem? = nil, eventFields: EventCreationDraft? = nil, onClose: (() -> Void)? = nil,
         onSwitchToTask: ((PlannerItem, EventCreationDraft) -> Void)? = nil) {
        self.store = store
        self.taskDraft = taskDraft
        self.onClose = onClose
        self.onSwitchToTask = onSwitchToTask
        let calendar = Calendar.current
        let date = taskDraft?.day ?? day
        let start = event?.start ?? taskDraft?.start ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        initialStart = start
        _alertMinutes = State(initialValue: event?.alertMinutesBefore ?? taskDraft?.reminderOffsetMinutes)
        _original = State(initialValue: event)
        _annotationOwner = State(initialValue: event)
        _title = State(initialValue: event?.title ?? taskDraft?.title ?? "")
        _day = State(initialValue: start)
        _clock = State(initialValue: String(format: "%02d:%02d", calendar.component(.hour, from: start),
                                           calendar.component(.minute, from: start)))
        _duration = State(initialValue: event.map { max(1, Int($0.end.timeIntervalSince($0.start) / 60)) } ?? taskDraft?.duration ?? 30)
        let fields = EventCreationDraft.fields(for: taskDraft, previous: eventFields,
                                              defaultCalendarID: store.defaultCalendarID ?? "", start: start)
        _calendarID = State(initialValue: event?.calendarID ?? fields.calendarID)
        _repeatFrequency = State(initialValue: fields.repeatFrequency)
        _allDay = State(initialValue: event?.isAllDay ?? fields.allDay)
        _lastDay = State(initialValue: event.flatMap { $0.isAllDay ? $0.end.addingTimeInterval(-1) : nil } ?? fields.lastDay)
        _notes = State(initialValue: event?.notes ?? fields.calendarNotes)
        if let taskDraft {
            _annotation = State(initialValue: EventAnnotation(notes: taskDraft.notes, richNotes: taskDraft.richNotes,
                                                              attachments: taskDraft.attachments ?? []))
        }
    }

    private var header: some View {
        let switchKind: (() -> Void)? = onSwitchToTask.map { _ in { switchToTask() } }
        return PlannerEditorHeader(kind: .event, creating: original == nil, close: { close() }, switchKind: switchKind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            TextField("Title", text: $title)
                .font(.system(size: 20, weight: .medium))
                .textFieldStyle(.plain)
                .accessibilityIdentifier("Title")
                .focused($titleFocused)
                .disabled(original?.isWritable == false)
            if store.authorization != .fullAccess {
                CalendarSourcesView(store: store)
            } else {
                calendarFields
                    .disabled(original?.isWritable == false)
                DisclosureGroup("Notes and attachments", isExpanded: $showNotes) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Calendar notes", text: $notes, axis: .vertical)
                            .disabled(original?.isWritable == false)
                        PlannerNoteEditor(notes: $annotation.notes, richNotes: $annotation.richNotes)
                        PlannerAttachmentEditor(attachments: $annotation.attachments)
                    }
                    .padding(.vertical, 6)
                    .disabled(!annotationLoaded)
                }
                .font(.system(size: 12))
            }
            if let error { Text(error).font(.callout).foregroundStyle(.red) }
            HStack {
                if let event = original, event.isWritable {
                    Button("Delete", role: .destructive) { remove(event) }.buttonStyle(.plain)
                }
                Spacer()
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("Save")
                    .disabled(store.authorization != .fullAccess || !annotationLoaded ||
                              (original?.isWritable != false && (calendarID.isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .onAppear {
            titleFocused = original == nil
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

    private var calendarFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("calendar") {
                Picker("Calendar", selection: $calendarID) {
                    ForEach(store.calendars.filter { $0.allowsContentModifications || $0.calendarIdentifier == original?.calendarID },
                            id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                }
                .labelsHidden().accessibilityIdentifier("Calendar")
                if store.writableCalendars.isEmpty, original == nil {
                    Text("Create a writable calendar in Calendar.").foregroundStyle(.secondary)
                }
            }
            row("calendar.day.timeline.left") {
                DatePicker("Date", selection: $day, displayedComponents: .date).labelsHidden()
                    .accessibilityLabel("Date")
                Toggle("All day", isOn: $allDay)
                if allDay {
                    DatePicker("Last day", selection: $lastDay, in: Calendar.current.startOfDay(for: day)...,
                               displayedComponents: .date)
                } else {
                    TextField("Start time", text: $clock).frame(width: 60)
                        .accessibilityIdentifier("Start time")
                    TextField("Duration", value: $duration, format: .number.grouping(.never)).frame(width: 44)
                        .accessibilityIdentifier("Duration")
                    Text("min").foregroundStyle(.secondary)
                }
            }
            row("bell") {
                Picker("Alert", selection: $alertMinutes) {
                    Text("No alert").tag(nil as Int?)
                    ForEach(Array(Set([0, 5, 10, 15, 30, 60, 1_440] + [alertMinutes].compactMap { $0 })).sorted(), id: \.self) { minutes in
                        if minutes == 0 { Text("At start time").tag(Optional(minutes)) }
                        else { Text("\(minutes) min before").tag(Optional(minutes)) }
                    }
                }
                .labelsHidden().accessibilityLabel("Alert")
            }
            if original == nil {
                row("repeat") {
                    Picker("Repeat", selection: $repeatFrequency) {
                        Text("Never repeat").tag(nil as EKRecurrenceFrequency?)
                        Text("Daily").tag(Optional(EKRecurrenceFrequency.daily))
                        Text("Weekly").tag(Optional(EKRecurrenceFrequency.weekly))
                        Text("Monthly").tag(Optional(EKRecurrenceFrequency.monthly))
                        Text("Yearly").tag(Optional(EKRecurrenceFrequency.yearly))
                    }
                    .labelsHidden().accessibilityLabel("Repeat")
                }
            } else if original?.isRecurring == true {
                Text("Changes apply to this occurrence.").foregroundStyle(.secondary)
            }
        }
        .controlSize(.small)
        .font(.system(size: 12))
    }

    private func row<Fields: View>(_ icon: String, @ViewBuilder fields: () -> Fields) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 16).accessibilityHidden(true)
            fields()
        }
        .frame(minHeight: 19)
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func switchToTask() {
        guard let onSwitchToTask, original == nil else { return }
        do {
            var item = taskDraft ?? PlannerItem(title: title)
            let (start, _) = try interval()
            item.title = title
            if taskDraft == nil || allDay || !Calendar.current.isDate(initialStart, equalTo: start, toGranularity: .minute) {
                item.day = Calendar.current.startOfDay(for: start)
                item.start = allDay ? nil : start
            }
            if taskDraft == nil || duration != (taskDraft?.duration ?? 30) { item.duration = duration }
            item.reminderOffsetMinutes = alertMinutes
            item.notes = annotation.notes
            item.richNotes = annotation.richNotes
            item.attachments = annotation.attachments.isEmpty ? nil : annotation.attachments
            onSwitchToTask(item, EventCreationDraft(taskID: item.id, calendarID: calendarID,
                        repeatFrequency: repeatFrequency, allDay: allDay, lastDay: lastDay, calendarNotes: notes))
        } catch { self.error = error.localizedDescription }
    }

    private func interval() throws -> (Date, Date) {
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
        return (start, end)
    }

    private func save() {
        do {
            let (start, end) = try interval()
            if original?.isWritable != false, original?.title != title || original?.start != start ||
                original?.end != end || original?.isAllDay != allDay || original?.notes != notes ||
                original?.calendarID != calendarID || original?.alertMinutesBefore != alertMinutes {
                original = try store.save(original, title: title, start: start, end: end, allDay: allDay,
                                          calendarID: calendarID, notes: notes, repeatFrequency: repeatFrequency,
                                          alertMinutesBefore: alertMinutes)
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
            close()
        } catch { self.error = error.localizedDescription }
    }

    private func remove(_ event: PlannerCalendarEvent) {
        do {
            try store.delete(event)
            try EventAnnotationStore.applicationStore().write(EventAnnotation(), for: event.annotationIdentity)
            close()
        } catch { self.error = error.localizedDescription }
    }
}
