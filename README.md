# NotchTerminal

NotchTerminal is a macOS app that puts a terminal workflow in the notch area.

It combines:
- A top notch overlay (real notch and no-notch screens)
- Floating terminal windows
- Quick terminal actions (restore/minimize/close)
- Metal-based visual effects

## What It Does

### Notch Overlay
- Expands on hover
- Works on multi-display setups
- Shows minimized terminal chips
- Opens quick actions:
  - `New`
  - `Reorg`
  - `Bulk` (`Restore All`, `Minimize All`, `Close All`, `Close All on This Display`)
  - `Settings`

### Terminal Windows
- Open/close/minimize/maximize
- Compact mode
- Always-on-top toggle
- Dock-to-notch behavior when dragged near the notch
- Drag and drop folders/files into terminal (inserts escaped path)

### Terminal Actions
- Context menu includes:
  - `Copy`
  - `Paste`
  - `Select All`
  - `Clear Buffer`
  - `Search` (sends Ctrl+R)
  - `Close` (sends `exit`)
- Keyboard shortcuts:
  - `⌘C`, `⌘V`, `⌘A`
  - `⌘K` clear
  - `⌘F` search
  - `⌘W` close session
  - `⌘+` / `⌘-` font size

### Open Ports Panel
- Lists listening TCP ports
- Search/filter by dev/all
- Kill process by PID from the UI

### Session + Persistence
- Stores terminal sessions via SwiftData
- Restores sessions on launch (work in progress)

## Requirements

- macOS 14+
- Xcode 16+ (for development)

Runtime note:
- The app defaults to `/bin/zsh`, which is available on a clean macOS install.

## Build and Run

1. Open `NotchTerminal.xcodeproj`
2. Select scheme `NotchTerminal`
3. Build and run

## Settings Overview

- `General`
  - Dock icon toggle
  - Haptics
  - Hover/open behavior
  - Close confirmation behavior
- `Appearance`
  - Notch geometry offsets
  - Docking sensitivity
  - Effects toggles
- `About`
  - Version/info links
  - Third-party notices
- `Experimental`
  - Work-in-progress options

## Project Structure

- `NotchTerminal/App` app lifecycle
- `NotchTerminal/Features/Notch` overlay + notch UI
- `NotchTerminal/Features/Windows` floating window manager + terminal integration
- `NotchTerminal/Features/Persistence` SwiftData models
- `NotchTerminal/Rendering/Metal` Metal shaders/renderers
- `NotchTerminal/Settings` settings screens
- `NotchTerminal/Services` helpers/services
- `NotchTerminal/Assets.xcassets` icons/images

## Credits

See `NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`.

Main attributions:
- SwiftTerm (terminal emulation, MIT)
- Port-Killer inspiration for open-port workflow (MIT)

Brand marks/logos used in UI belong to their respective owners and are used for identification only.

## License

MIT. See `LICENSE`.
