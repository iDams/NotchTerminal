import Foundation
import Observation

@MainActor
@Observable
final class StorageCleanupService {
    static let shared = StorageCleanupService()

    private let scanner = StorageCleanupScanner()
    private let overviewPresenter = StorageCleanupOverviewPresenter()
    private var scanTask: Task<Void, Never>?

    private(set) var lastResult: StorageCleanupScanResult?
    private(set) var isScanning = false
    private(set) var partialResults: [StorageCleanupCategoryResult] = []
    private(set) var scannedCategoryCount = 0
    private(set) var selectedCategory: StorageCleanupCategory?
    var searchText = ""
    var dateFilter: StorageCleanupDateFilter = .all
    var sizeFilter: StorageCleanupSizeFilter = .any
    var sortOption: StorageCleanupSortOption = .largestFirst

    var selectedCategoryResult: StorageCleanupCategoryResult? {
        guard let selectedCategory else { return visibleCategoryResults.first }
        return visibleCategoryResults.first(where: { $0.category == selectedCategory }) ?? visibleCategoryResults.first
    }

    var visibleCategoryResults: [StorageCleanupCategoryResult] {
        if isScanning {
            return sortedVisibleResults(from: partialResults)
        }

        return sortedVisibleResults(from: lastResult?.categoryResults ?? [])
    }

    var displayedTotalSizeInBytes: Int64 {
        if isScanning {
            return partialResults.reduce(0) { $0 + $1.totalSizeInBytes }
        }

        return lastResult?.totalSizeInBytes ?? 0
    }

    var totalCategoryCount: Int {
        StorageCleanupCategory.allCases.count
    }

    private func sortedVisibleResults(from results: [StorageCleanupCategoryResult]) -> [StorageCleanupCategoryResult] {
        results
            .filter { !$0.items.isEmpty && $0.totalSizeInBytes > 0 }
            .sorted { lhs, rhs in
                if lhs.totalSizeInBytes == rhs.totalSizeInBytes {
                    return lhs.category.title.localizedStandardCompare(rhs.category.title) == .orderedAscending
                }

                return lhs.totalSizeInBytes > rhs.totalSizeInBytes
            }
    }

    func scanIfNeeded() {
        if isScanning { return }
        if let lastResult, Date().timeIntervalSince(lastResult.scannedAt) < 300 { return }
        scanNow()
    }

    func scanNow() {
        scanTask?.cancel()
        isScanning = true
        partialResults = []
        scannedCategoryCount = 0

        scanTask = Task { [weak self] in
            guard let self else { return }

            let result = await scanner.scan { [weak self] categoryResult in
                guard let self, !Task.isCancelled else { return }
                await MainActor.run {
                    self.partialResults.removeAll(where: { $0.category == categoryResult.category })
                    self.partialResults.append(categoryResult)
                    self.partialResults.sort { lhs, rhs in
                        StorageCleanupCategory.allCases.firstIndex(of: lhs.category) ?? 0 <
                        StorageCleanupCategory.allCases.firstIndex(of: rhs.category) ?? 0
                    }
                    self.scannedCategoryCount = self.partialResults.count
                    self.syncSelection()
                }
            }

            guard !Task.isCancelled else { return }
            self.lastResult = result
            self.partialResults = result.categoryResults
            self.scannedCategoryCount = result.categoryResults.count
            self.isScanning = false
            self.syncSelection()
        }
    }

    @discardableResult
    func remove(_ item: StorageCleanupItem) -> Bool {
        remove(items: [item], title: item.displayName)
    }

    @discardableResult
    func removeAll(in result: StorageCleanupCategoryResult) -> Bool {
        remove(items: result.items, title: result.category.title)
    }

    @discardableResult
    func remove(items: [StorageCleanupItem], title: String) -> Bool {
        guard !items.isEmpty else { return false }

        let usageFindings = StorageCleanupUsageDiagnostics.inspect(items: items)
        guard StorageCleanupActions.confirmProceedAfterUsageCheck(findings: usageFindings, totalItemCount: items.count) else {
            return false
        }

        let totalSize = items.reduce(0) { $0 + $1.sizeInBytes }
        guard StorageCleanupActions.confirmMoveToTrash(
            itemCount: items.count,
            title: title,
            totalSizeInBytes: totalSize
        ) else {
            return false
        }

        var removedIDs = Set<String>()
        for item in items {
            if StorageCleanupActions.moveToTrash(item) {
                removedIDs.insert(item.id)
            }
        }

        guard !removedIDs.isEmpty else { return false }

        applyRemoval(itemIDs: removedIDs)
        return true
    }

    private func applyRemoval(itemIDs: Set<String>) {
        if let lastResult {
            self.lastResult = lastResult.removingItems(withIDs: itemIDs)
        }

        if !partialResults.isEmpty {
            partialResults = partialResults.map { $0.removingItems(withIDs: itemIDs) }
        }

        syncSelection()
    }

    func showDetails(for result: StorageCleanupCategoryResult) {
        selectedCategory = result.category
    }

    func showSummary() {
        selectedCategory = visibleCategoryResults.first?.category
    }

    func selectCategory(_ category: StorageCleanupCategory?) {
        selectedCategory = category
    }

    func showOverview() {
        overviewPresenter.present(service: self)
    }

    func filteredItems(for result: StorageCleanupCategoryResult) -> [StorageCleanupItem] {
        StorageCleanupFiltering.apply(
            to: result.items,
            searchText: searchText,
            dateFilter: dateFilter,
            sizeFilter: sizeFilter,
            sortOption: sortOption
        )
    }

    var activeFilters: [StorageCleanupActiveFilter] {
        StorageCleanupFiltering.activeFilters(
            searchText: searchText,
            dateFilter: dateFilter,
            sizeFilter: sizeFilter,
            sortOption: sortOption
        )
    }

    func resetFilters() {
        searchText = ""
        dateFilter = .all
        sizeFilter = .any
        sortOption = .largestFirst
    }

    private func syncSelection() {
        let availableCategories = Set(visibleCategoryResults.map(\.category))

        guard !availableCategories.isEmpty else {
            selectedCategory = nil
            return
        }

        if let selectedCategory, availableCategories.contains(selectedCategory) {
            return
        }

        selectedCategory = visibleCategoryResults.first?.category
    }
}
