import AppKit
import SwiftUI
import Combine
import UniformTypeIdentifiers

/// The menu bar icon itself, drawn and hit-tested by hand: a stock NSStatusItem
/// button doesn't report file-drag hover, and SwiftUI's MenuBarExtra only opens on
/// click — neither lets "hover to open" (with or without dragging a file) work,
/// which is the whole point of this mode.
final class StatusIconView: NSView {
    var onActivate: (() -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    var isFull = false { didSet { needsDisplay = true } }

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with event: NSEvent) { onHoverChange?(false) }

    override func draw(_ dirtyRect: NSRect) {
        let name = isFull ? "tray.full.fill" : "tray"
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil),
              let symbol = base.withSymbolConfiguration(.init(pointSize: 15, weight: .medium)) else { return }
        let rect = NSRect(
            x: (bounds.width - symbol.size.width) / 2,
            y: (bounds.height - symbol.size.height) / 2,
            width: symbol.size.width, height: symbol.size.height
        )
        // isTemplate only auto-tints when AppKit draws the image itself (button/image
        // view); drawing it by hand here always renders the glyph black, invisible on
        // a dark menu bar. Composite labelColor over the glyph's alpha mask instead.
        symbol.draw(in: rect)
        NSColor.labelColor.set()
        rect.fill(using: .sourceAtop)
    }

    override func mouseDown(with event: NSEvent) { onActivate?() }

    // Fires only during an actual external file drag (Finder → icon); plain mouse
    // hover is covered by mouseEntered/mouseExited above.
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onHoverChange?(true)
        return []  // the real drop targets live inside the popover, not the icon
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHoverChange?(false)
    }
}

@MainActor
final class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 26)
    private let iconView = StatusIconView(frame: NSRect(x: 0, y: 0, width: 26, height: 22))
    private let panel: NSPanel
    private var itemsCancellable: AnyCancellable?
    private var outsideClickMonitor: Any?
    private let closeAction = DebouncedAction()
    private var pinnedOpen = false

    private let panelSize = NSSize(width: PanelMetrics.width, height: PanelMetrics.height)
    private let gapBelowMenuBar: CGFloat = 8

    init(store: StashStore) {
        if let button = statusItem.button {
            iconView.frame = button.bounds
            iconView.autoresizingMask = [.width, .height]
            button.addSubview(iconView)
        }

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true // gives the floating-card look instead of a popover glued to the icon

        let content = PopoverContent(store: store, onHover: { [weak self] in self?.noteHover($0) })
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        panel.contentView = NSHostingView(rootView: content)

        iconView.onActivate = { [weak self] in self?.toggleClick() }
        iconView.onHoverChange = { [weak self] in self?.noteHover($0) }

        itemsCancellable = store.$items
            .sink { [weak self] items in self?.iconView.isFull = !items.isEmpty }
    }

    func show() { statusItem.isVisible = true }
    func hide() { statusItem.isVisible = false }

    private func toggleClick() {
        if panel.isVisible {
            pinnedOpen = false
            closePopover()
        } else {
            pinnedOpen = true
            openPopover()
        }
    }

    /// Hovering the icon (with or without a dragged file) or the panel content
    /// itself opens/keeps it open; leaving both schedules a collapse, unless the
    /// user explicitly clicked it open.
    private func noteHover(_ hovering: Bool) {
        if hovering {
            closeAction.cancel()
            openPopover()
        } else if !pinnedOpen {
            closeAction.fire(after: 0.35) { [weak self] in self?.closePopover() }
        }
    }

    private func openPopover() {
        closeAction.cancel()
        guard !panel.isVisible, let button = statusItem.button, let buttonWindow = button.window else { return }

        let buttonFrameOnScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        var origin = NSPoint(
            x: buttonFrameOnScreen.midX - panelSize.width / 2,
            y: buttonFrameOnScreen.minY - gapBelowMenuBar - panelSize.height
        )
        if let screenFrame = buttonWindow.screen?.visibleFrame {
            origin.x = min(max(origin.x, screenFrame.minX + 4), screenFrame.maxX - panelSize.width - 4)
        }
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
        panel.orderFrontRegardless()

        // A drag started inside our own panel never fires this (global monitors
        // only see events in *other* apps' windows), so it can't self-close mid-drag.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.pinnedOpen = false
            self?.closePopover()
        }
    }

    private func closePopover() {
        panel.orderOut(nil)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }
}
