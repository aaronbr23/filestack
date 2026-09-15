import SwiftUI

struct StashListView: View {
    @ObservedObject var store: StashStore

    var body: some View {
        if store.items.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(.tertiary)
                Text("Ablage leer").font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.items) { item in
                        StashRow(item: item, store: store)
                            .frame(height: 40)
                    }
                }
            }
        }
    }
}

/// Wraps DragSourceView (FilePromise.swift) — the whole row is one AppKit view so
/// drag start, hover highlight, and the right-click menu never compete with SwiftUI
/// gesture recognizers.
struct StashRow: NSViewRepresentable {
    let item: StashItem
    let store: StashStore

    func makeNSView(context: Context) -> DragSourceView {
        let view = DragSourceView()
        configure(view)
        return view
    }

    func updateNSView(_ view: DragSourceView, context: Context) {
        configure(view)
    }

    private func configure(_ view: DragSourceView) {
        view.item = item
        view.store = store
        view.onDelete = { Task { @MainActor in store.remove(item) } }
    }
}
