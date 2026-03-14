import SwiftUI

struct StorageCleanupSummaryView: View {
    @Bindable var service: StorageCleanupService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("storage.menu.title".localized, systemImage: "internaldrive")
                    .font(.headline)

                Spacer(minLength: 12)

                Text(StorageCleanupFormatter.string(from: service.displayedTotalSizeInBytes))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if service.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("storage.menu.foundSoFar".localized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(
                            String(
                                format: "storage.menu.progress".localized,
                                service.scannedCategoryCount,
                                service.totalCategoryCount
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("storage.menu.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if service.visibleCategoryResults.isEmpty, !service.isScanning {
                Text("storage.menu.empty".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach(service.visibleCategoryResults) { result in
                StorageCleanupCategoryRow(
                    result: result,
                    service: service
                )
            }

            Divider()

            Button("storage.menu.scanAgain".localized) {
                service.scanNow()
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 300, alignment: .leading)
        .task {
            service.scanIfNeeded()
        }
    }
}

private struct StorageCleanupCategoryRow: View {
    let result: StorageCleanupCategoryResult
    let service: StorageCleanupService

    var body: some View {
        Button {
            service.showDetails(for: result)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: result.category.icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.title)
                    .foregroundStyle(.primary)

                    Text(String(format: "storage.detail.itemsCount".localized, result.items.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                Text(StorageCleanupFormatter.string(from: result.totalSizeInBytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
