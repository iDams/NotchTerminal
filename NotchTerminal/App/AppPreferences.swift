import Foundation
import CoreGraphics

/// Centralizes persisted settings and converts raw `UserDefaults` values into
/// typed configuration objects used by views and controllers.
enum AppPreferences {
    struct NotchDisplayConfiguration: Equatable {
        let isEnabled: Bool
        let offsetX: Double
        let offsetY: Double
        let widthAdjustment: Double
    }

    struct AuroraDisplayConfiguration: Equatable {
        let usesCustomOverride: Bool
        let backgroundEnabled: Bool
        let theme: String
    }

    struct TerminalActionConfiguration: Equatable {
        let showChipCloseButtonOnHover: Bool
        let confirmBeforeCloseAll: Bool
        let closeActionMode: String
    }

    struct ExperimentalFeatureConfiguration: Equatable {
        let dragToNotchEnabled: Bool
        let startupOrbEnabled: Bool
        let notchDockingSensitivity: Double
        let projectStatusCardEnabled: Bool
        let projectStatusShowGit: Bool
        let projectStatusShowFolder: Bool
    }

    enum Keys {
        static let disabledNotchDisplayIDs = "disabledNotchDisplayIDs"
        static let notchDisplayOffsetX = "notchDisplayOffsetX"
        static let notchDisplayOffsetY = "notchDisplayOffsetY"
        static let notchDisplayWidthAdjustment = "notchDisplayWidthAdjustment"
        static let auroraDisplayOverrideIDs = "auroraDisplayOverrideIDs"
        static let auroraDisplayEnabledMap = "auroraDisplayEnabledMap"
        static let auroraDisplayThemeMap = "auroraDisplayThemeMap"
        static let contentPadding = "contentPadding"
        static let notchWidthOffset = "notchWidthOffset"
        static let notchHeightOffset = "notchHeightOffset"
        static let fakeNotchGlowEnabled = "fakeNotchGlowEnabled"
        static let fakeNotchGlowTheme = "fakeNotchGlowTheme"
        static let auroraBackgroundEnabled = "auroraBackgroundEnabled"
        static let auroraTheme = "auroraTheme"
        static let showExperimentalSettings = "showExperimentalSettings"
        static let hapticFeedback = "hapticFeedback"
        static let showDockIcon = "showDockIcon"
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
        static let experimentalDragToNotchEnabled = "experimentalDragToNotchEnabled"
        static let experimentalStartupOrbEnabled = "experimentalStartupOrbEnabled"
        static let startupOrbPillOffsetX = "startupOrbPillOffsetX"
        static let startupOrbPillOffsetY = "startupOrbPillOffsetY"
        static let startupOrbNotchOffsetX = "startupOrbNotchOffsetX"
        static let startupOrbNotchOffsetY = "startupOrbNotchOffsetY"
        static let enableCRTFilter = "enableCRTFilter"
        static let experimentalProjectStatusCardEnabled = "experimentalProjectStatusCardEnabled"
        static let experimentalProjectStatusShowGit = "experimentalProjectStatusShowGit"
        static let experimentalProjectStatusShowFolder = "experimentalProjectStatusShowFolder"
    }

    enum Defaults {
        static let contentPadding: Double = 30
        static let notchWidthOffset: Double = -80
        static let notchHeightOffset: Double = -8
        static let fakeNotchGlowEnabled = false
        static let auroraBackgroundEnabled = false
        static let showExperimentalSettings = false
        static let hapticFeedback = true
        static let showDockIcon = false
        static let autoOpenOnHover = true
        static let autoOpenOnHoverDelay: Double = 0.5
        static let lockWhileTyping = true
        static let preventCloseOnMouseLeave = false
        static let showChipCloseButtonOnHover = true
        static let confirmBeforeCloseAll = true
        static let closeActionMode = "terminateProcessAndClose"
        static let terminalDefaultWidth: Double = 740
        static let terminalDefaultHeight: Double = 480
        static let notchDockingSensitivity: Double = 80
        static let experimentalDragToNotchEnabled = false
        static let experimentalStartupOrbEnabled = false
        static let startupOrbPillOffsetX: Double = 20
        static let startupOrbPillOffsetY: Double = 0
        static let startupOrbNotchOffsetX: Double = 9
        static let startupOrbNotchOffsetY: Double = 4
        static let enableCRTFilter = false
        static let experimentalProjectStatusCardEnabled = false
        static let experimentalProjectStatusShowGit = true
        static let experimentalProjectStatusShowFolder = true
    }

    /// Disabled displays are stored as a stable comma-separated list so the
    /// value round-trips predictably across launches and tests.
    static func disabledNotchDisplayIDs(in defaults: UserDefaults = .standard) -> Set<CGDirectDisplayID> {
        guard let rawValue = defaults.string(forKey: Keys.disabledNotchDisplayIDs),
              !rawValue.isEmpty else {
            return []
        }

        return Set(
            rawValue
                .split(separator: ",")
                .compactMap { UInt32($0) }
                .map { CGDirectDisplayID($0) }
        )
    }

    static func isNotchEnabled(for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) -> Bool {
        !disabledNotchDisplayIDs(in: defaults).contains(displayID)
    }

    static func setNotchEnabled(_ isEnabled: Bool, for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) {
        var disabledIDs = disabledNotchDisplayIDs(in: defaults)
        if isEnabled {
            disabledIDs.remove(displayID)
        } else {
            disabledIDs.insert(displayID)
        }

        let rawValue = disabledIDs
            .map { String($0) }
            .sorted()
            .joined(separator: ",")
        defaults.set(rawValue, forKey: Keys.disabledNotchDisplayIDs)
    }

    static func notchConfiguration(for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) -> NotchDisplayConfiguration {
        NotchDisplayConfiguration(
            isEnabled: isNotchEnabled(for: displayID, in: defaults),
            offsetX: notchOffsetX(for: displayID, in: defaults),
            offsetY: notchOffsetY(for: displayID, in: defaults),
            widthAdjustment: notchWidthAdjustment(for: displayID, in: defaults)
        )
    }

    static func notchOffsetX(for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) -> Double {
        perDisplayDouble(for: displayID, key: Keys.notchDisplayOffsetX, in: defaults)
    }

    static func setNotchOffsetX(_ value: Double, for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) {
        setPerDisplayDouble(value, for: displayID, key: Keys.notchDisplayOffsetX, in: defaults)
    }

    static func notchOffsetY(for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) -> Double {
        perDisplayDouble(for: displayID, key: Keys.notchDisplayOffsetY, in: defaults)
    }

    static func setNotchOffsetY(_ value: Double, for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) {
        setPerDisplayDouble(value, for: displayID, key: Keys.notchDisplayOffsetY, in: defaults)
    }

    static func notchWidthAdjustment(for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) -> Double {
        perDisplayDouble(for: displayID, key: Keys.notchDisplayWidthAdjustment, in: defaults)
    }

    static func setNotchWidthAdjustment(_ value: Double, for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) {
        setPerDisplayDouble(value, for: displayID, key: Keys.notchDisplayWidthAdjustment, in: defaults)
    }

    static func hasCustomAuroraOverride(for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) -> Bool {
        customAuroraOverrideDisplayIDs(in: defaults).contains(displayID)
    }

    static func setCustomAuroraOverrideEnabled(_ isEnabled: Bool, for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) {
        var overrideIDs = customAuroraOverrideDisplayIDs(in: defaults)
        if isEnabled {
            overrideIDs.insert(displayID)
        } else {
            // Clearing the override also drops per-display values so the screen
            // cleanly falls back to the shared global appearance again.
            overrideIDs.remove(displayID)
            var enabledMap = perDisplayBoolMap(forKey: Keys.auroraDisplayEnabledMap, in: defaults)
            enabledMap.removeValue(forKey: String(displayID))
            defaults.set(enabledMap, forKey: Keys.auroraDisplayEnabledMap)
            var themeMap = perDisplayStringMap(forKey: Keys.auroraDisplayThemeMap, in: defaults)
            themeMap.removeValue(forKey: String(displayID))
            defaults.set(themeMap, forKey: Keys.auroraDisplayThemeMap)
        }

        let rawValue = overrideIDs.map { String($0) }.sorted().joined(separator: ",")
        defaults.set(rawValue, forKey: Keys.auroraDisplayOverrideIDs)
    }

    static func auroraBackgroundEnabled(
        for displayID: CGDirectDisplayID,
        fallback: Bool,
        in defaults: UserDefaults = .standard
    ) -> Bool {
        guard hasCustomAuroraOverride(for: displayID, in: defaults) else { return fallback }
        return perDisplayBoolMap(forKey: Keys.auroraDisplayEnabledMap, in: defaults)[String(displayID)] ?? fallback
    }

    static func setAuroraBackgroundEnabled(_ isEnabled: Bool, for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) {
        var map = perDisplayBoolMap(forKey: Keys.auroraDisplayEnabledMap, in: defaults)
        map[String(displayID)] = isEnabled
        defaults.set(map, forKey: Keys.auroraDisplayEnabledMap)
    }

    static func auroraTheme(
        for displayID: CGDirectDisplayID,
        fallback: String,
        in defaults: UserDefaults = .standard
    ) -> String {
        guard hasCustomAuroraOverride(for: displayID, in: defaults) else { return fallback }
        return perDisplayStringMap(forKey: Keys.auroraDisplayThemeMap, in: defaults)[String(displayID)] ?? fallback
    }

    static func setAuroraTheme(_ rawValue: String, for displayID: CGDirectDisplayID, in defaults: UserDefaults = .standard) {
        var map = perDisplayStringMap(forKey: Keys.auroraDisplayThemeMap, in: defaults)
        map[String(displayID)] = rawValue
        defaults.set(map, forKey: Keys.auroraDisplayThemeMap)
    }

    static func auroraConfiguration(
        for displayID: CGDirectDisplayID,
        fallbackEnabled: Bool,
        fallbackTheme: String,
        in defaults: UserDefaults = .standard
    ) -> AuroraDisplayConfiguration {
        AuroraDisplayConfiguration(
            usesCustomOverride: hasCustomAuroraOverride(for: displayID, in: defaults),
            backgroundEnabled: auroraBackgroundEnabled(
                for: displayID,
                fallback: fallbackEnabled,
                in: defaults
            ),
            theme: auroraTheme(
                for: displayID,
                fallback: fallbackTheme,
                in: defaults
            )
        )
    }

    static func terminalActionConfiguration(in defaults: UserDefaults = .standard) -> TerminalActionConfiguration {
        TerminalActionConfiguration(
            showChipCloseButtonOnHover: bool(
                forKey: Keys.showChipCloseButtonOnHover,
                default: Defaults.showChipCloseButtonOnHover,
                in: defaults
            ),
            confirmBeforeCloseAll: bool(
                forKey: Keys.confirmBeforeCloseAll,
                default: Defaults.confirmBeforeCloseAll,
                in: defaults
            ),
            closeActionMode: string(
                forKey: Keys.closeActionMode,
                default: Defaults.closeActionMode,
                in: defaults
            )
        )
    }

    static func experimentalFeatureConfiguration(in defaults: UserDefaults = .standard) -> ExperimentalFeatureConfiguration {
        ExperimentalFeatureConfiguration(
            dragToNotchEnabled: bool(
                forKey: Keys.experimentalDragToNotchEnabled,
                default: Defaults.experimentalDragToNotchEnabled,
                in: defaults
            ),
            startupOrbEnabled: bool(
                forKey: Keys.experimentalStartupOrbEnabled,
                default: Defaults.experimentalStartupOrbEnabled,
                in: defaults
            ),
            notchDockingSensitivity: double(
                forKey: Keys.notchDockingSensitivity,
                default: Defaults.notchDockingSensitivity,
                in: defaults
            ),
            projectStatusCardEnabled: bool(
                forKey: Keys.experimentalProjectStatusCardEnabled,
                default: Defaults.experimentalProjectStatusCardEnabled,
                in: defaults
            ),
            projectStatusShowGit: bool(
                forKey: Keys.experimentalProjectStatusShowGit,
                default: Defaults.experimentalProjectStatusShowGit,
                in: defaults
            ),
            projectStatusShowFolder: bool(
                forKey: Keys.experimentalProjectStatusShowFolder,
                default: Defaults.experimentalProjectStatusShowFolder,
                in: defaults
            )
        )
    }

    static func setConfirmBeforeCloseAll(_ isEnabled: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: Keys.confirmBeforeCloseAll)
    }

    private static func perDisplayDouble(for displayID: CGDirectDisplayID, key: String, in defaults: UserDefaults) -> Double {
        let map = perDisplayDoubleMap(forKey: key, in: defaults)
        return map[String(displayID)] ?? 0
    }

    private static func bool(forKey key: String, default defaultValue: Bool, in defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private static func double(forKey key: String, default defaultValue: Double, in defaults: UserDefaults) -> Double {
        guard let value = defaults.object(forKey: key) else { return defaultValue }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let doubleValue = value as? Double {
            return doubleValue
        }
        return defaultValue
    }

    private static func string(forKey key: String, default defaultValue: String, in defaults: UserDefaults) -> String {
        defaults.string(forKey: key) ?? defaultValue
    }

    private static func setPerDisplayDouble(_ value: Double, for displayID: CGDirectDisplayID, key: String, in defaults: UserDefaults) {
        var map = perDisplayDoubleMap(forKey: key, in: defaults)
        let storageKey = String(displayID)
        if abs(value) < 0.0001 {
            map.removeValue(forKey: storageKey)
        } else {
            map[storageKey] = value
        }
        defaults.set(map, forKey: key)
    }

    private static func perDisplayDoubleMap(forKey key: String, in defaults: UserDefaults) -> [String: Double] {
        guard let dictionary = defaults.dictionary(forKey: key) else { return [:] }
        return dictionary.reduce(into: [String: Double]()) { partialResult, entry in
            if let number = entry.value as? NSNumber {
                partialResult[entry.key] = number.doubleValue
            } else if let doubleValue = entry.value as? Double {
                partialResult[entry.key] = doubleValue
            }
        }
    }

    private static func customAuroraOverrideDisplayIDs(in defaults: UserDefaults) -> Set<CGDirectDisplayID> {
        guard let rawValue = defaults.string(forKey: Keys.auroraDisplayOverrideIDs),
              !rawValue.isEmpty else {
            return []
        }

        return Set(
            rawValue
                .split(separator: ",")
                .compactMap { UInt32($0) }
                .map { CGDirectDisplayID($0) }
        )
    }

    private static func perDisplayBoolMap(forKey key: String, in defaults: UserDefaults) -> [String: Bool] {
        guard let dictionary = defaults.dictionary(forKey: key) else { return [:] }
        return dictionary.reduce(into: [String: Bool]()) { partialResult, entry in
            if let number = entry.value as? NSNumber {
                partialResult[entry.key] = number.boolValue
            } else if let boolValue = entry.value as? Bool {
                partialResult[entry.key] = boolValue
            }
        }
    }

    private static func perDisplayStringMap(forKey key: String, in defaults: UserDefaults) -> [String: String] {
        guard let dictionary = defaults.dictionary(forKey: key) else { return [:] }
        return dictionary.reduce(into: [String: String]()) { partialResult, entry in
            if let stringValue = entry.value as? String {
                partialResult[entry.key] = stringValue
            }
        }
    }
}
