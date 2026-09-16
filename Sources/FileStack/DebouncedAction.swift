import Foundation

/// "Run this, but if asked again before it fires, cancel and reschedule" — the
/// collapse-after-hover-exit behavior StatusBarController needs.
@MainActor
final class DebouncedAction {
    private var pending: DispatchWorkItem?

    func cancel() {
        pending?.cancel()
        pending = nil
    }

    func fire(after delay: TimeInterval, _ action: @escaping () -> Void) {
        cancel()
        let work = DispatchWorkItem(block: action)
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
