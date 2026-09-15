import Foundation
import Combine

enum AddMode { case move, copy }

enum StashError: Error { case sourceMissing, alreadyExists }

@MainActor
final class StashStore: ObservableObject {
    @Published private(set) var items: [StashItem] = []

    let root: URL

    init(root: URL = StashStore.defaultRoot) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        reload()
    }

    nonisolated static var defaultRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FileStack/Stash", isDirectory: true)
    }

    /// Directory listing *is* the database — no separate index file.
    func reload() {
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
        ) else {
            items = []
            return
        }
        items = folders.compactMap { folder -> StashItem? in
            guard let inner = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
                  let file = inner.first else { return nil }
            let created = (try? folder.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return StashItem(id: folder.lastPathComponent, url: file, addedAt: created)
        }.sorted { $0.addedAt < $1.addedAt }
    }

    @discardableResult
    func add(url: URL, mode: AddMode) throws -> StashItem {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { throw StashError.sourceMissing }

        let folder = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(url.lastPathComponent)

        try fm.copyItem(at: url, to: dest)
        if mode == .move {
            // copy-then-delete: a failed delete never loses the file, unlike moveItem across volumes.
            try? fm.removeItem(at: url)
        }

        let item = StashItem(id: folder.lastPathComponent, url: dest, addedAt: Date())
        items.append(item)
        return item
    }

    func remove(_ item: StashItem) {
        let folder = root.appendingPathComponent(item.id, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        items.removeAll { $0.id == item.id }
    }

    func removeAll() {
        for item in items { remove(item) }
    }
}
