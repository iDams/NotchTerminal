import CoreGraphics

struct TerminalWindowDockTarget: Equatable {
    let displayID: CGDirectDisplayID
    let frame: CGRect
}

enum TerminalWindowDockingLogic {
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

    private static func expandedTargetFrame(_ frame: CGRect, sensitivity: CGFloat) -> CGRect {
        if isPillShape(frame: frame) {
            return frame.insetBy(dx: -sensitivity, dy: -(sensitivity * 0.38))
        }
        return frame.insetBy(dx: -sensitivity, dy: -(sensitivity * 0.75))
    }
}
