# Contributing

Thanks for your interest in contributing to NotchTerminal!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/iDams/NotchTerminal.git
   cd NotchTerminal
   ```

2. Open `NotchTerminal.xcodeproj`

3. Select scheme `NotchTerminal`

4. Build and run

### Code Signing

Copy `Config/Signing.local.example.xcconfig` to `Config/Signing.local.xcconfig` and add your Apple Developer team ID.

## Pull Request Process

1. Fork the repository
2. Create a branch for your feature or fix
3. Make your changes
4. Run tests if applicable
5. Open a Pull Request

## Code Style

- Swift 6 conventions
- SwiftUI for UI, AppKit bridge for window management
- Keep changes focused and minimal

## Architecture

See [`AGENTS.md`](AGENTS.md) for project architecture and conventions.

## Questions?

Open an issue for bugs, features, or questions.
