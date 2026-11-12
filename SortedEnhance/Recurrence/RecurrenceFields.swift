import SwiftUI

struct RecurrenceFields: View {
    @Binding var item: PlannerItem
    @Binding var scope: RecurrenceScope

    var body: some View {
        if item.seriesID != nil {
            Picker("Apply changes to", selection: $scope) {
                Text("This occurrence").tag(RecurrenceScope.occurrence)
                Text("This and future occurrences").tag(RecurrenceScope.future)
            }
        }
        Picker("Repeat", selection: Binding(
            get: { item.recurrence?.frequency },
            set: { frequency in
                if let frequency {
                    var rule = item.recurrence ?? PlannerRecurrence(frequency: frequency, anchor: item.start ?? item.day ?? .now)
                    rule.frequency = frequency
                    item.recurrence = rule
                } else {
                    item.recurrence = nil
                }
                if item.seriesID != nil { scope = .future }
            }
        )) {
            Text("Never").tag(nil as PlannerRecurrence.Frequency?)
            ForEach(PlannerRecurrence.Frequency.allCases, id: \.self) { frequency in
                Text(frequency.rawValue.capitalized).tag(Optional(frequency))
            }
        }
        if let rule = item.recurrence {
            Stepper(value: Binding(
                get: { rule.interval },
                set: { interval in
                    item.recurrence?.interval = interval
                    if item.seriesID != nil { scope = .future }
                }
            ), in: 1...999) {
                Text("Repeat interval: \(rule.interval)")
            }
        }
    }
}
