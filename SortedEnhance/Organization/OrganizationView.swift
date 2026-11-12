import SwiftUI

private enum CollectionFilter: Hashable {
    case all, folder(UUID), list(UUID), tag(String)
}

private enum CollectionEdit {
    case newFolder, newList(UUID?), folder(PlannerFolder), list(PlannerList)

    var initialName: String {
        switch self {
        case .newFolder, .newList: ""
        case .folder(let folder): folder.name
        case .list(let list): list.name
        }
    }

    var title: String {
        switch self {
        case .newFolder: "New Folder"
        case .newList: "New List"
        case .folder: "Rename Folder"
        case .list: "Rename List"
        }
    }
}

struct OrganizationView: View {
    @ObservedObject var store: PlannerStore
    let onEdit: (PlannerItem) -> Void
    @State private var filter: CollectionFilter? = .all
    @State private var selected = Set<UUID>()
    @State private var editing: CollectionEdit?
    @State private var name = ""
    @State private var mergeError: String?

    init(store: PlannerStore, onEdit: @escaping (PlannerItem) -> Void, initialListID: UUID? = nil) {
        self.store = store
        self.onEdit = onEdit
        _filter = State(initialValue: initialListID.map(CollectionFilter.list) ?? .all)
    }

    private var active: [PlannerItem] {
        store.items.filter { !$0.deleted && $0.status == .active }
    }

    private var visible: [PlannerItem] {
        let lists = store.lists
        return active.filter { item in
            switch filter {
            case .all, nil: true
            case .folder(let id): lists.contains { $0.id == item.listID && $0.folderID == id }
            case .list(let id): item.listID == id
            case .tag(let tag): item.tags.contains(tag)
            }
        }.sorted { ($0.order, $0.id.uuidString) < ($1.order, $1.id.uuidString) }
    }

    private var selection: [PlannerItem] {
        visible.filter { selected.contains($0.id) }
    }

    private var folders: [PlannerFolder] { store.folders.sorted { $0.order < $1.order } }

    private func lists(in folder: UUID?) -> [PlannerList] {
        store.lists.filter { $0.folderID == folder }.sorted { $0.order < $1.order }
    }

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $filter) {
                    Label("All Tasks", systemImage: "tray.full").tag(CollectionFilter.all)
                    Section("Lists") {
                        ForEach(lists(in: nil)) { listRow($0) }
                    }
                    ForEach(folders) { folder in
                        Section {
                            Label(folder.name, systemImage: "folder")
                                .tag(CollectionFilter.folder(folder.id))
                                .contextMenu {
                                    Button("New List…") { begin(.newList(folder.id)) }
                                    Button("Rename Folder…") { begin(.folder(folder)) }
                                    Button("Move Up") { reorder(folder, by: -1) }
                                        .disabled(folders.first?.id == folder.id)
                                    Button("Move Down") { reorder(folder, by: 1) }
                                        .disabled(folders.last?.id == folder.id)
                                }
                            ForEach(lists(in: folder.id)) { list in
                                listRow(list).padding(.leading, 12)
                            }
                        }
                    }
                    Section("Tags") {
                        ForEach(Set(active.flatMap(\.tags)).sorted(), id: \.self) { tag in
                            Label(tag, systemImage: "tag").tag(CollectionFilter.tag(tag))
                        }
                    }
                }
                Menu("Add Collection") {
                    Button("New Folder…") { begin(.newFolder) }
                    Button("New List…") { begin(.newList(currentFolder)) }
                }
                .padding(8)
            }
            .frame(minWidth: 160, idealWidth: 190, maxWidth: 280)
            VStack(alignment: .leading) {
                HStack {
                    Button("New Task", systemImage: "plus", action: newTask)
                    CalendarDrawerButton(store: store, items: selection)
                        .disabled(selection.isEmpty)
                    Button("Merge", action: merge).disabled(selection.count < 2)
                }
                .padding(.horizontal)
                List(visible, selection: $selected) { item in
                    Text(item.title).tag(item.id)
                }
                .contextMenu(forSelectionType: UUID.self) { ids in
                    if ids.count == 1, let item = visible.first(where: { ids.contains($0.id) }) {
                        Button("Edit Task") { onEdit(item) }
                    }
                } primaryAction: { ids in
                    if ids.count == 1, let item = visible.first(where: { ids.contains($0.id) }) {
                        onEdit(item)
                    }
                }
            }
            .frame(minWidth: 300)
        }
        .onChange(of: filter) { selected.removeAll() }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            if let editing {
                VStack(alignment: .leading, spacing: 16) {
                    Text(editing.title).font(.headline)
                    TextField("Name", text: $name)
                    HStack {
                        Spacer()
                        Button("Cancel") { self.editing = nil }
                            .keyboardShortcut(.cancelAction)
                        Button("Save") { save(editing) }
                            .keyboardShortcut(.defaultAction)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .frame(width: 320)
            }
        }
        .alert("Could not merge tasks", isPresented: Binding(
            get: { mergeError != nil }, set: { if !$0 { mergeError = nil } }
        )) {
            Button("OK") { mergeError = nil }
        } message: { Text(mergeError ?? "") }
    }

    private var currentFolder: UUID? {
        switch filter {
        case .folder(let id): id
        case .list(let id): store.lists.first { $0.id == id }?.folderID
        default: nil
        }
    }

    private func listRow(_ list: PlannerList) -> some View {
        Label(list.name, systemImage: "list.bullet")
            .tag(CollectionFilter.list(list.id))
            .contextMenu {
                Button("Rename List…") { begin(.list(list)) }
                Button("Move Up") { reorder(list, by: -1) }
                    .disabled(lists(in: list.folderID).first?.id == list.id)
                Button("Move Down") { reorder(list, by: 1) }
                    .disabled(lists(in: list.folderID).last?.id == list.id)
                Menu("Move to Folder") {
                    Button("No Folder") { move(list, to: nil) }.disabled(list.folderID == nil)
                    ForEach(folders) { folder in
                        Button(folder.name) { move(list, to: folder.id) }.disabled(list.folderID == folder.id)
                    }
                }
            }
    }

    private func newTask() {
        var item = PlannerItem(title: "")
        switch filter {
        case .list(let id): item.listID = id
        case .tag(let tag): item.tags = [tag]
        default: break
        }
        onEdit(item)
    }

    private func merge() {
        do {
            let changes = try TaskMerge.changes(for: selection)
            if let survivor = changes.first, store.save(changes) { selected = [survivor.id] }
        } catch {
            mergeError = error.localizedDescription
        }
    }

    private func begin(_ edit: CollectionEdit) {
        name = edit.initialName
        editing = edit
    }

    private func save(_ edit: CollectionEdit) {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var folders = store.folders
        var lists = store.lists
        let saved: CollectionFilter
        switch edit {
        case .newFolder:
            let folder = PlannerFolder(name: text, order: (folders.map(\.order).max() ?? -1) + 1)
            folders.append(folder)
            saved = .folder(folder.id)
        case .newList(let folderID):
            let lastOrder = self.lists(in: folderID).last?.order ?? -1
            let list = PlannerList(name: text, folderID: folderID, order: lastOrder + 1)
            lists.append(list)
            saved = .list(list.id)
        case .folder(let folder):
            guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
            folders[index].name = text
            saved = .folder(folder.id)
        case .list(let list):
            guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }
            lists[index].name = text
            saved = .list(list.id)
        }
        if store.replaceOrganization(folders: folders, lists: lists) {
            editing = nil
            filter = saved
        }
    }

    private func reorder(_ folder: PlannerFolder, by offset: Int) {
        var sorted = folders
        guard let index = sorted.firstIndex(where: { $0.id == folder.id }), sorted.indices.contains(index + offset) else { return }
        sorted.swapAt(index, index + offset)
        for index in sorted.indices { sorted[index].order = index }
        _ = store.replaceOrganization(folders: sorted, lists: store.lists)
    }

    private func reorder(_ list: PlannerList, by offset: Int) {
        var sorted = lists(in: list.folderID)
        guard let index = sorted.firstIndex(where: { $0.id == list.id }), sorted.indices.contains(index + offset) else { return }
        sorted.swapAt(index, index + offset)
        for index in sorted.indices { sorted[index].order = index }
        let others = store.lists.filter { $0.folderID != list.folderID }
        _ = store.replaceOrganization(folders: store.folders, lists: others + sorted)
    }

    private func move(_ list: PlannerList, to folder: UUID?) {
        var lists = store.lists
        guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }
        lists[index].folderID = folder
        lists[index].order = (self.lists(in: folder).last?.order ?? -1) + 1
        _ = store.replaceOrganization(folders: store.folders, lists: lists)
    }
}
