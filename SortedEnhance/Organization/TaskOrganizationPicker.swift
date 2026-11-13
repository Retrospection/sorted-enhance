import SwiftUI

struct TaskOrganizationPicker: View {
    @Binding var item: PlannerItem
    @ObservedObject var store: PlannerStore
    @State private var newTag = ""

    private var availableTags: [String] {
        Set(store.items.filter { !$0.deleted }.flatMap(\.tags))
            .subtracting(item.tags)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        Picker("List", selection: $item.listID) {
            Text("No List").tag(UUID?.none)
            ForEach(store.lists.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { list in
                Text(list.name).tag(Optional(list.id))
            }
        }
        LabeledContent("Tags") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(item.tags, id: \.self) { tag in
                    HStack {
                        Text(tag)
                        Button {
                            item.tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove " + tag)
                    }
                }
                HStack {
                    TextField("New tag", text: $newTag)
                        .onSubmit(addTag)
                    Button("Add Tag", action: addTag)
                        .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if !availableTags.isEmpty {
                        Menu("Existing Tags") {
                            ForEach(availableTags, id: \.self) { tag in
                                Button(tag) { item.tags.append(tag) }
                            }
                        }
                        .fixedSize()
                    }
                }
            }
        }
    }

    private func addTag() {
        let text = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let match: (String) -> Bool = { $0.caseInsensitiveCompare(text) == .orderedSame }
        if !item.tags.contains(where: match) {
            item.tags.append(availableTags.first(where: match) ?? text)
        }
        newTag = ""
    }
}
