import SwiftUI

struct PlannerEditorOverlay<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .textBackgroundColor).opacity(0.8)
            ScrollView {
                content()
                    .frame(maxWidth: 780, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 7))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    .padding(.horizontal, 28)
                    .padding(.top, 48)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

struct PlannerEditorHeader: View {
    enum Kind { case task, event }
    var kind: Kind
    var creating: Bool
    var close: () -> Void
    var switchKind: (() -> Void)?

    var body: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "xmark").frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("Close")
            Spacer()
        }
        .overlay {
            if creating, let switchKind {
                HStack(spacing: 0) {
                    segment("New Task", selected: kind == .task, switchKind)
                    segment("New Event", selected: kind == .event, switchKind)
                }
                .padding(2)
                .background(.quaternary, in: Capsule())
            } else {
                Text(creating ? (kind == .task ? "New Task" : "New Event") : (kind == .task ? "Task" : "Event"))
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder private func segment(_ title: LocalizedStringKey, selected: Bool, _ change: @escaping () -> Void) -> some View {
        let label = Text(title)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 13)
            .padding(.vertical, 3)
        if selected {
            label.foregroundStyle(.white).background(Color.accentColor, in: Capsule())
                .accessibilityAddTraits(.isSelected)
        } else {
            Button(action: change) { label }.buttonStyle(.plain)
        }
    }
}
