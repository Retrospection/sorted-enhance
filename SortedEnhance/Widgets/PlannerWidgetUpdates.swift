import Combine
import OSLog
import WidgetKit

@MainActor
final class PlannerWidgetUpdates {
    private let subscription: AnyCancellable

    init(store: PlannerStore) {
        subscription = store.$snapshot.sink { library in
            guard store.libraryIsReadable, let file = WidgetSnapshot.fileURL else { return }
            do {
                if try WidgetSnapshot.export(library, to: file) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } catch {
                Logger(subsystem: "SortedEnhance", category: "Widgets").error("Could not update widget snapshot: \(error.localizedDescription)")
            }
        }
    }
}
