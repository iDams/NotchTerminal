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

    // Appearance
    @AppStorage("contentPadding") var contentPadding: Double = 14
    @AppStorage("notchWidthOffset") var notchWidthOffset: Double = -80
    @AppStorage("notchHeightOffset") var notchHeightOffset: Double = -8
    @AppStorage("fakeNotchGlowEnabled") var fakeNotchGlowEnabled: Bool = false
    @AppStorage("auroraBackgroundEnabled") var auroraBackgroundEnabled: Bool = false

    // Usage
    @AppStorage("hapticFeedback") var hapticFeedback: Bool = true
    @AppStorage("showCostSummary") var showCostSummary: Bool = false

    // Compact Ticker
    @AppStorage("compactTickerEnabled") var compactTickerEnabled: Bool = true
    @AppStorage("compactTickerInterval") var compactTickerInterval: Double = 20
    @AppStorage("compactTickerClosedExtraWidth") var compactTickerClosedExtraWidth: Double = 216
    @AppStorage("compactTickerMetricMode") var compactTickerMetricMode: CompactTickerMetricMode = .percent
    @AppStorage("compactTickerPriorityMode") var compactTickerPriorityMode: CompactTickerPriorityMode = .criticalFirst
    @AppStorage("compactTickerBackgroundMode") var compactTickerBackgroundMode: CompactTickerBackgroundMode = .solid
    @AppStorage("compactTickerShowAntigravity") var compactTickerShowAntigravity: Bool = true
    @AppStorage("compactTickerShowGeminiCLI") var compactTickerShowGeminiCLI: Bool = true
    @AppStorage("compactTickerShowZia") var compactTickerShowZia: Bool = true

    // Automation
    @AppStorage("backgroundRefreshCadenceMinutes") var backgroundRefreshCadenceMinutes: Int = 5
    @AppStorage("checkProviderStatus") var checkProviderStatus: Bool = true
    @AppStorage("sessionQuotaNotificationsEnabled") var sessionQuotaNotificationsEnabled: Bool = true
    @AppStorage("autoOpenOnHover") var autoOpenOnHover: Bool = true
    @AppStorage("lockWhileTyping") var lockWhileTyping: Bool = true
    @AppStorage("preventCloseOnMouseLeave") var preventCloseOnMouseLeave: Bool = false
    @AppStorage("showChipCloseButtonOnHover") var showChipCloseButtonOnHover: Bool = true
    @AppStorage("confirmBeforeCloseAll") var confirmBeforeCloseAll: Bool = true
    @AppStorage("closeActionMode") var closeActionMode: String = "terminateProcessAndClose"

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
