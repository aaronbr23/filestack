import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class NotchController: ObservableObject {
    @Published fileprivate(set) var isExpanded = false

    let panel: NSPanel
    private var collapseWorkItem: DispatchWorkItem?
    private let collapsedSize = CGSize(width: 200, height: 32)
    private let expandedSize = CGSize(width: 320, height: 380)

    init(store: StashStore) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 200, height: 32)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .statusBar + 1
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        panel.contentView = NSHostingView(rootView: NotchRootView(store: store, controller: self))

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.reposition() }
        }

        reposition()
    }

    func show() { reposition(); panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }

    func requestExpand() {
        collapseWorkItem?.cancel()
        isExpanded = true
        reposition()
    }

    func requestCollapse(afterDelay: Bool) {
        collapseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.isExpanded = false
            self?.reposition()
        }
        collapseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (afterDelay ? 0.4 : 0), execute: work)
    }

    private func reposition() {
        guard let screen = NSScreen.main else { return }
        let size = isExpanded ? expandedSize : collapsedSize
        let screenFrame = screen.frame
        let target = NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width, height: size.height
        )
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        }
    }
}

private struct NotchRootView: View {
    @ObservedObject var store: StashStore
    @ObservedObject var controller: NotchController

    var body: some View {
        Group {
            if controller.isExpanded {
                StashPanelView(store: store)
                    .frame(width: 320, height: 380)
                    .background(.black)
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 16, bottomTrailingRadius: 16))
            } else {
                Color.black
                    .frame(width: 200, height: 32)
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 12, bottomTrailingRadius: 12))
            }
        }
        .onHover { hovering in
            if hovering { controller.requestExpand() } else { controller.requestCollapse(afterDelay: true) }
        }
        .onDrop(of: [.fileURL], isTargeted: Binding(
            get: { false },
            set: { targeted in if targeted { controller.requestExpand() } }
        )) { _ in false }
    }
}
