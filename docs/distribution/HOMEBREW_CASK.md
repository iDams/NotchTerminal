# Homebrew Cask Distribution

`NotchTerminal` can be distributed through Homebrew as a notarized ZIP that contains `NotchTerminal.app`.

## Prerequisites

- Paid Apple Developer membership.
- Xcode signed in with the Apple ID for that membership.
- A valid `Developer ID Application` certificate installed in Xcode.
- `Config/Signing.local.xcconfig` present locally with your `DEVELOPMENT_TEAM`.

## Project Requirements

- `Release` enables Hardened Runtime so the app can be notarized.
- Personal signing values stay in `Config/Signing.local.xcconfig`, which is ignored by Git.

## Build the Release Artifact

Run:

```bash
./scripts/package-homebrew-release.sh
```

That script:

1. Archives the app in `Release`.
2. Exports it using the `developer-id` distribution method.
3. Creates `build/homebrew/NotchTerminal-<version>.zip`.
4. Prints the SHA-256 needed by Homebrew.

## Optional Notarization in the Script

If you already saved a `notarytool` keychain profile, you can ask the script to notarize and staple before producing the final ZIP:

```bash
NOTARIZE=1 NOTARY_PROFILE=notary-profile-name ./scripts/package-homebrew-release.sh
```

Create that profile once with a command like:

```bash
xcrun notarytool store-credentials notary-profile-name \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID" \
  --password "app-specific-password"
```

## Publish to GitHub Releases

Upload the generated ZIP to a GitHub Release, for example:

- tag: `v1.2.1`
- asset: `NotchTerminal-1.2.1.zip`

## Cask

```ruby
cask "notchterminal" do
  version "1.2.1"
  sha256 "REPLACE_WITH_SHA256"

  url "https://github.com/marcoastorj/NotchTerminal/releases/download/v#{version}/NotchTerminal-#{version}.zip"
  name "NotchTerminal"
  desc "Drop-down terminal for macOS that lives in your notch"
  homepage "https://github.com/marcoastorj/NotchTerminal"

  app "NotchTerminal.app"
end
```

## Notes

- For Homebrew, a ZIP is enough; a DMG is optional.
- Homebrew rejects apps that fail with Gatekeeper enabled, so use `Developer ID` signing and notarization for public distribution.
- If export fails with `No signing certificate "Developer ID Application" found`, create that certificate in Xcode first.
