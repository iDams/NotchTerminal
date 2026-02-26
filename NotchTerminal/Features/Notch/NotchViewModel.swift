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
    @AppStorage(AppPreferences.Keys.showCostSummary) var showCostSummary: Bool = AppPreferences.Defaults.showCostSummary

    // Compact Ticker
    @AppStorage(AppPreferences.Keys.compactTickerEnabled) var compactTickerEnabled: Bool = AppPreferences.Defaults.compactTickerEnabled
    @AppStorage(AppPreferences.Keys.compactTickerInterval) var compactTickerInterval: Double = AppPreferences.Defaults.compactTickerInterval
    @AppStorage(AppPreferences.Keys.compactTickerClosedExtraWidth) var compactTickerClosedExtraWidth: Double = AppPreferences.Defaults.compactTickerClosedExtraWidth
    @AppStorage(AppPreferences.Keys.compactTickerMetricMode) var compactTickerMetricMode: CompactTickerMetricMode = .percent
    @AppStorage(AppPreferences.Keys.compactTickerPriorityMode) var compactTickerPriorityMode: CompactTickerPriorityMode = .criticalFirst
    @AppStorage(AppPreferences.Keys.compactTickerBackgroundMode) var compactTickerBackgroundMode: CompactTickerBackgroundMode = .solid
    @AppStorage(AppPreferences.Keys.compactTickerShowAntigravity) var compactTickerShowAntigravity: Bool = AppPreferences.Defaults.compactTickerShowAntigravity
    @AppStorage(AppPreferences.Keys.compactTickerShowGeminiCLI) var compactTickerShowGeminiCLI: Bool = AppPreferences.Defaults.compactTickerShowGeminiCLI
    @AppStorage(AppPreferences.Keys.compactTickerShowZia) var compactTickerShowZia: Bool = AppPreferences.Defaults.compactTickerShowZia

    // Automation
    @AppStorage(AppPreferences.Keys.backgroundRefreshCadenceMinutes) var backgroundRefreshCadenceMinutes: Int = AppPreferences.Defaults.backgroundRefreshCadenceMinutes
    @AppStorage(AppPreferences.Keys.checkProviderStatus) var checkProviderStatus: Bool = AppPreferences.Defaults.checkProviderStatus
    @AppStorage(AppPreferences.Keys.sessionQuotaNotificationsEnabled) var sessionQuotaNotificationsEnabled: Bool = AppPreferences.Defaults.sessionQuotaNotificationsEnabled
    @AppStorage(AppPreferences.Keys.autoOpenOnHover) var autoOpenOnHover: Bool = AppPreferences.Defaults.autoOpenOnHover
    @AppStorage(AppPreferences.Keys.autoOpenOnHoverDelay) var autoOpenOnHoverDelay: Double = AppPreferences.Defaults.autoOpenOnHoverDelay
    @AppStorage(AppPreferences.Keys.lockWhileTyping) var lockWhileTyping: Bool = AppPreferences.Defaults.lockWhileTyping
    @AppStorage(AppPreferences.Keys.preventCloseOnMouseLeave) var preventCloseOnMouseLeave: Bool = AppPreferences.Defaults.preventCloseOnMouseLeave
    @AppStorage(AppPreferences.Keys.showChipCloseButtonOnHover) var showChipCloseButtonOnHover: Bool = AppPreferences.Defaults.showChipCloseButtonOnHover
    @AppStorage(AppPreferences.Keys.confirmBeforeCloseAll) var confirmBeforeCloseAll: Bool = AppPreferences.Defaults.confirmBeforeCloseAll
    @AppStorage(AppPreferences.Keys.closeActionMode) var closeActionMode: String = AppPreferences.Defaults.closeActionMode

    enum CompactTickerMetricMode: String, CaseIterable, Identifiable {
        case percent, dot
        var id: String { rawValue }
    }

    enum CompactTickerPriorityMode: String, CaseIterable, Identifiable {
        case criticalFirst, roundRobin
        var id: String { rawValue }
    }

    enum CompactTickerBackgroundMode: String, CaseIterable, Identifiable {
        case solid, transparent
        var id: String { rawValue }
    }

    func triggerHaptic() {
        guard hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }
}
