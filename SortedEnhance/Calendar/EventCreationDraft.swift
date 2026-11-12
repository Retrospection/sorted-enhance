import EventKit
import Foundation

/// Event-only fields stay with the unsaved item while the task editor is open.
struct EventCreationDraft {
    var taskID: UUID
    var calendarID: String
    var repeatFrequency: EKRecurrenceFrequency?
    var allDay: Bool
    var lastDay: Date
    var calendarNotes: String

    static func fields(for task: PlannerItem?, previous: Self?, defaultCalendarID: String, start: Date) -> Self {
        if let previous, previous.taskID == task?.id { return previous }
        return Self(taskID: task?.id ?? UUID(), calendarID: defaultCalendarID, allDay: false,
                    lastDay: start, calendarNotes: "")
    }
}
