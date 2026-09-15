import Foundation

/// Shared sizing for the floating panel — both StatusBarController (menu bar mode)
/// and NotchController (notch mode) host the same PopoverContent, and drifting
/// these out of sync is exactly what caused content to get clipped before.
enum PanelMetrics {
    static let width: CGFloat = 320
    static let menuBarHeight: CGFloat = 420
    static let notchExpandedHeight: CGFloat = 380
}
