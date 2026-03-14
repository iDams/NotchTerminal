import Foundation

struct StorageCleanupCategoryResult: Identifiable, Hashable {
    let category: StorageCleanupCategory
    let items: [StorageCleanupItem]

    var id: StorageCleanupCategory { category }
    var totalSizeInBytes: Int64 { items.reduce(0) { $0 + $1.sizeInBytes } }

    func removingItems(withIDs ids: Set<String>) -> StorageCleanupCategoryResult {
        StorageCleanupCategoryResult(
            category: category,
            items: items.filter { !ids.contains($0.id) }
        )
    }
}

struct StorageCleanupScanResult: Hashable {
    let categoryResults: [StorageCleanupCategoryResult]
    let scannedAt: Date

    var totalSizeInBytes: Int64 {
        categoryResults.reduce(0) { $0 + $1.totalSizeInBytes }
    }

    func result(for category: StorageCleanupCategory) -> StorageCleanupCategoryResult? {
        categoryResults.first(where: { $0.category == category })
    }

    var nonEmptyCategoryResults: [StorageCleanupCategoryResult] {
        categoryResults.filter { !$0.items.isEmpty && $0.totalSizeInBytes > 0 }
    }

    func removingItems(withIDs ids: Set<String>) -> StorageCleanupScanResult {
        StorageCleanupScanResult(
            categoryResults: categoryResults.map { $0.removingItems(withIDs: ids) },
            scannedAt: scannedAt
        )
    }
}
