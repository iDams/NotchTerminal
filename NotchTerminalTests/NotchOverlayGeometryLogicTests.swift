import XCTest
@testable import NotchTerminal

final class NotchOverlayGeometryLogicTests: XCTestCase {
    private let constants = NotchOverlayGeometryLogic.Constants(
        collapsedNoNotchSize: CGSize(width: 126, height: 26),
        notchClosedWidthScale: 0.92,
        notchClosedHeightScale: 0.90,
        shadowPadding: 42,
        noNotchTopInset: 6,
        notchTopInset: 0
    )

    func testClosedSizeUsesFallbackForVirtualDisplays() {
        let size = NotchOverlayGeometryLogic.closedSize(
            screenNotchSize: .zero,
            fallbackNotchSize: CGSize(width: 126, height: 26),
            hasPhysicalNotch: false,
            widthOffset: 0,
            heightOffset: 0,
            configuration: .init(offsetX: 0, offsetY: 0, widthAdjustment: 14),
            constants: constants
        )

        XCTAssertEqual(size, CGSize(width: 140, height: 26))
    }

    func testClosedSizeUsesPhysicalNotchMetrics() {
        let size = NotchOverlayGeometryLogic.closedSize(
            screenNotchSize: CGSize(width: 210, height: 34),
            fallbackNotchSize: CGSize(width: 126, height: 26),
            hasPhysicalNotch: true,
            widthOffset: 10,
            heightOffset: 4,
            configuration: .init(offsetX: 0, offsetY: 0, widthAdjustment: 8),
            constants: constants
        )

        XCTAssertEqual(size.width, max(92, 210 * 0.92 + 10 + 8))
        XCTAssertEqual(size.height, max(22, 34 * 0.90 + 4))
    }

    func testPanelFrameCentersExpandedInteractionArea() {
        let frame = NotchOverlayGeometryLogic.panelFrame(
            screenFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
            hasPhysicalNotch: true,
            configuration: .init(offsetX: 12, offsetY: 8, widthAdjustment: 0),
            constants: constants
        )

        XCTAssertEqual(frame, CGRect(x: 188, y: 790, width: 1248, height: 250))
    }

    func testActivationRectExpandsPanelWhenOverlayExpanded() {
        let panelFrame = CGRect(x: 200, y: 700, width: 300, height: 100)

        let rect = NotchOverlayGeometryLogic.activationRect(
            screenFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
            panelFrame: panelFrame,
            closedSize: CGSize(width: 200, height: 40),
            hasPhysicalNotch: true,
            isExpanded: true,
            hardwareNotchRect: CGRect(x: 700, y: 960, width: 200, height: 40),
            configuration: .init(offsetX: 0, offsetY: 0, widthAdjustment: 0),
            constants: constants
        )

        XCTAssertEqual(rect, panelFrame.insetBy(dx: -54, dy: -76))
    }

    func testMouseEventsAllowedNearVirtualNotchOrOrb() {
        let configuration = NotchOverlayGeometryLogic.DisplayConfiguration(offsetX: 0, offsetY: 0, widthAdjustment: 0)
        let screenFrame = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let orbRect = CGRect(x: 760, y: 930, width: 40, height: 40)

        XCTAssertTrue(
            NotchOverlayGeometryLogic.shouldAllowMouseEvents(
                hasPhysicalNotch: false,
                isExpanded: false,
                screenFrame: screenFrame,
                cursor: CGPoint(x: 800, y: 980),
                startupOrbRect: nil,
                configuration: configuration,
                constants: constants
            )
        )

        XCTAssertTrue(
            NotchOverlayGeometryLogic.shouldAllowMouseEvents(
                hasPhysicalNotch: false,
                isExpanded: false,
                screenFrame: screenFrame,
                cursor: CGPoint(x: 770, y: 940),
                startupOrbRect: orbRect,
                configuration: configuration,
                constants: constants
            )
        )

        XCTAssertFalse(
            NotchOverlayGeometryLogic.shouldAllowMouseEvents(
                hasPhysicalNotch: true,
                isExpanded: false,
                screenFrame: screenFrame,
                cursor: CGPoint(x: 770, y: 940),
                startupOrbRect: orbRect,
                configuration: configuration,
                constants: constants
            )
        )
    }
}
