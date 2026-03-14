import AppKit
import Foundation

enum StorageCleanupActions {
    static func reveal(_ item: StorageCleanupItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    static func reveal(_ items: [StorageCleanupItem]) {
        let urls = items.map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    @discardableResult
    static func moveToTrash(_ item: StorageCleanupItem) -> Bool {
        do {
            _ = try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            return true
        } catch {
            NSLog("Failed to move item to trash: %@", error.localizedDescription)
            return false
        }
    }

    static func confirmProceedAfterUsageCheck(findings: [StorageCleanupUsageFinding], totalItemCount: Int) -> Bool {
        guard !findings.isEmpty else { return true }

        let alert = NSAlert()
        alert.messageText = "storage.inUse.title".localized
        alert.informativeText = usageSummary(for: findings, totalItemCount: totalItemCount)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "storage.inUse.continue".localized)
        alert.addButton(withTitle: "action.cancel".localized)
        alert.addButton(withTitle: "storage.action.revealSelected".localized)

        let response = alert.runModal()
        if response == .alertThirdButtonReturn {
            reveal(findings.map(\.item))
            return false
        }

        return response == .alertFirstButtonReturn
    }

    static func confirmMoveToTrash(itemCount: Int, title: String, totalSizeInBytes: Int64) -> Bool {
        let alert = NSAlert()
        alert.messageText = "storage.confirm.title".localized
        alert.informativeText = String(
            format: "storage.confirm.message".localized,
            title,
            itemCount,
            StorageCleanupFormatter.string(from: totalSizeInBytes)
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: "storage.action.trash".localized)
        alert.addButton(withTitle: "action.cancel".localized)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func usageSummary(for findings: [StorageCleanupUsageFinding], totalItemCount: Int) -> String {
        let visibleFindings = Array(findings.prefix(3))
        let body = visibleFindings.map { finding in
            let processSummary = finding.processes.prefix(3).map { process in
                "\(process.command) (PID \(process.pid))"
            }.joined(separator: ", ")

            var line = "- \(finding.item.displayName): \(processSummary)"
            if finding.didTimeOut {
                line += " — \("storage.inUse.timeout".localized)"
            }
            return line
        }.joined(separator: "\n")

        let remainingCount = max(findings.count - visibleFindings.count, 0)
        let remainingLine = remainingCount > 0
            ? "\n\n" + String(format: "storage.inUse.more".localized, remainingCount)
            : ""

        let totalLine = totalItemCount > findings.count
            ? "\n\n" + String(format: "storage.inUse.partialCheck".localized, totalItemCount)
            : ""

        return "storage.inUse.message".localized + "\n\n" + body + remainingLine + totalLine
    }
}
