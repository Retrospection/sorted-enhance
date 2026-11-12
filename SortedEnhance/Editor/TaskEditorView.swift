import SwiftUI

struct TaskEditorView: View {
    @ObservedObject var store: PlannerStore
    var onClose: (() -> Void)?
    var onNewEvent: ((PlannerItem) -> Void)?
    @State private var popover: EditorPopover?
    @State private var expandedNotes = false
    @Environment(\.dismiss) private var dismiss
    @State private var openingItem: PlannerItem?
    @State private var draft: PlannerItem
    @State private var timeText: String
    @State private var durationText: String
    @State private var repeatScope = RecurrenceScope.occurrence
    @State private var extractedTitles: [String] = []
    @State private var validationMessage: String?
    @FocusState private var titleFocused: Bool

    init(item: PlannerItem, store: PlannerStore, onClose: (() -> Void)? = nil, onNewEvent: ((PlannerItem) -> Void)? = nil) {
        self.onClose = onClose
        self.onNewEvent = onNewEvent
        self.store = store
        _openingItem = State(initialValue: store.items.contains { $0.id == item.id } ? item : nil)
        _draft = State(initialValue: item)
        _timeText = State(initialValue: item.start.map(Self.formatTime) ?? "")
        _durationText = State(initialValue: item.duration.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            PlannerEditorHeader(kind: .task, creating: openingItem == nil, close: close,
                                switchKind: onNewEvent.map { action in { switchToEvent(action) } })
            HStack(spacing: 7) {
                Button(action: toggleCompletion) {
                    Image(systemName: draft.status == .active ? "square" : "checkmark.square.fill")
                }
                .accessibilityLabel(draft.status == .active ? "Complete" : "Reopen")
                .accessibilityIdentifier(draft.status == .active ? "Complete" : "Reopen")
                .foregroundStyle(.secondary)
                .disabled(draft.deleted)
                TextField("Title", text: $draft.title)
                    .textFieldStyle(.plain).font(.system(size: 16, weight: .medium))
                    .accessibilityIdentifier("Title")
                    .focused($titleFocused)
                    .onSubmit { save(draft) }
            }
            PlannerNoteEditor(notes: $draft.notes, richNotes: $draft.richNotes,
                              extractedTitles: $extractedTitles, compact: !expandedNotes)
                .padding(.leading, 15)
            if !extractedTitles.isEmpty {
                Text("New tasks: " + extractedTitles.joined(separator: ", ")).font(.callout)
            }
            HStack(spacing: 6) {
                pill("tray", title: Text(store.lists.first { $0.id == draft.listID }?.name ?? String(localized: "Inbox"))) {
                    popover = .organization
                }
                .popover(isPresented: presented(.organization)) { organization }
                pill("tag", title: draft.tags.isEmpty ? Text("Tags") : Text(draft.tags.joined(separator: ", "))) {
                    popover = .tags
                }
                .popover(isPresented: presented(.tags)) { organization }
                Spacer()
                Button { expandedNotes.toggle() } label: { Image(systemName: "textformat") }
                    .accessibilityLabel("Formatting").help("Formatting")
                Button { popover = .attachments } label: {
                    Image(systemName: draft.attachments?.isEmpty == false ? "paperclip.circle.fill" : "paperclip")
                }
                .accessibilityLabel("Attachments").help("Attachments")
                .popover(isPresented: presented(.attachments)) {
                    PlannerAttachmentEditor(attachments: Binding(
                        get: { draft.attachments ?? [] }, set: { draft.attachments = $0 }
                    )).padding().frame(width: 300)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
                    option("calendar", title: draft.day.map { Text($0, format: .dateTime.year().month().day()) } ?? Text("No date")) {
                        popover = .date
                    }
                    .popover(isPresented: presented(.date)) { dateControls }
                    if draft.day != nil || !timeText.isEmpty {
                        TextField("Start time", text: $timeText, prompt: Text("HH:mm"))
                            .accessibilityIdentifier("Start time").textFieldStyle(.plain)
                            .frame(width: 62).monospacedDigit()
                    }
                }
                option("bell", title: draft.reminderOffsetMinutes.map { Text("\($0) min before") } ?? Text("No reminder")) {
                    popover = .alert
                }
                .popover(isPresented: presented(.alert)) {
                    if timeText.isEmpty {
                        Button("Set start time") {
                            draft.day = draft.day ?? Calendar.current.startOfDay(for: .now)
                            timeText = Self.formatTime(.now)
                            popover = nil
                        }.padding()
                    } else {
                        TaskAlertPicker(item: $draft).padding().frame(minWidth: 230)
                    }
                }
                option("repeat", title: draft.recurrence.map { Text($0.frequency.rawValue.capitalized) } ?? Text("No repeat")) {
                    popover = .recurrence
                }
                .popover(isPresented: presented(.recurrence)) {
                    VStack { RecurrenceFields(item: $draft, scope: $repeatScope) }.padding().frame(width: 280)
                }
                HStack(spacing: 5) {
                    option("clock", title: Text("Duration")) { popover = .duration }
                        .popover(isPresented: presented(.duration)) {
                            HStack {
                                Button("Auto") { durationText = ""; popover = nil }
                                ForEach([15, 30, 60], id: \.self) { value in
                                    Button("\(value) min") { durationText = String(value); popover = nil }
                                }
                            }.padding()
                        }
                    TextField("Duration", text: $durationText, prompt: Text("Auto"))
                        .accessibilityIdentifier("Duration").textFieldStyle(.plain)
                        .monospacedDigit().frame(width: 45)
                }
            }
            .font(.system(size: 12))
            if let validationMessage { Text(validationMessage).foregroundStyle(.red).font(.callout) }
            HStack(spacing: 12) {
                if openingItem?.id == draft.id { actions }
                Spacer(minLength: 4)
                Button { draft.locked.toggle() } label: {
                    Image(systemName: draft.locked ? "lock.fill" : "lock.open")
                }
                .disabled(timeText.isEmpty).accessibilityLabel("Lock time")
                .accessibilityValue(draft.locked ? "On" : "Off").help("Lock time")
                Button("Save") { save(draft) }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("Save")
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.frame(minHeight: 25)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16).padding(.vertical, 9)
        .onAppear { titleFocused = true }
    }

    private enum EditorPopover { case organization, tags, date, alert, recurrence, attachments, duration }

    private func presented(_ panel: EditorPopover) -> Binding<Bool> {
        Binding(get: { popover == panel }, set: { show in
            if show { popover = panel } else if popover == panel { popover = nil }
        })
    }

    private var organization: some View {
        VStack(alignment: .leading, spacing: 8) {
            TaskOrganizationPicker(item: $draft, store: store)
        }.padding().frame(width: 290)
    }

    private var dateControls: some View {
        VStack(alignment: .leading) {
            DatePicker("Date", selection: Binding(get: { draft.day ?? Date() }, set: { draft.day = $0 }),
                       displayedComponents: .date).datePickerStyle(.graphical)
            HStack {
                Button("No date") { draft.day = nil; draft.locked = false; timeText = ""; popover = nil }
                Spacer()
                Button("Today") { draft.day = Calendar.current.startOfDay(for: Date()); popover = nil }
            }
        }.padding()
    }

    private func option(_ symbol: String, title: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).frame(width: 16).foregroundStyle(.secondary)
                title
                Image(systemName: "chevron.down").font(.system(size: 8)).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 19)
            .contentShape(Rectangle())
        }
    }

    private func pill(_ symbol: String, title: Text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) { Image(systemName: symbol); title.lineLimit(1) }
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
    }

    private func toggleCompletion() {
        var item = draft
        item.status = item.status == .active ? .completed : .active
        if openingItem?.id == item.id { save(item, scope: .occurrence) } else { draft = item }
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    private func switchToEvent(_ action: (PlannerItem) -> Void) {
        guard extractedTitles.isEmpty else {
            validationMessage = "Save the extracted tasks before creating an event."
            return
        }
        if let item = scheduledDraft(draft) { action(item) }
    }

    @ViewBuilder private var actions: some View {
        if draft.deleted {
            Button("Restore") { var item = draft; item.deleted = false; save(item) }
        } else {
            if draft.status == .active {
                Button("Cancel task") { var item = draft; item.status = .canceled; save(item, scope: .occurrence) }
            }
            if draft.recurrence != nil && draft.status == .active {
                Button("Skip") { var item = draft; item.status = .canceled; save(item, scope: .occurrence) }
            }
            Button("Duplicate") {
                draft.id = UUID()
                draft.seriesID = nil
                draft.occurrenceIndex = nil
                draft.revisionDefaults = nil
                draft.recurrence = nil
                repeatScope = .occurrence
                draft.status = .active
                draft.order = Int.max
                titleFocused = true
            }
            Button("Delete", role: .destructive) { var item = draft; item.deleted = true; save(item) }
        }
    }

    private static func formatTime(_ date: Date) -> String {
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", time.hour ?? 0, time.minute ?? 0)
    }

    private func scheduledDraft(_ input: PlannerItem) -> PlannerItem? {
        var item = input
        let duration = durationText.trimmingCharacters(in: .whitespacesAndNewlines)
        if duration.isEmpty {
            item.duration = nil
        } else {
            guard let minutes = Int(duration), (1...1440).contains(minutes) else {
                validationMessage = "Enter a duration from 1 to 1440 minutes."
                return nil
            }
            item.duration = minutes
            item.scheduledDuration = nil
        }
        if timeText.isEmpty {
            item.start = nil
            item.scheduledDuration = nil
            item.reminderOffsetMinutes = nil
            item.locked = false
        } else {
            let parts = timeText.split(separator: ":", omittingEmptySubsequences: false)
            let calendar = Calendar.current
            let day = calendar.startOfDay(for: item.day ?? Date())
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0..<24).contains(hour), (0..<60).contains(minute),
                  let time = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  calendar.isDate(time, inSameDayAs: day), Self.formatTime(time) == String(format: "%02d:%02d", hour, minute)
            else {
                validationMessage = "Enter a valid start time in HH:mm format."
                return nil
            }
            item.start = time
            item.day = day
        }
        return item
    }

    private func save(_ input: PlannerItem, scope: RecurrenceScope? = nil) {
        guard var item = scheduledDraft(input) else { return }
        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !item.title.isEmpty else {
            validationMessage = "Enter a title."
            return
        }
        let current = store.items.first { $0.id == item.id }
        if let openingItem, openingItem.id == item.id {
            do { item = try PlannerItemEdit.reconcile(item, opening: openingItem, current: current) }
            catch {
                validationMessage = error.localizedDescription
                return
            }
        }
        let original = current ?? item
        var changes = PlannerRepetition.edit(item, original: original, in: store.items, scope: scope ?? repeatScope)
        for title in extractedTitles {
            var child = PlannerItem(title: title)
            child.day = item.day
            child.tags = item.tags
            child.listID = item.listID
            changes.append(child)
        }
        if store.save(changes) { close() } else { validationMessage = store.errorMessage }
    }
}
