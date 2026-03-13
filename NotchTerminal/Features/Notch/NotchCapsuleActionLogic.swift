import CoreGraphics
import Foundation

enum NotchCapsuleActionLogic {
    enum CloseAllResolution: Equatable {
        case requestConfirmation(CGDirectDisplayID)
        case closeImmediately
    }

    static func resolveCloseAllAction(
        confirmBeforeCloseAll: Bool,
        ownDisplayID: CGDirectDisplayID
    ) -> CloseAllResolution {
        if confirmBeforeCloseAll {
            return .requestConfirmation(ownDisplayID)
        }
        return .closeImmediately
    }

    static func shiftedScreenIndex(
        currentIndex: Int,
        delta: Int,
        availableCount: Int
    ) -> Int? {
        let targetIndex = currentIndex + delta
        guard targetIndex >= 0, targetIndex < availableCount else { return nil }
        return targetIndex
    }
}
