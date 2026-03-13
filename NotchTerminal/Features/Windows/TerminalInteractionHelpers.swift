import CoreGraphics
import Foundation

enum TerminalDropInteractionHelper {
    static func hasDroppableFileURLs(_ urls: [URL]?) -> Bool {
        guard let urls else { return false }
        return urls.contains { $0.isFileURL && !$0.path(percentEncoded: false).isEmpty }
    }

    static func insertionText(for urls: [URL]) -> String? {
        let quotedPaths = urls
            .filter(\.isFileURL)
            .map { $0.path(percentEncoded: false) }
            .filter { !$0.isEmpty }
            .map(shellQuotedPath)

        guard !quotedPaths.isEmpty else { return nil }
        return quotedPaths.joined(separator: " ") + " "
    }

    static func shellQuotedPath(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum TerminalSelectionAutoScrollLogic {
    static func delta(for point: CGPoint, in bounds: CGRect, rows: Int) -> Int {
        let overflowTop = max(0, point.y - bounds.maxY)
        let overflowBottom = max(0, bounds.minY - point.y)

        if overflowTop > 0 {
            return -velocity(for: overflowTop, rows: rows)
        }

        if overflowBottom > 0 {
            return velocity(for: overflowBottom, rows: rows)
        }

        return 0
    }

    private static func velocity(for overflow: CGFloat, rows: Int) -> Int {
        if overflow > 36 { return max(rows, 20) }
        if overflow > 20 { return 10 }
        if overflow > 8 { return 3 }
        return 1
    }
}
