# NotchTerminal

NotchTerminal is a macOS notch-first terminal utility built with SwiftUI, AppKit, Metal, and SwiftTerm.

It provides a Dynamic-Island-style top overlay, quick terminal windows, minimized window previews, and configurable behavior for notch and non-notch displays.

## Current Features

- Notch overlay UI (physical notch and fake notch support)
- Hover-to-expand notch behavior
- Optional keep-open while typing
- Minimized terminal window chips with hover preview popovers
- Quick actions from notch:
  - New terminal window
  - Reorganize visible windows
  - Restore minimized windows
- Floating terminal windows with:
  - Minimize / close / maximize
  - Compact mode
  - Always-on-top toggle
  - Terminal font size controls (`⌘+` / `⌘-`)
- Animated Metal visual effects:
  - Notch background shader
  - Detached notification-style orb effect
  - Black window subtle animated background
- Appearance controls:
  - Content padding
  - Notch width/height fine-tune
  - Optional fake-notch glow
  - Compact ticker options
- App icon and image assets migrated to `Assets.xcassets`
- Optional Dock icon toggle (`Show Dock icon`)

## Requirements

- macOS 14+
- Xcode 16+

## Build and Run

1. Open `NotchTerminal.xcodeproj`
2. Select the `NotchTerminal` scheme
3. Build and Run

## Settings

Open the app Settings to configure:

- System
  - Haptic feedback
  - Show Dock icon
- Automation
  - Open notch on hover
  - Keep open while typing
- Appearance
  - Geometry tuning
  - Compact ticker behavior
  - Fake notch glow

## Project Structure

- `NotchTerminal/App` app entry and lifecycle
- `NotchTerminal/Features/Notch` notch overlay UI and behavior
- `NotchTerminal/Features/Windows` terminal window manager and terminal container
- `NotchTerminal/Rendering/Metal` Metal renderers and shaders
- `NotchTerminal/Services` app services (branding, etc.)
- `NotchTerminal/Extensions` framework extensions
- `NotchTerminal/Settings` settings UI
- `NotchTerminal/Assets.xcassets` app and UI image assets

## Credits and Third-Party

### SwiftTerm

This project uses SwiftTerm for terminal emulation and local PTY process integration.

- Upstream: https://github.com/migueldeicaza/SwiftTerm
- Fork used by this project: https://github.com/iDams/SwiftTerm
- License: MIT (see upstream repository license file)

### Port-Killer (Inspiration)

The open-ports panel and process-termination flow were inspired by Port-Killer, and part of the port scanning/kill logic approach was adapted for this project.

- Project: https://github.com/productdevbook/port-killer
- License: MIT

### Brand Assets

Some command branding icons correspond to third-party products (for example, Claude/OpenCode logos).

- These marks and logos are property of their respective owners.
- They are used here only for UI identification.
- This project is not affiliated with or endorsed by those brands.

### Notices

See `THIRD_PARTY_NOTICES.md` for attribution notes.
