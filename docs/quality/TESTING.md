# TESTING.md

## Testing Policy

Use these rules when making changes in `NotchTerminal`.

- Run relevant tests before changing code if there is any chance the current branch is already broken.
- Run tests again immediately after each meaningful change.
- Do not mark work as finished without running the affected tests, or explicitly stating what could not be verified.
- If you add or refactor logic, add or update tests in the same task unless blocked by environment or architecture.

## What To Run

### Logic changes

If you change logic in any of these areas, run the full `NotchTerminal` test suite:

- preferences
- command classification
- CLI branding
- path normalization
- ports
- sessions
- restore/save behavior
- window ordering or renumbering

Recommended command:

```bash
xcodebuild -project NotchTerminal.xcodeproj -scheme NotchTerminal -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

### UI and AppKit changes

If you change SwiftUI, AppKit, Settings, or window controller behavior:

- run the affected unit tests
- run `build-for-testing` at minimum

Recommended command:

```bash
xcodebuild -project NotchTerminal.xcodeproj -scheme NotchTerminal -destination 'platform=macOS' build-for-testing CODE_SIGNING_ALLOWED=NO
```

### UI test infrastructure changes

If you change:

- `NotchTerminalUITests`
- UI test launch behavior
- accessibility identifiers
- test-only app startup logic

Then:

- run `build-for-testing`
- try running the affected UI tests
- if runtime UI execution is blocked by the local Xcode environment, document that clearly

Recommended runtime command:

```bash
xcodebuild test-without-building \
  -xctestrun /path/to/DerivedData/Build/Products/NotchTerminal_NotchTerminal_macosx*.xctestrun \
  -destination 'platform=macOS,arch=arm64,id=<YOUR-MAC-ID>' \
  -only-testing:NotchTerminalUITests
```

## Completion Standard

A task is only considered verified when one of these is true:

1. Relevant tests passed.
2. Build-for-testing passed and the remaining runtime test gap is clearly documented.
3. A specific environmental blocker prevented execution and that blocker is explicitly recorded.
