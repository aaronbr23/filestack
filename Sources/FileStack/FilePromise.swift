import AppKit
import SwiftUI

/// A whole stash row, drawn and hit-tested entirely in AppKit: an earlier version
/// only made the small file icon draggable and left the SwiftUI filename/size text
/// inert, which made "click anywhere on the row to drag it out" silently fail.
final class DragSourceView: NSView, NSDraggingSource {
    var item: StashItem? { didSet { updateContent() } }
    weak var store: StashStore?
    var onDelete: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var hovering = false { didSet { deleteButton.isHidden = !hovering; needsDisplay = true } }

    private let imageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let sizeLabel = NSTextField(labelWithString: "")
    private let deleteButton = NSButton(
        image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil) ?? NSImage(),
        target: nil, action: nil
    )

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        imageView.imageScaling = .scaleProportionallyUpOrDown

        nameLabel.font = .systemFont(ofSize: 12.5)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.usesSingleLineMode = true
        nameLabel.cell?.truncatesLastVisibleLine = true

        sizeLabel.font = .systemFont(ofSize: 10)
        sizeLabel.textColor = .secondaryLabelColor
        sizeLabel.lineBreakMode = .byTruncatingTail
        sizeLabel.usesSingleLineMode = true

        deleteButton.isBordered = false
        deleteButton.imageScaling = .scaleProportionallyUpOrDown
        deleteButton.contentTintColor = .secondaryLabelColor
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        deleteButton.isHidden = true

        for v in [imageView, nameLabel, sizeLabel, deleteButton] {
            addSubview(v)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateContent() {
        imageView.image = item?.icon
        nameLabel.stringValue = item?.name ?? ""
        sizeLabel.stringValue = item?.sizeString ?? ""
    }

    // Manual frame layout instead of Auto Layout constraints: deterministic and
    // immune to content-hugging/compression-resistance fights that previously left
    // long filenames rendered oddly instead of cleanly truncated.
    override func layout() {
        super.layout()
        let iconSize: CGFloat = 24
        imageView.frame = NSRect(x: 8, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)

        let deleteSize: CGFloat = 16
        deleteButton.frame = NSRect(
            x: bounds.width - 8 - deleteSize, y: (bounds.height - deleteSize) / 2,
            width: deleteSize, height: deleteSize
        )

        let textX = imageView.frame.maxX + 10
        let textWidth = max(0, deleteButton.frame.minX - 6 - textX)
        let nameHeight: CGFloat = 15
        let sizeHeight: CGFloat = 12
        let gap: CGFloat = 2
        let blockHeight = nameHeight + gap + sizeHeight
        let startY = (bounds.height - blockHeight) / 2

        sizeLabel.frame = NSRect(x: textX, y: startY, width: textWidth, height: sizeHeight)
        nameLabel.frame = NSRect(x: textX, y: startY + sizeHeight + gap, width: textWidth, height: nameHeight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func draw(_ dirtyRect: NSRect) {
        (hovering ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.08) : NSColor.clear).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
    }

    @objc private func deleteTapped() { onDelete?() }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    // Plain file-URL drag instead of NSFilePromiseProvider: promise-based drags only
    // land in apps that implement NSFilePromiseReceiver. Many Electron/Chromium apps
    // (e.g. Claude desktop) don't, so the promise is never fulfilled — the drop
    // silently does nothing and the file never leaves Filestack.
    override func mouseDown(with event: NSEvent) {
        guard let item else { return }
        let point = convert(event.locationInWindow, from: nil)
        if deleteButton.frame.contains(point) { return } // let the button's own target/action handle it

        let dragItem = NSDraggingItem(pasteboardWriter: item.url as NSURL)
        dragItem.setDraggingFrame(imageView.frame, contents: item.icon)
        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    // "Remove after drag out" must fire only for drags that actually leave Filestack:
    // the same panel also hosts the Move/Copy drop zones right above this list, so a
    // drag ending inside one of our own windows (own panel, not another app) doesn't count.
    //
    // The plain file-URL drag (see mouseDown above) gives no completion signal at all —
    // unlike a file promise, nothing calls back when the destination has actually read
    // the bytes. `endedAt` only means the OS-level drop was accepted; Electron apps read
    // the file asynchronously afterward (DOM drop event, then an IPC round-trip to read
    // it), so deleting immediately here raced Claude's own read and won, deleting the
    // file out from under it. ponytail: fixed delay, not a real completion signal —
    // switch to an NSFilePromiseProvider-based deletion callback if this proves flaky.
    private static let deletionGracePeriod: TimeInterval = 2

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard operation != [], let item, let store, UserDefaults.standard.bool(forKey: "removeAfterDragOut") else { return }
        let droppedInsideOwnApp = NSApp.windows.contains { $0.isVisible && $0.frame.contains(screenPoint) }
        guard !droppedInsideOwnApp else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.deletionGracePeriod) {
            store.remove(item)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard item != nil else { return nil }
        let language = AppLanguage.current
        let menu = NSMenu()
        let reveal = NSMenuItem(
            title: t("Show in Finder", "Im Finder zeigen", language), action: #selector(revealInFinder), keyEquivalent: ""
        )
        reveal.target = self
        menu.addItem(reveal)
        let remove = NSMenuItem(
            title: t("Remove", "Entfernen", language), action: #selector(deleteTapped), keyEquivalent: ""
        )
        remove.target = self
        menu.addItem(remove)
        return menu
    }

    @objc private func revealInFinder() {
        guard let item else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}
