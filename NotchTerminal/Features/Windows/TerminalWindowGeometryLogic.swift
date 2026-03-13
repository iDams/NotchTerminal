import CoreGraphics

enum TerminalWindowGeometryLogic {
    static func initialFrame(screenFrame: CGRect, windowSize: CGSize) -> CGRect {
        let origin = CGPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.maxY - windowSize.height - 220
        )
        return CGRect(origin: origin, size: windowSize)
    }

    static func compactToggleFrame(currentFrame: CGRect, targetSize: CGSize) -> CGRect {
        let targetOrigin = CGPoint(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.maxY - targetSize.height
        )
        return CGRect(origin: targetOrigin, size: targetSize)
    }

    static func resetFrame(currentFrame: CGRect, expandedSize: CGSize) -> CGRect {
        CGRect(
            x: currentFrame.minX,
            y: currentFrame.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )
    }

    static func restoredFrameFromMaximize(
        currentFrame: CGRect,
        expandedSize: CGSize,
        preMaximizeFrame: CGRect?
    ) -> CGRect {
        preMaximizeFrame ?? CGRect(
            origin: CGPoint(
                x: currentFrame.midX - expandedSize.width / 2,
                y: currentFrame.midY - expandedSize.height / 2
            ),
            size: expandedSize
        )
    }
}
