# NotchTerminal

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue.svg)]()
[![Version](https://img.shields.io/badge/Version-1.2.1-green.svg)]()

**English** | [**Español**](README.es.md) | [**日本語**](README.ja.md) | [**简体中文**](README.zh-Hans.md) | [**Français**](README.fr.md)

<p align="center">
  <img src="docs/hero.png" alt="NotchTerminal" width="720" />
</p>

A drop-down terminal for macOS that lives in your notch. Fast, always accessible, and stays out of your way.

---

## Demo

https://github.com/user-attachments/assets/bfe05d72-96fe-45c9-a9d1-94521a5d3023

https://github.com/user-attachments/assets/4b07bcd6-1c13-4916-bbe0-b65342c73f78

---

## Features

- **Notch Integration:** Hover to expand. Works on all Macs (even those without a physical notch) and across multiple displays.
- **Menu Bar Access:** A menu bar item is available for quick access to core functions and settings.
- **Session Management:** SwiftData persistence automatically restores your window positions, sizes, and states across launches.
- **Window Management:** Compact mode, always-on-top, and a drag-and-drop system that supports paths.
- **Built-in Tools:**
  - *Active Ports:* View listening TCP ports and kill processes directly.
  - *Storage Analyzer:* Quickly scan and clean up `node_modules`, `DerivedData`, caches, and logs.

### Experimental Features
NotchTerminal includes an experimental settings tab featuring:
- **CRT Filter:** A retro CRT terminal overlay using Metal shaders.
- **Fake Notch Glow:** Simulates a glowing ambient light coming from the notch (Cyberpunk theme, etc).
- **Startup Orb:** A visual indicator during app launch.
- **Drag-to-Dock:** Adjust the magnetic sensitivity when dragging terminal windows near the notch.

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘C` / `⌘V` / `⌘A` | Copy / Paste / Select All |
| `⌘K` | Clear buffer |
| `⌘F` | Search |
| `⌘W` | Close session |
| `⌘+` / `⌘-` | Adjust font size |

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/screenshot1.png" width="720" />
</p>

<p align="center">
  <img src="docs/screenshots/screenshot2.png" width="720" />
</p>

---

## Requirements

- macOS 14+
- Xcode 16+ (to build from source)

---

## Installation

### Homebrew

```bash
brew tap idams/notchterminal
brew install --cask notchterminal
```

### Direct Download

1. Open the latest release on GitHub.
2. Download `NotchTerminal-<version>.zip`.
3. Unzip the file.
4. Move `NotchTerminal.app` to `/Applications`.

Releases:

- https://github.com/iDams/NotchTerminal/releases

---

## Build from Source

```bash
git clone https://github.com/iDams/NotchTerminal.git
cd NotchTerminal
```
Open `NotchTerminal.xcodeproj` and run the `NotchTerminal` scheme.

**Local Code Signing:**
The repository does not include a personal Apple `DEVELOPMENT_TEAM`. To build locally:
1. Copy `Config/Signing.local.example.xcconfig` to `Config/Signing.local.xcconfig`
2. Add your Apple Developer team ID.
3. Keep this file local (it's in `.gitignore`).

---

## Documentation & Links

- [Documentation Index](docs/README.md)
- [Testing Guide](docs/quality/)
- [Localization](docs/localization/LOCALIZATION.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Third-Party Notices](NotchTerminal/Resources/THIRD_PARTY_NOTICES.md)

---

## Support

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-donate-yellow.svg)](https://buymeacoffee.com/marcoastorj)

<p align="center">
  <img src="docs/bmc_qr.png" alt="Buy Me a Coffee QR" width="200" />
</p>

---

## Brand Notice

Some screenshots, icons, and references may mention third-party tools or services such as OpenAI, Claude, Copilot, or similar products to show workflows or interoperability.

Those names, logos, and marks belong to their respective owners. They are used only for identification and descriptive reference inside the app, website, documentation, or promotional visuals. NotchTerminal is not affiliated with, endorsed by, or sponsored by those companies unless explicitly stated otherwise.

---

## License

[MIT](LICENSE) © 2026 Marco Astorga González
