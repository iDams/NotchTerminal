import Foundation

enum AIFeatureAvailability {
    static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        if defaults.object(forKey: AppPreferences.Keys.aiFeaturesEnabled) == nil {
            return AppPreferences.Defaults.aiFeaturesEnabled
        }

        return defaults.bool(forKey: AppPreferences.Keys.aiFeaturesEnabled)
    }
}
