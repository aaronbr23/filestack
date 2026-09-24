import AppKit
import Foundation

/// Run with `swift run FileStack --selftest` — exercises the one non-trivial logic
/// path (copy/move/remove/reload) without needing XCTest/swift-testing, which don't
/// build against the pinned SDK on this Xcode-less toolchain (see build.sh).
@MainActor
enum SelfTest {
    static func run() {
        try! testCopyKeepsOriginal()
        try! testMoveRemovesOriginal()
        try! testRemoveDeletesEntry()
        try! testReloadRebuildsFromDisk()
        try! testDragExposesPlainFileURL()
        print("selftest ok")
    }

    private static func makeTempSource() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("test.txt")
        try "hello".write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private static func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private static func testCopyKeepsOriginal() throws {
        let store = StashStore(root: tempRoot())
        let src = try makeTempSource()
        let item = try store.add(url: src, mode: .copy)
        precondition(FileManager.default.fileExists(atPath: src.path), "copy must keep original")
        precondition(FileManager.default.fileExists(atPath: item.url.path), "copy must create stash file")
        precondition(store.items.count == 1)
    }

    private static func testMoveRemovesOriginal() throws {
        let store = StashStore(root: tempRoot())
        let src = try makeTempSource()
        let item = try store.add(url: src, mode: .move)
        precondition(!FileManager.default.fileExists(atPath: src.path), "move must remove original")
        precondition(FileManager.default.fileExists(atPath: item.url.path), "move must create stash file")
    }

    private static func testRemoveDeletesEntry() throws {
        let store = StashStore(root: tempRoot())
        let item = try store.add(url: try makeTempSource(), mode: .copy)
        store.remove(item)
        precondition(!FileManager.default.fileExists(atPath: item.url.path), "remove must delete stash file")
        precondition(store.items.isEmpty)
    }

    private static func testReloadRebuildsFromDisk() throws {
        let root = tempRoot()
        let store = StashStore(root: root)
        _ = try store.add(url: try makeTempSource(), mode: .copy)
        let reopened = StashStore(root: root)
        precondition(reopened.items.count == 1, "reload must rebuild the list from disk")
    }

    /// Regression guard for the drag-out bug: apps without NSFilePromiseReceiver
    /// (most Electron/Chromium apps, e.g. Claude desktop) never receive a promised
    /// file, so the drag must publish a plain "public.file-url" pasteboard type.
    private static func testDragExposesPlainFileURL() throws {
        let url = try makeTempSource()
        let types = (url as NSURL).writableTypes(for: NSPasteboard(name: .drag))
        precondition(
            types.contains(NSPasteboard.PasteboardType("public.file-url")),
            "drag item must expose a plain file URL, not only a file promise"
        )
    }
}
