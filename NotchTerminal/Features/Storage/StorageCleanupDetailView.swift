import SwiftUI

struct StorageCleanupDetailView: View {
    let result: StorageCleanupCategoryResult
    @Bindable var service: StorageCleanupService
    @State private var items: [StorageCleanupItem]
    @State private var selectedItemIDs: Set<String> = []
    @State private var relativeDateFormatter = RelativeDateTimeFormatter()
    @State private var nameSortMode: NameSortMode = .name

    init(result: StorageCleanupCategoryResult, service: StorageCleanupService) {
        self.result = result
        self.service = service
        _items = State(initialValue: result.items)
    }

    private var filteredItems: [StorageCleanupItem] {
        service.filteredItems(for: currentResult)
    }

    private var selectedItems: [StorageCleanupItem] {
        filteredItems.filter { selectedItemIDs.contains($0.id) }
    }

    private var currentResult: StorageCleanupCategoryResult {
        StorageCleanupCategoryResult(category: result.category, items: items)
    }

    private var totalVisibleSizeInBytes: Int64 {
        filteredItems.reduce(0) { $0 + $1.sizeInBytes }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if filteredItems.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    tableHeader

                    Divider()

                    List {
                        ForEach(filteredItems) { item in
                            itemRow(for: item)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: result.items.map { $0.id }) { _, updatedIDs in
            let updatedIDSet = Set(updatedIDs)
            items = result.items
            selectedItemIDs = selectedItemIDs.intersection(updatedIDSet)
            syncNameSortMode()
        }
        .onAppear {
            syncNameSortMode()
        }
        .onChange(of: service.sortOption) { _, _ in
            syncNameSortMode()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(result.category.title, systemImage: result.category.icon)
                        .font(.title2.weight(.semibold))

                    Text(result.category.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(StorageCleanupFormatter.string(from: totalVisibleSizeInBytes))
                        .font(.title3.monospacedDigit())

                    Text(String(format: "storage.detail.filteredCount".localized, filteredItems.count, items.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(selectionButtonTitle) {
                    toggleSelectAll()
                }

                Button("storage.action.revealSelected".localized) {
                    StorageCleanupActions.reveal(selectedItems)
                }
                .disabled(selectedItems.isEmpty)

                Button(selectedItems.isEmpty ? "storage.action.trashAll".localized : "storage.action.trashSelected".localized) {
                    removeSelectionOrAll()
                }
                .disabled(filteredItems.isEmpty)

                Spacer(minLength: 12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Button {
                toggleNameSort()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: allVisibleItemsSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(allVisibleItemsSelected ? Color.accentColor : .secondary)

                    Text(nameSortMode == .name ? "storage.detail.name".localized : "storage.detail.path".localized)

                    sortIndicator(for: service.sortOption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: 360, alignment: .leading)

            Divider()
                .frame(height: 18)

            Button {
                toggleModifiedSort()
            } label: {
                HStack(spacing: 8) {
                    Text("storage.detail.modified".localized)
                    sortIndicator(for: isModifiedSortActive ? service.sortOption : nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 160, alignment: .leading)

            Divider()
                .frame(height: 18)

            Button {
                toggleSizeSort()
            } label: {
                HStack(spacing: 8) {
                    Text("storage.detail.size".localized)
                    sortIndicator(for: isSizeSortActive ? service.sortOption : nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 140, alignment: .leading)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "storage.detail.noMatches".localized,
            systemImage: "line.3.horizontal.decrease.circle",
            description: Text("storage.detail.noMatchesSubtitle".localized)
        )
    }

    private var selectionButtonTitle: String {
        selectedItemIDs.count == filteredItems.count && !filteredItems.isEmpty
            ? "storage.action.clearSelection".localized
            : "storage.action.selectAll".localized
    }

    private var allVisibleItemsSelected: Bool {
        !filteredItems.isEmpty && selectedItemIDs.count == filteredItems.count
    }

    private var isModifiedSortActive: Bool {
        service.sortOption == .mostRecent || service.sortOption == .oldestFirst
    }

    private var isSizeSortActive: Bool {
        service.sortOption == .largestFirst || service.sortOption == .smallestFirst
    }

    private func itemRow(for item: StorageCleanupItem) -> some View {
        HStack(spacing: 0) {
            Button {
                toggleSelection(for: item)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selectedItemIDs.contains(item.id) ? Color.accentColor : .secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(nameSortMode == .name ? item.displayName : item.path)
                            .font(.headline)
                            .lineLimit(1)

                        Text(nameSortMode == .name ? item.path : item.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 360, alignment: .leading)

            Text(modifiedDateText(for: item))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(width: 160, alignment: .leading)

            Text(StorageCleanupFormatter.string(from: item.sizeInBytes))
                .font(.body.monospacedDigit())
                .padding(.horizontal, 12)
                .frame(width: 140, alignment: .leading)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
        .listRowBackground(selectedItemIDs.contains(item.id) ? Color.accentColor.opacity(0.12) : Color.clear)
        .contextMenu {
            Button("storage.action.reveal".localized) {
                StorageCleanupActions.reveal(item)
            }

            Button("storage.action.trash".localized) {
                remove(item)
            }
        }
    }

    private func toggleSelectAll() {
        if selectedItemIDs.count == filteredItems.count {
            selectedItemIDs.removeAll()
        } else {
            selectedItemIDs = Set(filteredItems.map(\.id))
        }
    }

    private func toggleSelection(for item: StorageCleanupItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    private func remove(_ item: StorageCleanupItem) {
        guard service.remove(item) else { return }
        items.removeAll { $0.id == item.id }
        selectedItemIDs.remove(item.id)
    }

    private func toggleNameSort() {
        switch nameSortMode {
        case .name:
            if service.sortOption == .name {
                nameSortMode = .path
                service.sortOption = .path
            } else {
                service.sortOption = .name
            }
        case .path:
            nameSortMode = .name
            service.sortOption = .name
        }
    }

    private func toggleModifiedSort() {
        service.sortOption = service.sortOption == .mostRecent ? .oldestFirst : .mostRecent
    }

    private func toggleSizeSort() {
        service.sortOption = service.sortOption == .largestFirst ? .smallestFirst : .largestFirst
    }

    @ViewBuilder
    private func sortIndicator(for sortOption: StorageCleanupSortOption?) -> some View {
        if let sortOption {
            Image(systemName: sortIcon(for: sortOption))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func sortIcon(for sortOption: StorageCleanupSortOption) -> String {
        switch sortOption {
        case .largestFirst, .mostRecent:
            return "arrow.down"
        case .smallestFirst, .oldestFirst:
            return "arrow.up"
        case .name, .path:
            return "arrow.up.arrow.down"
        }
    }

    private func syncNameSortMode() {
        nameSortMode = service.sortOption == .path ? .path : .name
    }

    private func removeSelectionOrAll() {
        let itemsToRemove = selectedItems.isEmpty ? filteredItems : selectedItems
        let title = selectedItems.isEmpty ? result.category.title : "storage.action.selectedItemsTitle".localized
        guard service.remove(items: itemsToRemove, title: title) else { return }

        let removedIDs = Set(itemsToRemove.map(\.id))
        items.removeAll { removedIDs.contains($0.id) }
        selectedItemIDs.subtract(removedIDs)
    }

    private func modifiedDateText(for item: StorageCleanupItem) -> String {
        guard let modifiedAt = item.modifiedAt else {
            return "storage.detail.unknownDate".localized
        }

        let now = Date()
        if Calendar.current.isDate(modifiedAt, inSameDayAs: now) {
            return "storage.filter.date.today".localized
        }

        relativeDateFormatter.unitsStyle = .full
        return relativeDateFormatter.localizedString(for: modifiedAt, relativeTo: now)
    }
}

private enum NameSortMode {
    case name
    case path
}
