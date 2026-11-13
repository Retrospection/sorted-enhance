import SwiftUI

enum OrganizationSection: String {
    case lists = "Lists"
    case tags = "Tags"

    var title: String {
        switch self {
        case .lists: String(localized: "Lists")
        case .tags: String(localized: "Tags")
        }
    }
}

private struct CollectionCount {
    var total = 0
    var unscheduled = 0

    mutating func add(_ item: PlannerItem) {
        total += 1
        if item.day == nil && item.start == nil { unscheduled += 1 }
    }

    var summary: String {
        if total == 1 {
            String(localized: "\(total) task · \(unscheduled) unscheduled")
        } else {
            String(localized: "\(total) tasks · \(unscheduled) unscheduled")
        }
    }
}

enum CollectionFilter: Hashable {
    case folder(UUID), list(UUID), tag(String)
}

private enum CollectionEdit {
    case newTag, newFolder, newList(UUID?), folder(PlannerFolder), list(PlannerList)

    var initialName: String {
        switch self {
        case .newFolder, .newList, .newTag: ""
        case .folder(let folder): folder.name
        case .list(let list): list.name
        }
    }

    var title: String {
        switch self {
        case .newTag: "New Tag"
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
    let section: OrganizationSection
    let onSearch: () -> Void
    let newCollectionSignal: Int
    @State private var filter: CollectionFilter?
    @State private var selected = Set<UUID>()
    @State private var editing: CollectionEdit?
    @State private var name = ""
    @State private var mergeError: String?

    init(store: PlannerStore, section: OrganizationSection, onEdit: @escaping (PlannerItem) -> Void,
         onSearch: @escaping () -> Void, newCollectionSignal: Int, initialFilter: CollectionFilter? = nil) {
        self.section = section
        self.onSearch = onSearch
        self.newCollectionSignal = newCollectionSignal
        self.store = store
        self.onEdit = onEdit
        _filter = State(initialValue: initialFilter)
    }

    private var active: [PlannerItem] {
        store.items.filter { !$0.deleted && $0.status == .active }
    }

    private var visible: [PlannerItem] {
        let lists = store.lists
        return active.filter { item in
            switch filter {
            case nil: false
            case .folder(let id): lists.contains { $0.id == item.listID && $0.folderID == id }
            case .list(let id): item.listID == id
            case .tag(let tag): item.tags.contains { PlannerTag.key($0) == PlannerTag.key(tag) }
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
        VStack(alignment: .leading, spacing: 0) {
            header
            if filter == nil {
                overview
            } else {
                tasks
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: filter) { selected.removeAll() }
        .onChange(of: section) { filter = nil }
        .onChange(of: newCollectionSignal) {
            if filter != nil {
                newTask()
            } else {
                begin(section == .tags ? .newTag : .newList(nil))
            }
        }
        .sheet(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            if let editing {
                VStack(alignment: .leading, spacing: 16) {
                    Text(editing.title).font(.headline)
                    if case .newList(nil) = editing {
                        Button("Create a Folder Instead") { begin(.newFolder) }.buttonStyle(.link)
                    } else if case .newFolder = editing {
                        Button("Create a List Instead") { begin(.newList(nil)) }.buttonStyle(.link)
                    }
                    TextField("Name", text: $name)
                    HStack {
                        Spacer()
                        Button("Cancel") { self.editing = nil }.keyboardShortcut(.cancelAction)
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

    private var header: some View {
        HStack(spacing: 12) {
            if filter != nil {
                Button { filter = nil } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to " + section.title)
            }
            Image(systemName: section == .lists ? "list.bullet" : "tag.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(section == .lists ? Color.cyan : Color(red: 41 / 255, green: 183 / 255, blue: 52 / 255))
            Text(pageTitle).font(.system(size: 24, weight: .bold))
            Spacer()
            Button(action: onSearch) { Image(systemName: "magnifyingglass") }
                .font(.system(size: 17))
                .buttonStyle(.plain)
                .accessibilityLabel("Search")
        }
        .padding(.leading, 44)
        .padding(.trailing, 56)
        .padding(.top, 30)
        .padding(.bottom, 18)
    }

    private var pageTitle: String {
        switch filter {
        case .folder(let id): store.folders.first { $0.id == id }?.name ?? section.title
        case .list(let id): store.lists.first { $0.id == id }?.name ?? section.title
        case .tag(let tag): tag
        case nil: section.title
        }
    }

    private var overview: some View {
        let counts = active.reduce(into: [CollectionFilter: CollectionCount]()) { result, item in
            if let id = item.listID { result[.list(id), default: CollectionCount()].add(item) }
            for tag in Set(item.tags.map(PlannerTag.key)) { result[.tag(tag), default: CollectionCount()].add(item) }
        }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if section == .tags {
                    ForEach(store.tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending }, id: \.self) { tag in
                        collectionRow(tag, count: counts[.tag(PlannerTag.key(tag))] ?? CollectionCount()) { filter = .tag(tag) }
                    }
                } else {
                    ForEach(lists(in: nil)) { list in listRow(list, counts: counts) }
                    if !folders.isEmpty {
                        Canvas { context, size in
                            var line = Path()
                            line.move(to: CGPoint(x: 0, y: 0.5))
                            line.addLine(to: CGPoint(x: size.width, y: 0.5))
                            context.stroke(line, with: .color(.secondary.opacity(0.4)),
                                           style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                        .frame(height: 1).padding(.vertical, 14)
                        .accessibilityHidden(true)
                    }
                    ForEach(folders) { folder in
                        Button { filter = .folder(folder.id) } label: {
                            Label(folder.name, systemImage: "folder")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("New List…") { begin(.newList(folder.id)) }
                            Button("Rename Folder…") { begin(.folder(folder)) }
                            Button("Move Up") { reorder(folder, by: -1) }.disabled(folders.first?.id == folder.id)
                            Button("Move Down") { reorder(folder, by: 1) }.disabled(folders.last?.id == folder.id)
                        }
                        ForEach(lists(in: folder.id)) { list in listRow(list, counts: counts) }
                    }
                }
            }
            .padding(.horizontal, 44)
            .padding(.bottom, 72)
        }
    }

    private func collectionRow(_ title: String, count: CollectionCount, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 22) {
                Circle().strokeBorder(.secondary.opacity(0.65), lineWidth: 1.5).frame(width: 9, height: 9)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(count.summary).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tasks: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selection.isEmpty {
                HStack {
                    CalendarDrawerButton(store: store, items: selection)
                    Button("Merge", action: merge).disabled(selection.count < 2)
                }
                .padding(.horizontal, 44)
            }
            List(visible, selection: $selected) { item in
                PlannerTaskRow(
                    item: item, listName: store.lists.first { $0.id == item.listID }?.name,
                    completionIdentifier: "CollectionComplete-" + item.id.uuidString,
                    onToggleCompletion: { PlannerFeedback.toggleCompletion(id: item.id, in: store) },
                    onOpen: { onEdit(item) }
                )
                .padding(.vertical, 5)
                .listRowSeparator(.hidden)
                .tag(item.id)
            }
            .listStyle(.plain)
            .contextMenu(forSelectionType: UUID.self) { ids in
                if ids.count == 1, let item = visible.first(where: { ids.contains($0.id) }) {
                    Button("Edit Task") { onEdit(item) }
                }
            }
            .onKeyPress(.return) {
                guard selected.count == 1, let item = selection.first else { return .ignored }
                onEdit(item)
                return .handled
            }
            .padding(.horizontal, 32)
        }
    }

    private func listRow(_ list: PlannerList, counts: [CollectionFilter: CollectionCount]) -> some View {
        collectionRow(list.name, count: counts[.list(list.id)] ?? CollectionCount()) { filter = .list(list.id) }
            .contextMenu {
                Button("Rename List…") { begin(.list(list)) }
                Button("Move Up") { reorder(list, by: -1) }.disabled(lists(in: list.folderID).first?.id == list.id)
                Button("Move Down") { reorder(list, by: 1) }.disabled(lists(in: list.folderID).last?.id == list.id)
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
        switch edit {
        case .newTag:
            if store.addTag(text) { editing = nil }
            return
        case .newFolder:
            let folder = PlannerFolder(name: text, order: (folders.map(\.order).max() ?? -1) + 1)
            folders.append(folder)
        case .newList(let folderID):
            let lastOrder = self.lists(in: folderID).last?.order ?? -1
            let list = PlannerList(name: text, folderID: folderID, order: lastOrder + 1)
            lists.append(list)
        case .folder(let folder):
            guard let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
            folders[index].name = text
        case .list(let list):
            guard let index = lists.firstIndex(where: { $0.id == list.id }) else { return }
            lists[index].name = text
        }
        if store.replaceOrganization(folders: folders, lists: lists) {
            editing = nil
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
