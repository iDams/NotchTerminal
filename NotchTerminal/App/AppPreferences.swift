import Foundation

enum AppPreferences {
    enum Keys {
        static let contentPadding = "contentPadding"
        static let notchWidthOffset = "notchWidthOffset"
        static let notchHeightOffset = "notchHeightOffset"
        static let fakeNotchGlowEnabled = "fakeNotchGlowEnabled"
        static let fakeNotchGlowTheme = "fakeNotchGlowTheme"
        static let auroraBackgroundEnabled = "auroraBackgroundEnabled"
        static let auroraTheme = "auroraTheme"
        static let hapticFeedback = "hapticFeedback"
        static let showDockIcon = "showDockIcon"
        static let showCostSummary = "showCostSummary"
        static let compactTickerEnabled = "compactTickerEnabled"
        static let compactTickerInterval = "compactTickerInterval"
        static let compactTickerClosedExtraWidth = "compactTickerClosedExtraWidth"
        static let compactTickerMetricMode = "compactTickerMetricMode"
        static let compactTickerPriorityMode = "compactTickerPriorityMode"
        static let compactTickerBackgroundMode = "compactTickerBackgroundMode"
        static let compactTickerShowAntigravity = "compactTickerShowAntigravity"
        static let compactTickerShowGeminiCLI = "compactTickerShowGeminiCLI"
        static let compactTickerShowZia = "compactTickerShowZia"
        static let backgroundRefreshCadenceMinutes = "backgroundRefreshCadenceMinutes"
        static let checkProviderStatus = "checkProviderStatus"
        static let sessionQuotaNotificationsEnabled = "sessionQuotaNotificationsEnabled"
        static let autoOpenOnHover = "autoOpenOnHover"
        static let autoOpenOnHoverDelay = "autoOpenOnHoverDelay"
        static let lockWhileTyping = "lockWhileTyping"
        static let preventCloseOnMouseLeave = "preventCloseOnMouseLeave"
        static let showChipCloseButtonOnHover = "showChipCloseButtonOnHover"
        static let confirmBeforeCloseAll = "confirmBeforeCloseAll"
        static let closeActionMode = "closeActionMode"
        static let terminalDefaultWidth = "terminalDefaultWidth"
        static let terminalDefaultHeight = "terminalDefaultHeight"
        static let notchDockingSensitivity = "notchDockingSensitivity"
        static let enableCRTFilter = "enableCRTFilter"
    }

    enum Defaults {
        static let contentPadding: Double = 14
        static let notchWidthOffset: Double = -80
        static let notchHeightOffset: Double = -8
        static let fakeNotchGlowEnabled = false
        static let auroraBackgroundEnabled = false
        static let hapticFeedback = true
        static let showDockIcon = false
        static let showCostSummary = false
        static let compactTickerEnabled = true
        static let compactTickerInterval: Double = 20
        static let compactTickerClosedExtraWidth: Double = 216
        static let compactTickerShowAntigravity = true
        static let compactTickerShowGeminiCLI = true
        static let compactTickerShowZia = true
        static let backgroundRefreshCadenceMinutes = 5
        static let checkProviderStatus = true
        static let sessionQuotaNotificationsEnabled = true
        static let autoOpenOnHover = true
        static let autoOpenOnHoverDelay: Double = 0.5
        static let lockWhileTyping = true
        static let preventCloseOnMouseLeave = false
        static let showChipCloseButtonOnHover = true
        static let confirmBeforeCloseAll = true
        static let closeActionMode = "terminateProcessAndClose"
        static let terminalDefaultWidth: Double = 640
        static let terminalDefaultHeight: Double = 400
        static let notchDockingSensitivity: Double = 80
        static let enableCRTFilter = false
    }
}
