import SwiftUI

struct CalendarDrawerButton: View {
    @ObservedObject var store: PlannerStore
    var items: [PlannerItem]
    @State private var date = Date()
    @State private var isPresented = false

    var body: some View {
        Button("Move to Date", systemImage: "calendar") {
            date = items.first?.day ?? Date()
            isPresented = true
        }
        .disabled(items.isEmpty)
        .popover(isPresented: $isPresented) {
            VStack(alignment: .trailing) {
                DatePicker("Move to date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Button("Move") {
                    store.save(DayPlanner.move(items, to: date))
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}
