import Foundation
import CoreGraphics

struct TerminalWindowDockTarget: Equatable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
}

enum TerminalWindowDockingLogic {
    struct PreviewUpdate: Equatable {
        let hoverDisplayID: CGDirectDisplayID?
        let shouldPreview: Bool
        let shouldRestorePreview: Bool
        let shouldClearPendingTarget: Bool
        let suppressionUntil: Date?
    }

    struct DragEndResolution: Equatable {
        let targetToMinimize: CGDirectDisplayID?
        let hoverDisplayIDsToClear: [CGDirectDisplayID]
        let shouldRestoreAllPreviews: Bool
        let shouldClearPendingTargets: Bool
    }

    struct ClearPreviewResolution: Equatable {
        let hoverDisplayIDsToClear: [CGDirectDisplayID]
        let shouldClearSuppression: Bool
        let shouldRestorePreview: Bool
        let shouldRemoveMonitor: Bool
        let shouldRestoreAllPreviews: Bool
        let shouldClearPendingTargets: Bool
    }

    struct Candidate {
        let target: TerminalWindowDockTarget
        let effectiveFrame: CGRect
    }

    static func dockThumbnailFrame(from sourceFrame: CGRect, notchFrame: CGRect?) -> CGRect {
        let size = CGSize(width: 54, height: 54)
        let anchorFrame = notchFrame ?? sourceFrame
        let origin = CGPoint(
            x: anchorFrame.midX - size.width / 2,
            y: anchorFrame.maxY - size.height
        )
        return CGRect(origin: origin, size: size)
    }

    static func previewFrame(for original: CGRect) -> CGRect {
        let width = max(300, original.width * 0.74)
        let height = max(190, original.height * 0.74)
        let previewSize = CGSize(width: width, height: height)
        let previewOrigin = CGPoint(
            x: original.midX - (previewSize.width / 2),
            y: original.maxY - previewSize.height
        )
        return CGRect(origin: previewOrigin, size: previewSize)
    }

    static func closestTarget(
        to windowFrame: CGRect,
        sensitivity: CGFloat,
        candidates: [Candidate]
    ) -> TerminalWindowDockTarget? {
        let topCenter = CGPoint(x: windowFrame.midX, y: windowFrame.maxY)

        return candidates
            .map { candidate -> (TerminalWindowDockTarget, CGFloat, CGRect) in
                let expanded = expandedTargetFrame(candidate.effectiveFrame, sensitivity: sensitivity)
                let dx = topCenter.x - expanded.midX
                let dy = topCenter.y - expanded.midY
                let dist2 = (dx * dx) + (dy * dy)
                return (candidate.target, dist2, expanded)
            }
            .filter { $0.2.contains(topCenter) }
            .min { $0.1 < $1.1 }?
            .0
    }

    static func isPillShape(frame: CGRect) -> Bool {
        frame.width > frame.height * 2.2
    }

    static func previewUpdate(
        dragToNotchEnabled: Bool,
        isDraggingWithMouse: Bool,
        now: Date,
        suppressionUntil: Date?,
        previousTarget: TerminalWindowDockTarget?,
        nearTarget: TerminalWindowDockTarget?,
        previousTargetIsPill: Bool
    ) -> PreviewUpdate {
        guard dragToNotchEnabled else {
            return PreviewUpdate(
                hoverDisplayID: nil,
                shouldPreview: false,
                shouldRestorePreview: true,
                shouldClearPendingTarget: true,
                suppressionUntil: nil
            )
        }

        if let suppressionUntil, suppressionUntil > now {
            return PreviewUpdate(
                hoverDisplayID: nil,
                shouldPreview: false,
                shouldRestorePreview: true,
                shouldClearPendingTarget: true,
                suppressionUntil: suppressionUntil
            )
        }

        if let nearTarget, isDraggingWithMouse {
            return PreviewUpdate(
                hoverDisplayID: nearTarget.displayID,
                shouldPreview: true,
                shouldRestorePreview: false,
                shouldClearPendingTarget: false,
                suppressionUntil: nil
            )
        }

        return PreviewUpdate(
            hoverDisplayID: nil,
            shouldPreview: false,
            shouldRestorePreview: true,
            shouldClearPendingTarget: true,
            suppressionUntil: previousTargetIsPill && isDraggingWithMouse
                ? now.addingTimeInterval(0.45)
                : nil
        )
    }

    static func dragEndResolution(
        dragToNotchEnabled: Bool,
        pendingTargets: [TerminalWindowDockTarget],
        matchedMinimizeDisplayID: CGDirectDisplayID?
    ) -> DragEndResolution {
        guard dragToNotchEnabled else {
            return DragEndResolution(
                targetToMinimize: nil,
                hoverDisplayIDsToClear: pendingTargets.map(\.displayID),
                shouldRestoreAllPreviews: true,
                shouldClearPendingTargets: true
            )
        }

        if let matchedMinimizeDisplayID {
            return DragEndResolution(
                targetToMinimize: matchedMinimizeDisplayID,
                hoverDisplayIDsToClear: [matchedMinimizeDisplayID],
                shouldRestoreAllPreviews: false,
                shouldClearPendingTargets: false
            )
        }

        return DragEndResolution(
            targetToMinimize: nil,
            hoverDisplayIDsToClear: pendingTargets.map(\.displayID),
            shouldRestoreAllPreviews: true,
            shouldClearPendingTargets: true
        )
    }

    static func clearPreviewResolution(
        pendingTargets: [TerminalWindowDockTarget],
        scope: ClearPreviewScope
    ) -> ClearPreviewResolution {
        switch scope {
        case .singleTarget:
            return ClearPreviewResolution(
                hoverDisplayIDsToClear: pendingTargets.map(\.displayID),
                shouldClearSuppression: true,
                shouldRestorePreview: true,
                shouldRemoveMonitor: false,
                shouldRestoreAllPreviews: false,
                shouldClearPendingTargets: true
            )
        case .allTargets:
            return ClearPreviewResolution(
                hoverDisplayIDsToClear: pendingTargets.map(\.displayID),
                shouldClearSuppression: true,
                shouldRestorePreview: false,
                shouldRemoveMonitor: true,
                shouldRestoreAllPreviews: true,
                shouldClearPendingTargets: true
            )
        }
    }

    enum ClearPreviewScope {
        case singleTarget
        case allTargets
    }

    private static func expandedTargetFrame(_ frame: CGRect, sensitivity: CGFloat) -> CGRect {
        if isPillShape(frame: frame) {
            return frame.insetBy(dx: -sensitivity, dy: -(sensitivity * 0.38))
        }
        return frame.insetBy(dx: -sensitivity, dy: -(sensitivity * 0.75))
    }
}
