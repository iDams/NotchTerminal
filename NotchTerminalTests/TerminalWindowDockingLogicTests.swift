import XCTest
@testable import NotchTerminal

final class TerminalWindowDockingLogicTests: XCTestCase {
    func testDockThumbnailFrameUsesNotchFrameWhenPresent() {
        let sourceFrame = CGRect(x: 100, y: 120, width: 400, height: 300)
        let notchFrame = CGRect(x: 220, y: 700, width: 160, height: 32)

        let frame = TerminalWindowDockingLogic.dockThumbnailFrame(from: sourceFrame, notchFrame: notchFrame)

        XCTAssertEqual(frame, CGRect(x: 273, y: 678, width: 54, height: 54))
    }

    func testPreviewFrameShrinksWindowAroundTopCenter() {
        let original = CGRect(x: 100, y: 200, width: 500, height: 400)

        let frame = TerminalWindowDockingLogic.previewFrame(for: original)

        XCTAssertEqual(frame, CGRect(x: 165, y: 304, width: 370, height: 296))
    }

    func testClosestTargetPrefersNearestCandidateContainingTopCenter() {
        let left = TerminalWindowDockTarget(displayID: 1, frame: CGRect(x: 0, y: 700, width: 160, height: 32))
        let right = TerminalWindowDockTarget(displayID: 2, frame: CGRect(x: 300, y: 700, width: 160, height: 32))
        let windowFrame = CGRect(x: 320, y: 480, width: 200, height: 240)

        let target = TerminalWindowDockingLogic.closestTarget(
            to: windowFrame,
            sensitivity: 80,
            candidates: [
                .init(target: left, effectiveFrame: left.frame),
                .init(target: right, effectiveFrame: right.frame)
            ]
        )

        XCTAssertEqual(target?.displayID, 2)
    }

    func testClosestTargetReturnsNilWhenNoCandidateContainsTopCenter() {
        let target = TerminalWindowDockingLogic.closestTarget(
            to: CGRect(x: 10, y: 10, width: 120, height: 120),
            sensitivity: 20,
            candidates: [
                .init(
                    target: TerminalWindowDockTarget(displayID: 1, frame: CGRect(x: 400, y: 700, width: 160, height: 32)),
                    effectiveFrame: CGRect(x: 400, y: 700, width: 160, height: 32)
                )
            ]
        )

        XCTAssertNil(target)
    }

    func testIsPillShapeDistinguishesWideAndTallFrames() {
        XCTAssertTrue(TerminalWindowDockingLogic.isPillShape(frame: CGRect(x: 0, y: 0, width: 160, height: 32)))
        XCTAssertFalse(TerminalWindowDockingLogic.isPillShape(frame: CGRect(x: 0, y: 0, width: 120, height: 100)))
    }

    func testPreviewUpdateClearsPreviewWhenFeatureDisabled() {
        let update = TerminalWindowDockingLogic.previewUpdate(
            dragToNotchEnabled: false,
            isDraggingWithMouse: true,
            now: Date(timeIntervalSince1970: 100),
            suppressionUntil: nil,
            previousTarget: TerminalWindowDockTarget(displayID: 1, frame: .zero),
            nearTarget: TerminalWindowDockTarget(displayID: 2, frame: .zero),
            previousTargetIsPill: true
        )

        XCTAssertEqual(update.hoverDisplayID, nil)
        XCTAssertFalse(update.shouldPreview)
        XCTAssertTrue(update.shouldRestorePreview)
        XCTAssertTrue(update.shouldClearPendingTarget)
        XCTAssertNil(update.suppressionUntil)
    }

    func testPreviewUpdateKeepsSuppressedStateUntilTimeoutExpires() {
        let until = Date(timeIntervalSince1970: 200)
        let update = TerminalWindowDockingLogic.previewUpdate(
            dragToNotchEnabled: true,
            isDraggingWithMouse: true,
            now: Date(timeIntervalSince1970: 150),
            suppressionUntil: until,
            previousTarget: TerminalWindowDockTarget(displayID: 1, frame: .zero),
            nearTarget: TerminalWindowDockTarget(displayID: 1, frame: .zero),
            previousTargetIsPill: true
        )

        XCTAssertEqual(update.suppressionUntil, until)
        XCTAssertFalse(update.shouldPreview)
        XCTAssertTrue(update.shouldRestorePreview)
        XCTAssertTrue(update.shouldClearPendingTarget)
    }

    func testPreviewUpdateEntersPreviewWhenNearTargetExistsDuringDrag() {
        let nearTarget = TerminalWindowDockTarget(displayID: 7, frame: .zero)

        let update = TerminalWindowDockingLogic.previewUpdate(
            dragToNotchEnabled: true,
            isDraggingWithMouse: true,
            now: Date(timeIntervalSince1970: 100),
            suppressionUntil: nil,
            previousTarget: nil,
            nearTarget: nearTarget,
            previousTargetIsPill: false
        )

        XCTAssertEqual(update.hoverDisplayID, 7)
        XCTAssertTrue(update.shouldPreview)
        XCTAssertFalse(update.shouldRestorePreview)
        XCTAssertFalse(update.shouldClearPendingTarget)
        XCTAssertNil(update.suppressionUntil)
    }

    func testPreviewUpdateStartsSuppressionWhenLeavingPillTargetWhileDragging() {
        let now = Date(timeIntervalSince1970: 300)

        let update = TerminalWindowDockingLogic.previewUpdate(
            dragToNotchEnabled: true,
            isDraggingWithMouse: true,
            now: now,
            suppressionUntil: nil,
            previousTarget: TerminalWindowDockTarget(displayID: 5, frame: .zero),
            nearTarget: nil,
            previousTargetIsPill: true
        )

        XCTAssertNil(update.hoverDisplayID)
        XCTAssertFalse(update.shouldPreview)
        XCTAssertTrue(update.shouldRestorePreview)
        XCTAssertTrue(update.shouldClearPendingTarget)
        XCTAssertEqual(update.suppressionUntil, now.addingTimeInterval(0.45))
    }

    func testDragEndResolutionMinimizesMatchedTargetOnly() {
        let resolution = TerminalWindowDockingLogic.dragEndResolution(
            dragToNotchEnabled: true,
            pendingTargets: [
                TerminalWindowDockTarget(displayID: 2, frame: .zero),
                TerminalWindowDockTarget(displayID: 7, frame: .zero)
            ],
            matchedMinimizeDisplayID: 7
        )

        XCTAssertEqual(resolution.targetToMinimize, 7)
        XCTAssertEqual(resolution.hoverDisplayIDsToClear, [7])
        XCTAssertFalse(resolution.shouldRestoreAllPreviews)
        XCTAssertFalse(resolution.shouldClearPendingTargets)
    }

    func testDragEndResolutionClearsAllWhenNoTargetMatches() {
        let resolution = TerminalWindowDockingLogic.dragEndResolution(
            dragToNotchEnabled: true,
            pendingTargets: [
                TerminalWindowDockTarget(displayID: 2, frame: .zero),
                TerminalWindowDockTarget(displayID: 7, frame: .zero)
            ],
            matchedMinimizeDisplayID: nil
        )

        XCTAssertNil(resolution.targetToMinimize)
        XCTAssertEqual(resolution.hoverDisplayIDsToClear, [2, 7])
        XCTAssertTrue(resolution.shouldRestoreAllPreviews)
        XCTAssertTrue(resolution.shouldClearPendingTargets)
    }

    func testDragEndResolutionClearsEverythingWhenFeatureDisabled() {
        let resolution = TerminalWindowDockingLogic.dragEndResolution(
            dragToNotchEnabled: false,
            pendingTargets: [TerminalWindowDockTarget(displayID: 3, frame: .zero)],
            matchedMinimizeDisplayID: 3
        )

        XCTAssertNil(resolution.targetToMinimize)
        XCTAssertEqual(resolution.hoverDisplayIDsToClear, [3])
        XCTAssertTrue(resolution.shouldRestoreAllPreviews)
        XCTAssertTrue(resolution.shouldClearPendingTargets)
    }
}
