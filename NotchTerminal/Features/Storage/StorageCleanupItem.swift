import Foundation

struct StorageCleanupItem: Identifiable, Hashable {
    let category: StorageCleanupCategory
    let url: URL
    let sizeInBytes: Int64
    let modifiedAt: Date?

    var id: String { url.path }
    var displayName: String { url.lastPathComponent }
    var path: String { url.path }
}
