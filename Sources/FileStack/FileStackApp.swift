import SwiftUI
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = StashStore()
    let settings = AppSettings()
    private var statusBar: StatusBarController?
    private var notch: NotchController?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(store: store, settings: settings)
        statusBar?.show()
        cancellable = settings.$mode
            .sink { [weak self] mode in self?.applyMode(mode) }
        applyMode(settings.mode)
    }

    private func applyMode(_ mode: DisplayMode) {
        let effective: DisplayMode = (mode == .notch && AppSettings.notchAvailable) ? .notch : .menuBar
        if effective == .notch {
            if notch == nil { notch = NotchController(store: store) }
            notch?.show()
        } else {
            notch?.hide()
        }
    }
}

@main
enum EntryPoint {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--selftest") {
            SelfTest.run()
            return
        }
        FileStackApp.main()
    }
}

struct FileStackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.store, settings: appDelegate.settings)
        }
    }
}

struct PopoverContent: View {
    @ObservedObject var store: StashStore
    @ObservedObject var settings: AppSettings
    let onHover: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if settings.mode == .menuBar {
                StashPanelView(store: store)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "menubar.dock.rectangle").font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("Ablage läuft in der Notch").font(.callout).foregroundStyle(.secondary)
                }
                .frame(width: 300, height: 140)
            }

            Divider()

            HStack(spacing: 14) {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
                Spacer()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Beenden", systemImage: "power")
                }
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(height: 40) // fixed: keeps the total panel height budget exact
        }
        .frame(width: 320, height: 420)
        .onHover { onHover($0) }
    }
}
