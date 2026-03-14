import Foundation

enum StorageCleanupFormatter {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static func string(from byteCount: Int64) -> String {
        byteFormatter.string(fromByteCount: byteCount)
    }
}
