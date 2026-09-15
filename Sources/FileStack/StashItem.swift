import Foundation
import AppKit

struct StashItem: Identifiable, Equatable {
    let id: String          // UUID folder name
    let url: URL             // file inside the UUID folder
    let addedAt: Date

    var name: String { url.lastPathComponent }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    var sizeString: String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? Int ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
