import SwiftUI
import UniformTypeIdentifiers

struct DropZonesView: View {
    @ObservedObject var store: StashStore
    @AppStorage("language") private var language: AppLanguage = .english

    var body: some View {
        HStack(spacing: 10) {
            DropZone(
                mode: .move, label: t("Move", "Verschieben", language),
                hint: t("Original is removed", "Original wird entfernt", language),
                systemImage: "arrow.right.doc.on.clipboard", tint: .orange, store: store
            )
            DropZone(
                mode: .copy, label: t("Copy", "Kopieren", language),
                hint: t("Original stays", "Original bleibt", language),
                systemImage: "doc.on.doc", tint: .accentColor, store: store
            )
        }
        .frame(height: 82)
    }
}

private struct DropZone: View {
    let mode: AddMode
    let label: String
    let hint: String
    let systemImage: String
    let tint: Color
    @ObservedObject var store: StashStore
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
            Text(label).font(.caption).fontWeight(.semibold)
            Text(hint).font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(targeted ? tint.opacity(0.18) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(targeted ? tint : Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: targeted ? 2 : 1, dash: targeted ? [] : [4, 3]))
        )
        .scaleEffect(targeted ? 1.03 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: targeted)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in try? store.add(url: url, mode: mode) }
                }
            }
            return true
        }
    }
}
