import AppKit

extension NSScreen {
    var notchSize: CGSize {
        guard #available(macOS 12.0, *) else { return .zero }
        guard safeAreaInsets.top > 0 else { return .zero }

        let notchHeight = safeAreaInsets.top
        let fullWidth = frame.width
        let leftPadding = auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = auxiliaryTopRightArea?.width ?? 0
        guard leftPadding > 0, rightPadding > 0 else { return .zero }

        let notchWidth = fullWidth - leftPadding - rightPadding
        guard notchWidth > 0 else { return .zero }
        return CGSize(width: notchWidth, height: notchHeight)
    }

    func notchSizeOrFallback(fallback: CGSize) -> CGSize {
        let size = notchSize
        guard size != .zero else { return fallback }
        return size
    }
}
