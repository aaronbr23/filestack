import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The content hosted inside both the menu-bar floating panel (StatusBarController)
/// and the notch panel (NotchController) — same view, two different windows.
struct PopoverContent: View {
    @ObservedObject var store: StashStore
    @ObservedObject var settings: AppSettings
    let onHover: (Bool) -> Void
    @AppStorage("language") private var language: AppLanguage = .english

    var body: some View {
        VStack(spacing: 0) {
            if settings.mode == .menuBar {
                StashPanelView(store: store)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "menubar.dock.rectangle").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text(t("Shelf is running in the Notch", "Ablage läuft in der Notch", language))
                        .font(.callout).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            footer
        }
        .frame(width: PanelMetrics.width, height: PanelMetrics.menuBarHeight)
        .onHover { onHover($0) }
        // .onHover alone never fires during a live external file drag (only for
        // plain mouse movement), so without this the panel's auto-close timer kept
        // running while the user was still dragging toward a drop zone, closing the
        // panel out from under them mid-drag.
        .onDrop(of: [.fileURL], isTargeted: Binding(
            get: { false },
            set: { targeted in if targeted { onHover(true) } }
        )) { _ in false }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button {
                openSettingsWindow()
            } label: {
                Label(t("Settings", "Einstellungen", language), systemImage: "gearshape")
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label(t("Quit", "Beenden", language), systemImage: "power")
            }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 40) // fixed: keeps the total panel height budget exact
    }

    /// This content is hosted directly in a plain NSPanel, not inside a SwiftUI
    /// Scene, so the normal `@Environment(\.openSettings)` action isn't populated
    /// here — it only exists for views that are part of a Scene's view hierarchy.
    /// `showSettingsWindow:` is the underlying AppKit action SwiftUI's Settings
    /// scene registers on the app; sending it directly works from anywhere.
    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
