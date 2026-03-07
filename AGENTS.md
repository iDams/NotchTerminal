# AGENTS.md

## Project Snapshot
- Name: `NotchTerminal`
- Creator: `Marco`
- Maintainer: `Marco`
- Type: native macOS app (SwiftUI + AppKit + Metal)
- Goal: control terminal windows from a notch-style overlay UI.

## Tech Stack
- Swift 6 style codebase
- SwiftUI for most UI
- AppKit bridge for window management
- SwiftData for session persistence
- Metal for visual effects
- Xcode project: `NotchTerminal.xcodeproj`

## Run / Build
1. Open `NotchTerminal.xcodeproj`
2. Select scheme `NotchTerminal`
3. Build and run on macOS

Requirements:
- macOS 14+
- Xcode 16+

## Main Architecture
- `NotchTerminal/App`: app lifecycle and preferences bootstrapping.
- `NotchTerminal/Features/Notch`: notch overlay UI + interaction model.
- `NotchTerminal/Features/Windows`: floating terminal windows and actions.
- `NotchTerminal/Features/Persistence`: SwiftData models.
- `NotchTerminal/Rendering/Metal`: Metal shaders/rendering pipeline.
- `NotchTerminal/Settings`: settings screens.
- `NotchTerminal/Services`: shared services/utilities.

## Behavior Expectations
- Keep notch interactions fast and non-blocking.
- Preserve multi-display behavior.
- Avoid regressions in terminal session lifecycle (open/minimize/restore/close).
- Keep destructive actions confirmable when settings require it.

## Localization
- Primary strings: `NotchTerminal/*/*.strings` and `*.lproj/Localizable.strings`.
- Existing languages include `en`, `es`, `fr`, `ja`.
- See `LOCALIZATION.md` for language system details.

## Safe Change Guidelines
- Prefer focused, minimal patches.
- Do not commit secrets, keys, tokens, or private notes.
- Do not commit personal Xcode signing settings such as `DEVELOPMENT_TEAM`; use `Config/Signing.local.xcconfig` for local-only signing overrides.
- Do not add personal planning docs to version control.
- Keep user-facing copy localized where appropriate.
- For UI/state changes, validate behavior in both notch and non-notch screens.

## Useful References
- Product overview: `README.md`
- Third-party attributions: `NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`
