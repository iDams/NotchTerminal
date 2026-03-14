import Foundation

enum StorageCleanupDateFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case last7Days
    case last30Days
    case last90Days

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "storage.filter.date.all".localized
        case .today:
            return "storage.filter.date.today".localized
        case .last7Days:
            return "storage.filter.date.week".localized
        case .last30Days:
            return "storage.filter.date.month".localized
        case .last90Days:
            return "storage.filter.date.quarter".localized
        }
    }

    func includes(_ item: StorageCleanupItem, now: Date = .now) -> Bool {
        guard self != .all else { return true }
        guard let modifiedAt = item.modifiedAt else { return false }

        let calendar = Calendar.current
        switch self {
        case .all:
            return true
        case .today:
            return calendar.isDate(modifiedAt, inSameDayAs: now)
        case .last7Days:
            return modifiedAt >= (calendar.date(byAdding: .day, value: -7, to: now) ?? .distantPast)
        case .last30Days:
            return modifiedAt >= (calendar.date(byAdding: .day, value: -30, to: now) ?? .distantPast)
        case .last90Days:
            return modifiedAt >= (calendar.date(byAdding: .day, value: -90, to: now) ?? .distantPast)
        }
    }
}

enum StorageCleanupSizeFilter: String, CaseIterable, Identifiable {
    case any
    case over100MB
    case over500MB
    case over1GB

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any:
            return "storage.filter.size.any".localized
        case .over100MB:
            return "storage.filter.size.100mb".localized
        case .over500MB:
            return "storage.filter.size.500mb".localized
        case .over1GB:
            return "storage.filter.size.1gb".localized
        }
    }

    private var minimumSizeInBytes: Int64 {
        switch self {
        case .any:
            return 0
        case .over100MB:
            return 100 * 1_024 * 1_024
        case .over500MB:
            return 500 * 1_024 * 1_024
        case .over1GB:
            return 1 * 1_024 * 1_024 * 1_024
        }
    }

    func includes(_ item: StorageCleanupItem) -> Bool {
        item.sizeInBytes >= minimumSizeInBytes
    }
}

enum StorageCleanupSortOption: String, CaseIterable, Identifiable {
    case largestFirst
    case smallestFirst
    case mostRecent
    case oldestFirst
    case name
    case path

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largestFirst:
            return "storage.filter.sort.largest".localized
        case .smallestFirst:
            return "storage.filter.sort.smallest".localized
        case .mostRecent:
            return "storage.filter.sort.recent".localized
        case .oldestFirst:
            return "storage.filter.sort.oldest".localized
        case .name:
            return "storage.filter.sort.name".localized
        case .path:
            return "storage.filter.sort.path".localized
        }
    }
}

enum StorageCleanupFiltering {
    static func apply(
        to items: [StorageCleanupItem],
        searchText: String,
        dateFilter: StorageCleanupDateFilter,
        sizeFilter: StorageCleanupSizeFilter,
        sortOption: StorageCleanupSortOption
    ) -> [StorageCleanupItem] {
        let filteredItems = items.filter { item in
            matchesSearch(item, searchText: searchText) &&
            dateFilter.includes(item) &&
            sizeFilter.includes(item)
        }

        return filteredItems.sorted { lhs, rhs in
            switch sortOption {
            case .largestFirst:
                if lhs.sizeInBytes == rhs.sizeInBytes {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.sizeInBytes > rhs.sizeInBytes
            case .smallestFirst:
                if lhs.sizeInBytes == rhs.sizeInBytes {
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.sizeInBytes < rhs.sizeInBytes
            case .mostRecent:
                return compareDates(lhs.modifiedAt, rhs.modifiedAt, fallback: {
                    lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }, descending: true)
            case .oldestFirst:
                return compareDates(lhs.modifiedAt, rhs.modifiedAt, fallback: {
                    lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }, descending: false)
            case .name:
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            case .path:
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            }
        }
    }

    private static func matchesSearch(_ item: StorageCleanupItem, searchText: String) -> Bool {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        return item.displayName.localizedStandardContains(trimmedQuery) ||
        item.path.localizedStandardContains(trimmedQuery)
    }

    private static func compareDates(
        _ lhs: Date?,
        _ rhs: Date?,
        fallback: () -> Bool,
        descending: Bool
    ) -> Bool {
        switch (lhs, rhs) {
        case let (lhsDate?, rhsDate?):
            if lhsDate == rhsDate {
                return fallback()
            }
            return descending ? lhsDate > rhsDate : lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return fallback()
        }
    }

    static func activeFilters(
        searchText: String,
        dateFilter: StorageCleanupDateFilter,
        sizeFilter: StorageCleanupSizeFilter,
        sortOption: StorageCleanupSortOption
    ) -> [StorageCleanupActiveFilter] {
        var filters: [StorageCleanupActiveFilter] = []

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            filters.append(StorageCleanupActiveFilter(id: "search", title: trimmedQuery, systemImage: "magnifyingglass"))
        }

        if dateFilter != .all {
            filters.append(StorageCleanupActiveFilter(id: "date", title: dateFilter.title, systemImage: "calendar"))
        }

        if sizeFilter != .any {
            filters.append(StorageCleanupActiveFilter(id: "size", title: sizeFilter.title, systemImage: "internaldrive"))
        }

        if sortOption != .largestFirst {
            filters.append(StorageCleanupActiveFilter(id: "sort", title: sortOption.title, systemImage: "arrow.up.arrow.down"))
        }

        return filters
    }
}

struct StorageCleanupActiveFilter: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
}
