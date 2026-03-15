# NotchTerminal

NotchTerminal is a macOS app that brings terminal workflows into the notch area.

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
- Always on Top toggle
- Dock-to-notch behavior when dragged near the notch
- Drag and drop folders/files into the terminal (inserts escaped paths)

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
- Search and filter by dev/all
- Kill process by PID from the UI

### Menu Bar Access
- Menu bar status item with quick access to:
  - `New Terminal`
  - `Storage Analysis`
  - `Show All Windows`
  - `Settings`
  - `Hide`
  - `Quit`

### Storage Analysis
- Opens from the menu bar status item
- Scans common space-heavy folders such as `node_modules`, `DerivedData`, `Pods`, `Carthage`, caches, logs, Trash, and old Downloads
- Uses a single native macOS window with category sidebar, filters, search, and bulk cleanup actions
- Warns when folders appear to still be in use before moving them to Trash

### Session Persistence
- Stores terminal sessions via SwiftData
- Restores terminal sessions on launch, including display placement, docked state, sizing, compact mode, always-on-top state, maximize state, and recent project context

### NotchAgent (Experimental)
- Dedicated `AI Control Center` window for managing providers, jobs, logs, permissions, and prompt workflows
- Scheduled AI jobs that run prompts on a timer or through macOS `launchd`
- Two execution modes:
  - **App Timer**: runs while NotchTerminal is open
  - **Machine Daemon**: installs a macOS `LaunchAgent` and runs via `launchd` even when the app is closed
- Global active provider plus optional provider override per job
- Provider API keys stored in macOS Keychain
- Built-in provider presets for OpenAI, Z.ai, OpenRouter, Gemini, Anthropic, MiniMax, Groq, DeepSeek, Qwen, Cerebras, LM Studio, Ollama, and custom OpenAI-compatible endpoints
- Z.ai supports both **Standard** and **Coding Plan** modes with different default endpoints/models
- User-friendly interval picker (`1min` to `daily`) or advanced custom cron expression
- Per-job command permissions / whitelist for local command tools
- Job logs with recent execution history, rerun actions, and prompt improvement tools
- Results displayed in the Notch overlay (if app is open) and/or macOS Notification Center
- Provider connection testing, model fetching, and model selection from the AI workspace
- **Connected Apps**: attach the built-in terminal or installed macOS apps to jobs
  - Drag & drop app tokens into prompts (`@notch-terminal`, `@app:com.apple.Safari`)
  - Visual prompt helpers for common actions like "Capture the app window"
  - Automated macOS app control (open, activate, type text, press keys)
  - Automatic screenshot capture for AI visual verification of app UI
  - Final screenshot verification guard prevents AI from guessing results
  - Character-by-character typing for reliable input in apps like Calculator
- **AI Vision**: jobs can capture and inspect app windows with screenshots
  - `capture_app_window` tool for visual verification of connected apps
  - Auto-capture after UI actions when prompt requires visual verification
  - Base64 PNG screenshots embedded in AI message context
  - Fails job with clear error if required screenshot cannot be captured

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

### Debug App Install Flow for macOS Permissions

macOS privacy permissions such as `Accessibility` are more reliable when the app lives at a stable path instead of running directly from Xcode's transient `DerivedData` bundle.

For that reason, Debug builds now install a stable development copy automatically to:

- `/Applications/NotchTerminal Dev.app`

Current Debug workflow:

1. Build from Xcode as usual
2. The target reinstalls `NotchTerminal Dev.app` automatically
3. If it was already running, the old dev copy is closed first
4. Use `NotchTerminal Dev.app` when testing permissions like `Accessibility`

Why this exists:

- TCC / macOS privacy permissions can behave inconsistently for ephemeral app bundles in `DerivedData`
- A stable app path makes permission prompts and stored approvals much more predictable
- This keeps the development loop inside Xcode while avoiding manual copy steps

## Permissions

NotchTerminal can request these macOS permissions depending on enabled features:

- `Notifications`
  - Used for AI job results and alerts
- `Accessibility`
  - Required for automating installed macOS apps and typing/keypress actions
- `Screen Recording`
  - Required for app window capture and AI visual verification

The app includes an initial permission onboarding flow and a permissions section in Settings to review or request access later.

## Settings Overview

- `General`
  - Language: system default or manual override (`en`, `es`, `fr`, `ja`)
  - Haptics
  - Dock icon toggle
  - Show Experimental tab
  - Hover/open behavior and delay
  - Keep open while typing
  - Permissions status and request actions for Notifications, Accessibility, and Screen Recording
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

## AI Control Center

- Experimental AI workspace opened from the notch overlay
- Provider management with Keychain-backed API keys
- Global default provider plus optional per-job override
- Job editor with scheduling, permissions, connected apps, installed apps, and prompt helpers
- App Timer and Machine Daemon execution modes
- Job logs, rerun actions, and prompt improvement
- Connection testing and model discovery for compatible providers

## Project Structure

- `NotchTerminal/App` app lifecycle
- `NotchTerminal/Features/Notch` overlay UI, interactions, notch actions, and AI entry points
- `NotchTerminal/Features/AI` AI Control Center, app automation, permissions, and connected-app workflows
- `NotchTerminal/Features/Storage` storage scanning, cleanup actions, and overview UI
- `NotchTerminal/Features/Windows` floating window manager, terminal integration, ports UI, and session/window logic
- `NotchTerminal/Features/Persistence` SwiftData models and session restore helpers
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
