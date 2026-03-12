import SwiftUI

final class NotchViewModel: ObservableObject {
    @Published var isExpanded = false
    @Published var terminalItems: [TerminalWindowItem] = []
    
    // Multi-screen routing
    @Published var ownDisplayID: CGDirectDisplayID = 0
    @Published var availableScreens: [CGDirectDisplayID] = []
    @Published var activeScreenIndex: Int = 0
    var activeDisplayID: CGDirectDisplayID? {
        guard availableScreens.indices.contains(activeScreenIndex) else { return nil }
        return availableScreens[activeScreenIndex]
    }
    
    var visibleTerminalItems: [TerminalWindowItem] {
        guard let targetID = activeDisplayID else { return [] }
        return terminalItems.filter { $0.displayID == targetID }
    }
    
    @Published var contentWidth: CGFloat = 0
    @Published var closedSize: CGSize = CGSize(width: 126, height: 26)
    @Published var commandOrbEvent: TerminalCommandOrbEvent?
    @Published var activeCommandOrbEvent: TerminalCommandOrbEvent?
    
    // Tracking visibility state
    @Published var isFullScreenAppActive: Bool = false
    @Published var isSwitchingSpace: Bool = false

    @Published var isHoveringPreview = false {
        didSet {
            if isHoveringPreview {
                lastInteractionTime = Date()
                hasPreviewedDuringSession = true
            }
        }
    }
    @Published var isHoveringItem = false {
        didSet { if isHoveringItem { lastInteractionTime = Date() } }
    }
    
    var lastInteractionTime: Date = Date.distantPast
    var hasPreviewedDuringSession = false

    var hasPhysicalNotch = false
    @Published var physicalNotchHeight: CGFloat = 38

    // Appearance
    @AppStorage(AppPreferences.Keys.contentPadding) var contentPadding: Double = AppPreferences.Defaults.contentPadding
    @AppStorage(AppPreferences.Keys.notchWidthOffset) var notchWidthOffset: Double = AppPreferences.Defaults.notchWidthOffset
    @AppStorage(AppPreferences.Keys.notchHeightOffset) var notchHeightOffset: Double = AppPreferences.Defaults.notchHeightOffset
    @AppStorage(AppPreferences.Keys.fakeNotchGlowEnabled) var fakeNotchGlowEnabled: Bool = AppPreferences.Defaults.fakeNotchGlowEnabled
    @AppStorage(AppPreferences.Keys.fakeNotchGlowTheme) var fakeNotchGlowTheme: GlowTheme = .cyberpunk
    @AppStorage(AppPreferences.Keys.auroraBackgroundEnabled) var auroraBackgroundEnabled: Bool = AppPreferences.Defaults.auroraBackgroundEnabled
    
    enum GlowTheme: String, CaseIterable, Identifiable {
        case cyberpunk, neonClassic, fire, plasma, emerald
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .cyberpunk: return "Cyberpunk (Pink & Cyan)"
            case .neonClassic: return "Neon Classic (Red & Blue)"
            case .fire: return "Fire (Red & Yellow)"
            case .plasma: return "Plasma (Purple & Blue)"
            case .emerald: return "Emerald (Green & Yellow)"
            }
        }
    }
    @AppStorage(AppPreferences.Keys.auroraTheme) var auroraTheme: AuroraTheme = .classic

    enum AuroraTheme: String, CaseIterable, Identifiable {
        case classic, neon, sunset, crimson, matrix
        var id: String { rawValue }
        var localizedName: String {
            switch self {
            case .classic: return "Classic (Purple & Blue)"
            case .neon: return "Neon (Cyan & Green)"
            case .sunset: return "Sunset (Orange & Pink)"
            case .crimson: return "Crimson (Red & Dark Red)"
            case .matrix: return "Matrix (Black & Emerald)"
            }
        }
    }

    // Usage
    @AppStorage(AppPreferences.Keys.hapticFeedback) var hapticFeedback: Bool = AppPreferences.Defaults.hapticFeedback


    // Automation
    @AppStorage(AppPreferences.Keys.autoOpenOnHover) var autoOpenOnHover: Bool = AppPreferences.Defaults.autoOpenOnHover
    @AppStorage(AppPreferences.Keys.autoOpenOnHoverDelay) var autoOpenOnHoverDelay: Double = AppPreferences.Defaults.autoOpenOnHoverDelay
    @AppStorage(AppPreferences.Keys.lockWhileTyping) var lockWhileTyping: Bool = AppPreferences.Defaults.lockWhileTyping
    @AppStorage(AppPreferences.Keys.preventCloseOnMouseLeave) var preventCloseOnMouseLeave: Bool = AppPreferences.Defaults.preventCloseOnMouseLeave
    @AppStorage(AppPreferences.Keys.showChipCloseButtonOnHover) var showChipCloseButtonOnHover: Bool = AppPreferences.Defaults.showChipCloseButtonOnHover
    @AppStorage(AppPreferences.Keys.confirmBeforeCloseAll) var confirmBeforeCloseAll: Bool = AppPreferences.Defaults.confirmBeforeCloseAll
    @AppStorage(AppPreferences.Keys.closeActionMode) var closeActionMode: String = AppPreferences.Defaults.closeActionMode

    func triggerHaptic() {
        guard hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }
}
