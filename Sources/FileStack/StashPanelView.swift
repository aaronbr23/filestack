import SwiftUI

struct StashPanelView: View {
    @ObservedObject var store: StashStore

    var body: some View {
        VStack(spacing: 12) {
            header
            DropZonesView(store: store)
            StashListView(store: store)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Label("FileStack", systemImage: "tray.full")
                .font(.headline)
            Spacer()
            Text("\(store.items.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(.quaternary))
        }
        .frame(height: 22) // fixed: keeps the total panel height budget exact
    }
}
