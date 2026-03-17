import CoreGraphics
import Foundation

/// Pure geometry helpers for the notch overlay.
/// Keeping these calculations side-effect free makes hover and hit-test rules
/// easy to reason about and verify in unit tests.
enum NotchOverlayGeometryLogic {
    struct DisplayConfiguration {
        let offsetX: CGFloat
        let offsetY: CGFloat
        let widthAdjustment: CGFloat
    }

    struct Constants {
        let collapsedNoNotchSize: CGSize
        let notchClosedWidthScale: CGFloat
        let notchClosedHeightScale: CGFloat
        let shadowPadding: CGFloat
        let noNotchTopInset: CGFloat
        let notchTopInset: CGFloat
    }

    static func closedSize(
        screenNotchSize: CGSize,
        fallbackNotchSize: CGSize,
        hasPhysicalNotch: Bool,
        widthOffset: CGFloat,
        heightOffset: CGFloat,
        configuration: DisplayConfiguration,
        constants: Constants
    ) -> CGSize {
        guard hasPhysicalNotch else {
            return CGSize(
                width: max(26, constants.collapsedNoNotchSize.width + configuration.widthAdjustment),
                height: constants.collapsedNoNotchSize.height
            )
        }

        let raw = screenNotchSize == .zero ? fallbackNotchSize : screenNotchSize
        return CGSize(
            width: max(92, raw.width * constants.notchClosedWidthScale + widthOffset + configuration.widthAdjustment),
            height: max(22, raw.height * constants.notchClosedHeightScale + heightOffset)
        )
    }

    static func panelFrame(
        screenFrame: CGRect,
        hasPhysicalNotch: Bool,
        configuration: DisplayConfiguration,
        constants: Constants
    ) -> CGRect {
        // The backing panel is intentionally larger than the visible notch so
        // SwiftUI can animate within a stable container without frame churn.
        let visualSize = CGSize(width: 1100, height: 160)
        let shoulderExtra: CGFloat = hasPhysicalNotch ? 64 : 0
        let topOvershoot: CGFloat = hasPhysicalNotch ? 6 : 0

        let panelSize = CGSize(
            width: visualSize.width + shoulderExtra + (constants.shadowPadding * 2),
            height: visualSize.height + topOvershoot + (constants.shadowPadding * 2)
        )
        let topInset = hasPhysicalNotch ? constants.notchTopInset : constants.noNotchTopInset

        let visualOrigin = CGPoint(
            x: screenFrame.midX - (visualSize.width + shoulderExtra) / 2 + configuration.offsetX,
            y: screenFrame.maxY - visualSize.height - topInset - configuration.offsetY
        )

        return CGRect(
            x: visualOrigin.x - constants.shadowPadding,
            y: visualOrigin.y - constants.shadowPadding,
            width: panelSize.width,
            height: panelSize.height
        )
    }

    static func hardwareNotchRect(
        screenFrame: CGRect,
        notchSize: CGSize,
        notchTopInset: CGFloat
    ) -> CGRect {
        guard notchSize != .zero else { return .zero }
        return CGRect(
            x: screenFrame.midX - notchSize.width / 2,
            y: screenFrame.maxY - notchSize.height - notchTopInset,
            width: notchSize.width,
            height: notchSize.height
        )
    }

    static func activationRect(
        screenFrame: CGRect,
        panelFrame: CGRect,
        closedSize: CGSize,
        hasPhysicalNotch: Bool,
        isExpanded: Bool,
        hardwareNotchRect: CGRect,
        configuration: DisplayConfiguration,
        constants: Constants
    ) -> CGRect {
        if isExpanded {
            // Expanded hover should follow the visible notch surface, not the
            // oversized panel used for shadows and animation.
            let visualWidth = CGFloat(1100)
            let visualHeight = CGFloat(160)
            let topInset = hasPhysicalNotch ? constants.notchTopInset : constants.noNotchTopInset
            let visualRect = CGRect(
                x: screenFrame.midX - visualWidth / 2 + configuration.offsetX,
                y: screenFrame.maxY - visualHeight - topInset - configuration.offsetY,
                width: visualWidth,
                height: visualHeight
            )
            // Keep the target forgiving without letting the invisible panel
            // claim input far away from the notch itself.
            return visualRect.insetBy(dx: -20, dy: -30)
        }

        if hasPhysicalNotch && hardwareNotchRect != .zero {
            let adjustedRect = CGRect(
                x: screenFrame.midX - closedSize.width / 2 + configuration.offsetX,
                y: screenFrame.maxY - closedSize.height - constants.notchTopInset - configuration.offsetY,
                width: closedSize.width,
                height: closedSize.height
            )
            return adjustedRect.insetBy(dx: -6, dy: -1)
        }

        let virtual = CGRect(
            x: screenFrame.midX - (constants.collapsedNoNotchSize.width + configuration.widthAdjustment) / 2 + configuration.offsetX,
            y: screenFrame.maxY - constants.collapsedNoNotchSize.height - constants.noNotchTopInset,
            width: max(26, constants.collapsedNoNotchSize.width + configuration.widthAdjustment),
            height: constants.collapsedNoNotchSize.height
        )
        return virtual.offsetBy(dx: 0, dy: -configuration.offsetY).insetBy(dx: -2, dy: -2)
    }

    static func shouldAllowMouseEvents(
        hasPhysicalNotch: Bool,
        isExpanded: Bool,
        screenFrame: CGRect,
        cursor: CGPoint,
        startupOrbRect: CGRect?,
        configuration: DisplayConfiguration,
        constants: Constants
    ) -> Bool {
        if isExpanded {
            // Mouse ownership stays close to the visible notch even though the
            // backing panel is larger than the rendered surface.
            let visualWidth = CGFloat(1100)
            let visualHeight = CGFloat(160)
            let topInset = hasPhysicalNotch ? constants.notchTopInset : constants.noNotchTopInset
            let visualRect = CGRect(
                x: screenFrame.midX - visualWidth / 2,
                y: screenFrame.maxY - visualHeight - topInset,
                width: visualWidth,
                height: visualHeight
            )
            return visualRect.insetBy(dx: -30, dy: -30).contains(cursor)
        }

        guard !hasPhysicalNotch else { return false }

        let virtual = CGRect(
            x: screenFrame.midX - (constants.collapsedNoNotchSize.width + configuration.widthAdjustment) / 2 + configuration.offsetX,
            y: screenFrame.maxY - constants.collapsedNoNotchSize.height - constants.noNotchTopInset,
            width: max(26, constants.collapsedNoNotchSize.width + configuration.widthAdjustment),
            height: constants.collapsedNoNotchSize.height
        )
        let notchRect = virtual.offsetBy(dx: 0, dy: -configuration.offsetY).insetBy(dx: -20, dy: -20)
        let orbRect = startupOrbRect?.insetBy(dx: -8, dy: -8)
        return notchRect.contains(cursor) || orbRect?.contains(cursor) == true
    }
}
