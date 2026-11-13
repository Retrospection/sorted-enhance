import EventKit

enum EventAlerts {
    static func editable(in event: EKEvent) -> [EKAlarm] {
        (event.alarms ?? []).filter { alarm in
            alarm.absoluteDate == nil && alarm.proximity == .none && alarm.type == .display &&
                alarm.soundName == nil && alarm.emailAddress == nil && alarm.relativeOffset <= 0 && Int(exactly: -alarm.relativeOffset / 60) != nil
        }
    }

    static func replace(in event: EKEvent, minutesBefore: Int?) {
        for alarm in editable(in: event) { event.removeAlarm(alarm) }
        if let minutesBefore { event.addAlarm(EKAlarm(relativeOffset: -TimeInterval(minutesBefore) * 60)) }
    }
}
