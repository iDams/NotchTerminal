import SwiftUI
import AppKit

struct StorageCleanupOverviewView: View {
    @Bindable var service: StorageCleanupService
    @State private var storageWindow: NSWindow?

    private let idealWindowWidth: CGFloat = 1_040
    private let minimumWindowWidth: CGFloat = 900
    private let minimumHeight: CGFloat = 560
    private let maximumHeight: CGFloat = 860

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 320)
        } detail: {
            detailContent
        }
        .background(
            StorageCleanupWindowObserver { window in
                attach(to: window)
            }
        )
        .frame(minWidth: minimumWindowWidth, minHeight: minimumHeight)
        .task {
            service.scanIfNeeded()
        }
        .onChange(of: service.visibleCategoryResults.count) { _, _ in
            resizeWindow(animated: true)
        }
        .searchable(
            text: $service.searchText,
            placement: .toolbar,
            prompt: Text("storage.search.placeholder".localized)
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                filterMenu(
                    title: "storage.filter.date".localized,
                    systemImage: "calendar",
                    selection: $service.dateFilter,
                    allCases: StorageCleanupDateFilter.allCases
                )

                filterMenu(
                    title: "storage.filter.size".localized,
                    systemImage: "internaldrive",
                    selection: $service.sizeFilter,
                    allCases: StorageCleanupSizeFilter.allCases
                )

                filterMenu(
                    title: "storage.filter.sort".localized,
                    systemImage: "arrow.up.arrow.down",
                    selection: $service.sortOption,
                    allCases: StorageCleanupSortOption.allCases
                )

                Button {
                    service.scanNow()
                } label: {
                    Label("storage.menu.scanAgain".localized, systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var sidebar: some View {
        List(service.visibleCategoryResults, selection: selectedCategoryBinding) { result in
            StorageCleanupSidebarRow(result: result)
                .tag(result.category)
        }
        .listStyle(.sidebar)
        .overlay {
            if service.visibleCategoryResults.isEmpty, !service.isScanning {
                ContentUnavailableView(
                    "storage.menu.empty".localized,
                    systemImage: "externaldrive.badge.checkmark"
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let selectedCategoryResult = service.selectedCategoryResult {
            StorageCleanupDetailView(
                result: selectedCategoryResult,
                service: service
            )
        } else {
            ContentUnavailableView(
                "storage.detail.selectCategory".localized,
                systemImage: "sidebar.leading",
                description: Text("storage.detail.selectCategorySubtitle".localized)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("storage.menu.title".localized)
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

                    Text(String(format: "storage.menu.progress".localized, service.scannedCategoryCount, service.totalCategoryCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("storage.menu.sidebarSubtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var selectedCategoryBinding: Binding<StorageCleanupCategory?> {
        Binding(
            get: { service.selectedCategoryResult?.category },
            set: { service.selectCategory($0) }
        )
    }

    private var targetWindowHeight: CGFloat {
        let selectedCount = service.selectedCategoryResult?.items.count ?? 0
        let estimatedRowsHeight = CGFloat(min(selectedCount, 10)) * 24
        let sidebarHeight = 420 + CGFloat(service.visibleCategoryResults.count) * 12 + (service.isScanning ? 22 : 0)
        return min(max(max(sidebarHeight, 560 + estimatedRowsHeight), minimumHeight), maximumHeight)
    }

    private func attach(to window: NSWindow) {
        guard storageWindow !== window else { return }
        storageWindow = window
        window.contentMinSize = NSSize(width: minimumWindowWidth, height: minimumHeight)
        window.contentMaxSize = NSSize(width: 1_280, height: maximumHeight)
        resizeWindow(animated: false)
    }

    private func resizeWindow(animated: Bool) {
        guard let window = storageWindow else { return }

        DispatchQueue.main.async {
            guard window === self.storageWindow else { return }

            let currentFrame = window.frame
            let targetContentSize = NSSize(width: self.idealWindowWidth, height: self.targetWindowHeight)
            let targetFrameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: targetContentSize)).size

            let targetFrame = NSRect(
                x: currentFrame.minX,
                y: currentFrame.maxY - targetFrameSize.height,
                width: targetFrameSize.width,
                height: targetFrameSize.height
            )

            guard abs(currentFrame.width - targetFrame.width) > 1 || abs(currentFrame.height - targetFrame.height) > 1 else {
                return
            }

            window.setFrame(targetFrame, display: true, animate: animated)
        }
    }

    private func filterMenu<Selection: Hashable & Identifiable & CaseIterable>(
        title menuTitle: String,
        systemImage: String,
        selection: Binding<Selection>,
        allCases: Selection.AllCases
    ) -> some View where Selection.AllCases: RandomAccessCollection, Selection.AllCases.Element == Selection {
        Menu {
            Picker(menuTitle, selection: selection) {
                ForEach(Array(allCases)) { option in
                    Text(optionTitle(for: option))
                        .tag(option)
                }
            }
        } label: {
            Label(menuTitle, systemImage: systemImage)
        }
    }

    private func optionTitle(for option: some Identifiable) -> String {
        switch option {
        case let value as StorageCleanupDateFilter:
            return value.title
        case let value as StorageCleanupSizeFilter:
            return value.title
        case let value as StorageCleanupSortOption:
            return value.title
        default:
            return ""
        }
    }
}

private struct StorageCleanupSidebarRow: View {
    let result: StorageCleanupCategoryResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.category.icon)
                .frame(width: 18)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(result.category.title)
                    .lineLimit(1)

                Text(String(format: "storage.detail.itemsCount".localized, result.items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(StorageCleanupFormatter.string(from: result.totalSizeInBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct StorageCleanupWindowObserver: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        ObserverView(onResolve: onResolve)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let observerView = nsView as? ObserverView else { return }
        observerView.onResolve = onResolve
        DispatchQueue.main.async {
            observerView.resolveWindowIfNeeded()
        }
    }

    private final class ObserverView: NSView {
        var onResolve: (NSWindow) -> Void

        init(onResolve: @escaping (NSWindow) -> Void) {
            self.onResolve = onResolve
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            resolveWindowIfNeeded()
        }

        func resolveWindowIfNeeded() {
            guard let window else { return }
            onResolve(window)
        }
    }
}
