import Foundation
import Combine
import AppKit

enum DisplayMode: String { case menuBar, notch }

@MainActor
final class AppSettings: ObservableObject {
    @Published var mode: DisplayMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "displayMode") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "displayMode") ?? DisplayMode.menuBar.rawValue
        mode = DisplayMode(rawValue: raw) ?? .menuBar
    }

    /// No hardware notch (external display, older MacBook) → notch mode is pointless, fall back.
    static var notchAvailable: Bool {
        (NSScreen.main?.safeAreaInsets.top ?? 0) > 0
    }
}
