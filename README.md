# NotchTerminal

NotchTerminal is a macOS app that puts a terminal workflow in the notch area.

<p align="center">
  <img src="docs/logo.png" alt="NotchTerminal Logo" width="160" />
</p>

## Screenshots

![Claude and Gemini terminals in NotchTerminal](docs/screenshots/claude-gemini.png)

![About settings screen](docs/screenshots/about-settings.png)

![Per-display notch settings](docs/screenshots/notch-settings.png)

It combines:
- A top notch overlay (real notch and no-notch screens)
- Floating terminal windows
- Quick terminal actions (restore/minimize/close)
- Advanced Metal-based visual effects (Aurora background, CRT filter, Fake Notch glow)

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

### Storage Analysis
- Opens from the menu bar status item
- Scans common space-heavy folders such as `node_modules`, `DerivedData`, `Pods`, `Carthage`, caches, logs, Trash, and old Downloads
- Uses a single native macOS window with category sidebar, filters, search, and bulk cleanup actions
- Warns when folders appear to still be in use before moving them to Trash

### Session + Persistence
- Stores terminal sessions via SwiftData
- Restores sessions on launch (work in progress)

### NotchAgent (Experimental)
- Scheduled AI cronjobs that run prompts on a timer or via macOS `launchd`
- Two execution modes:
  - **App Timer**: runs while NotchTerminal is open
  - **Machine Daemon**: runs via native macOS `launchd`, even when the app is closed
- User-friendly interval picker (1min–daily) or advanced custom cron expression
- Results displayed in the Notch overlay (if app is open) and/or macOS Notification Center
- Supports OpenAI, OpenRouter (free), and custom API endpoints

## Requirements

- macOS 14+
- Xcode 16+ (for development)

Runtime note:
- The app defaults to `/bin/zsh`, which is available on a clean macOS install.

## Build and Run

1. Open `NotchTerminal.xcodeproj`
2. Select scheme `NotchTerminal`
3. Build and run

### Local Code Signing for Contributors

This repository does not commit a personal Apple `DEVELOPMENT_TEAM`.

If you need local signing to run or archive the app:

1. Copy `Config/Signing.local.example.xcconfig` to `Config/Signing.local.xcconfig`
2. Replace `YOURTEAMID` with your own Apple Developer team ID
3. Keep `Config/Signing.local.xcconfig` local only

The shared `Config/Signing.xcconfig` includes that file optionally, so collaborators can sign locally without rewriting shared project settings.

## Settings Overview

- `General`
  - Language: system default or manual override (`en`, `es`, `fr`, `ja`)
  - Haptics
  - Dock icon toggle
  - Show Experimental tab
  - Hover/open behavior and delay
  - Keep open while typing
  - Chip close button on hover
  - Close confirmation behavior
  - Close action mode (`Close window only` / `Terminate process and close`)
  - Quit app action
- `Notch`
  - Per-display notch enable/disable
  - Per-display X/Y offset and width adjustment
  - Per-display custom Aurora background override
- `Appearance`
  - Content padding
  - Default terminal width/height
  - Global Aurora background and theme
- `About`
- `Experimental`
  - Hidden by default behind `Show Experimental tab`
  - Drag to Notch and docking sensitivity
  - Startup Orb and its offset tuning
  - Project Status Card (contextual details like Folder Name and Git Status in the Notch)
  - Fake Notch Glow and theme
  - CRT Filter
  - Hit-test debug overlay
  - Extra notch geometry offsets for physical-notch displays
- `NotchAgent`
  - Experimental tab for scheduled AI background tasks
  - Global AI provider configuration (OpenAI / OpenRouter / Custom)
  - Cronjob list with enable/disable, test, edit, and delete
  - Per-job execution mode (App Timer or Machine Daemon)
  - Interval picker or advanced cron expression

## Project Structure

- `NotchTerminal/App` app lifecycle
- `NotchTerminal/Features/Notch` overlay + notch UI
- `NotchTerminal/Features/Storage` storage scanning, cleanup actions, and overview UI
- `NotchTerminal/Features/Windows` floating window manager + terminal integration
- `NotchTerminal/Features/Persistence` SwiftData models
- `NotchTerminal/Rendering/Metal` Metal shaders/renderers
- `NotchTerminal/Settings` settings screens
- `NotchTerminal/Services` helpers/services
- `NotchTerminal/Assets.xcassets` icons/images

## Documentation

- Main docs index: `docs/README.md`
- Quality and testing: `docs/quality/`
- Localization docs: `docs/localization/`

## Credits

See `NotchTerminal/Resources/THIRD_PARTY_NOTICES.md`.

Main attributions:
- SwiftTerm (terminal emulation, MIT)
- Port-Killer inspiration for open-port workflow (MIT)

Brand marks/logos used in UI belong to their respective owners and are used for identification only.

## Support

If you want to support development:

- Buy Me a Coffee: https://buymeacoffee.com/marcoastorj

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="260" />
</p>

## License

MIT. See `LICENSE`.
