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
- `NotchTerminal/Features/Notch`: notch overlay UI, interaction model, and entry points for overlay actions.
- `NotchTerminal/Features/AI`: AI Control Center, provider management, app automation, permissions, and connected-app workflows.
- `NotchTerminal/Features/Storage`: storage analysis, cleanup actions, and overview UI.
- `NotchTerminal/Features/Windows`: floating terminal windows and actions.
- `NotchTerminal/Features/Persistence`: SwiftData models and session restore helpers.
- `NotchTerminal/Rendering/Metal`: Metal shaders/rendering pipeline (Aurora, Fake Glow, CRT).
- `NotchTerminal/Settings`: settings screens and custom NotchTerminal UI components.
- `NotchTerminal/Services`: shared services/utilities.
- `vendor/SwiftTerm`: vendored terminal emulation library.

## Behavior Expectations
- Keep notch interactions fast and non-blocking.
- Preserve multi-display behavior.
- Avoid regressions in terminal session lifecycle (open/minimize/restore/close).
- Keep destructive actions confirmable when settings require it.
- Preserve AI job behavior, especially provider selection, job scheduling, permissions, and connected-app automation flows.
- Treat macOS permission flows carefully: Notifications, Accessibility, and Screen Recording are all used by AI-related features.

## Localization
- Primary strings: `NotchTerminal/*/*.strings` and `*.lproj/Localizable.strings`.
- Existing languages include `en`, `es`, `fr`, `ja`.
- See `docs/localization/LOCALIZATION.md` for language system details.

## Safe Change Guidelines
- Prefer focused, minimal patches.
- Do not commit secrets, keys, tokens, or private notes.
- Do not commit personal Xcode signing settings such as `DEVELOPMENT_TEAM`; use `Config/Signing.local.xcconfig` for local-only signing overrides.
- Do not add personal planning docs to version control.
- Keep user-facing copy localized where appropriate.
- For UI/state changes, validate behavior in both notch and non-notch screens.

## Testing Policy
- Run relevant tests before changing code when there is any chance the base is already failing.
- Run tests immediately after each meaningful code change.
- Do not consider a task complete without running the affected tests, or clearly stating why they could not be run.
- If new logic is added or refactored, add or update tests in the same task unless that is genuinely blocked.
- For changes in preferences, command classification, ports, paths, sessions, or restore logic, run the full `NotchTerminal` test suite.
- For changes in AI providers, AI jobs, app automation, permission handling, or connected-app capture flows, run `build-for-testing` and the affected tests; if coverage is missing, state that clearly.
- For UI or AppKit changes, at minimum run `build-for-testing` and the affected unit tests.
- For UI test infrastructure changes, run `build-for-testing` and document separately if runtime UI execution is blocked by the local Xcode environment.

## Useful References
- Product overview: `README.md`
- AI vision and Connected Apps: `docs/ai/VISION.md`
- Testing guidance: `docs/quality/TESTING.md`
- Localization details: `docs/localization/LOCALIZATION.md`
- Third-party attributions: `NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`
