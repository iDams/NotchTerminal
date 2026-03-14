import Foundation

actor StorageCleanupScanner {
    private let fileManager = FileManager.default

    func scan(progress: @escaping @Sendable (StorageCleanupCategoryResult) async -> Void) async -> StorageCleanupScanResult {
        let categories = StorageCleanupCategory.allCases
        var results: [StorageCleanupCategoryResult] = []

        for category in categories {
            let result = StorageCleanupCategoryResult(category: category, items: items(for: category))
            results.append(result)
            await progress(result)
        }

        return StorageCleanupScanResult(categoryResults: results, scannedAt: Date())
    }

    private func items(for category: StorageCleanupCategory) -> [StorageCleanupItem] {
        switch category {
        case .nodeModules:
            return scanNodeModules()
        case .derivedData:
            return scanDirectChildren(
                of: fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
                category: category
            )
        case .pods:
            return scanNamedDirectories(named: "Pods", category: category)
        case .carthage:
            return scanNamedDirectories(named: "Carthage", category: category)
        case .caches:
            return scanDirectChildren(of: fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches"), category: category)
        case .logs:
            return scanDirectChildren(of: fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs"), category: category)
        case .trash:
            return scanDirectChildren(of: fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"), category: category)
        case .downloads:
            return scanOldDownloads()
        }
    }

    private func scanNamedDirectories(named targetName: String, category: StorageCleanupCategory) -> [StorageCleanupItem] {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let roots = [
            homeURL.appendingPathComponent("Documents"),
            homeURL.appendingPathComponent("Desktop"),
            homeURL.appendingPathComponent("Developer"),
            homeURL.appendingPathComponent("Sites"),
            homeURL.appendingPathComponent("Projects")
        ]

        var collected: [StorageCleanupItem] = []
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey, .isSymbolicLinkKey]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isDirectory == true,
                      values.isSymbolicLink != true else {
                    continue
                }

                if values.name == targetName {
                    let size = directorySize(at: url)
                    if size > 0 {
                        collected.append(
                            StorageCleanupItem(
                                category: category,
                                url: url,
                                sizeInBytes: size,
                                modifiedAt: modificationDate(for: url)
                            )
                        )
                    }
                    enumerator.skipDescendants()
                }
            }
        }

        return collected.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func scanOldDownloads() -> [StorageCleanupItem] {
        let downloadsURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        guard let entries = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast

        return entries.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt < cutoffDate else {
                return nil
            }

            let size = directorySize(at: url)
            guard size > 0 else { return nil }
            return StorageCleanupItem(category: .downloads, url: url, sizeInBytes: size, modifiedAt: modifiedAt)
        }
        .sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func scanNodeModules() -> [StorageCleanupItem] {
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let roots = [
            homeURL.appendingPathComponent("Documents"),
            homeURL.appendingPathComponent("Desktop"),
            homeURL.appendingPathComponent("Developer"),
            homeURL.appendingPathComponent("Sites"),
            homeURL.appendingPathComponent("Projects")
        ]

        var collected: [StorageCleanupItem] = []
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .nameKey, .isSymbolicLinkKey]

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isDirectory == true,
                      values.isSymbolicLink != true else {
                    continue
                }

                if values.name == "node_modules" {
                    let size = directorySize(at: url)
                    if size > 0 {
                        collected.append(
                            StorageCleanupItem(
                                category: .nodeModules,
                                url: url,
                                sizeInBytes: size,
                                modifiedAt: modificationDate(for: url)
                            )
                        )
                    }
                    enumerator.skipDescendants()
                }
            }
        }

        return collected.sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func scanDirectChildren(of directory: URL, category: StorageCleanupCategory) -> [StorageCleanupItem] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
                  values.isSymbolicLink != true else {
                return nil
            }

            let size = directorySize(at: url)
            guard size > 0 else { return nil }
            return StorageCleanupItem(
                category: category,
                url: url,
                sizeInBytes: size,
                modifiedAt: modificationDate(for: url)
            )
        }
        .sorted { $0.sizeInBytes > $1.sizeInBytes }
    }

    private func modificationDate(for url: URL) -> Date? {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        return try? url.resourceValues(forKeys: keys).contentModificationDate
    }

    private func directorySize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .isSymbolicLinkKey]

        if let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys),
                  values.isSymbolicLink != true,
                  values.isRegularFile == true else {
                continue
            }

            totalSize += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return totalSize
    }
}
