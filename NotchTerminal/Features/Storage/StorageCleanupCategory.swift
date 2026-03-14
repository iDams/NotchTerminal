import Foundation

enum StorageCleanupCategory: String, CaseIterable, Identifiable {
    case nodeModules
    case derivedData
    case pods
    case carthage
    case caches
    case logs
    case trash
    case downloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nodeModules:
            return "storage.category.nodeModules".localized
        case .derivedData:
            return "storage.category.derivedData".localized
        case .pods:
            return "storage.category.pods".localized
        case .carthage:
            return "storage.category.carthage".localized
        case .caches:
            return "storage.category.caches".localized
        case .logs:
            return "storage.category.logs".localized
        case .trash:
            return "storage.category.trash".localized
        case .downloads:
            return "storage.category.downloads".localized
        }
    }

    var subtitle: String {
        switch self {
        case .nodeModules:
            return "storage.category.nodeModules.subtitle".localized
        case .derivedData:
            return "storage.category.derivedData.subtitle".localized
        case .pods:
            return "storage.category.pods.subtitle".localized
        case .carthage:
            return "storage.category.carthage.subtitle".localized
        case .caches:
            return "storage.category.caches.subtitle".localized
        case .logs:
            return "storage.category.logs.subtitle".localized
        case .trash:
            return "storage.category.trash.subtitle".localized
        case .downloads:
            return "storage.category.downloads.subtitle".localized
        }
    }

    var icon: String {
        switch self {
        case .nodeModules:
            return "shippingbox"
        case .derivedData:
            return "hammer"
        case .pods:
            return "shippingbox.circle"
        case .carthage:
            return "cube.box"
        case .caches:
            return "externaldrive.badge.timemachine"
        case .logs:
            return "doc.text.magnifyingglass"
        case .trash:
            return "trash"
        case .downloads:
            return "arrow.down.circle"
        }
    }

    var allowsMoveToTrash: Bool { true }
}
