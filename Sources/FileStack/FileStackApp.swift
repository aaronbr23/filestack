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
