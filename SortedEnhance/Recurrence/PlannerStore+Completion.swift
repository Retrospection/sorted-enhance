import Foundation

extension PlannerStore {
    @discardableResult
    func toggleOccurrenceCompletion(id: UUID) -> Bool {
        guard let current = items.first(where: { $0.id == id && !$0.deleted }) else { return false }
        var edited = current
        edited.status = current.status == .active ? .completed : .active
        return save(PlannerRepetition.edit(edited, original: current, in: items, scope: .occurrence))
    }
}
