# Localization System

NotchTerminal supports multiple languages with automatic system detection and manual override capability.

## Supported Languages

| Code | Language | Status |
|------|----------|--------|
| `en` | English | Default |
| `es` | Spanish | ✅ |
| `fr` | French | ✅ |
| `ja` | Japanese | ✅ |

## How It Works

### 1. System Language Detection

By default, NotchTerminal automatically detects the system language using:

```swift
let preferredLanguages = Locale.preferredLanguages
```

If the system language is not supported, it falls back to English (`en`).

### 2. User Override

Users can manually select their preferred language in **Settings → General → Language**:

- **System Default**: Uses the system's language setting
- **Manual Selection**: Choose from available languages (English, Spanish, French, Japanese)

The user's selection is stored in `UserDefaults` with the key `userLanguageOverride`.

## Architecture

### LanguageManager

Located in `NotchTerminal/Services/LanguageManager.swift`:

```swift
@Observable
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    var currentLanguage: String { ... }
    var systemLanguage: String { ... }
    var userHasSelectedLanguage: Bool { ... }
    
    func setLanguage(_ languageCode: String) { ... }
    func resetToSystemLanguage() { ... }
    func displayName(for languageCode: String) -> String { ... }
}
```

### Key Features

1. **Singleton Pattern**: `LanguageManager.shared` provides global access
2. **Auto-detection**: Reads from `Locale.preferredLanguages`
3. **Persistence**: User preference saved in `UserDefaults`
4. **Reactive Updates**: Uses `@Observable` for SwiftUI integration

## Adding New Languages

### 1. Update LanguageManager

Add the new language code to `supportedLanguageCodes`:

```swift
private let supportedLanguageCodes = ["en", "es", "fr", "ja", "de"] // Add "de" for German
```

### 2. Create Localization File

Create a new `.lproj` folder and `Localizable.strings` file:

```bash
mkdir NotchTerminal/NotchTerminal/de.lproj
```

### 3. Add Translations

Copy `en.lproj/Localizable.strings` and translate all keys:

```strings
/* General */
"app.name" = "NotchTerminal";
"settings.general" = "General";
/* ... */
```

## Using Localized Strings

### In SwiftUI Views

```swift
Text("settings.general".localized)
```

### In Code

```swift
let title = NSLocalizedString("settings.general", bundle: .main, value: "settings.general", comment: "")
```

### With Language Override

```swift
let title = "settings.general".localized(in: "es") // Returns Spanish version
```

## File Structure

```
NotchTerminal/
├── Services/
│   └── LanguageManager.swift     # Language detection & management
├── en.lproj/
│   └── Localizable.strings      # English (default)
├── es.lproj/
│   └── Localizable.strings      # Spanish
├── fr.lproj/
│   └── Localizable.strings      # French
├── ja.lproj/
│   └── Localizable.strings      # Japanese
└── Settings/
    └── SettingsView.swift       # Language picker UI
```

## Configuration

### UserDefaults Keys

| Key | Type | Description |
|-----|------|-------------|
| `userLanguageOverride` | String? | User-selected language code (nil = system default) |

## Notes

- Language changes take effect immediately in the Settings UI
- Some UI elements may require app restart for full effect
- The system language is read at runtime, not compile time
- Fallback to English for any missing translations
