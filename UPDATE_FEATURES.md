# Update Feature Plan (Future Integration)

This file tracks the planned in-app update system for NotchTerminal.

## Goal

Implement native macOS in-app updates ("Check for Updates") with signed releases.

## Recommended Stack

- Sparkle 2 (macOS update framework)
- GitHub Releases as distribution source
- Appcast feed (`appcast.xml`) hosted in repo pages/site

## Integration Checklist

1. Add Sparkle dependency to the app target.
2. Add Sparkle updater controller to app lifecycle.
3. Configure `SUFeedURL` to point to the appcast URL.
4. Generate EdDSA key pair for update signing.
5. Sign every release artifact (`.zip`/`.dmg`) with Sparkle tools.
6. Publish and maintain `appcast.xml` entries per release.
7. Wire About -> `Check for Updates` button to Sparkle updater.
8. Test channels:
   - Fresh install -> detects update
   - Same version -> no update
   - Delta/full update path
9. Document release process in README/CONTRIBUTING.

## Security Notes

- Never commit private signing keys.
- Keep key material in local secure storage / CI secret store.
- Validate appcast over HTTPS only.

## Current Status

- About screen button exists.
- If Sparkle is not present, it falls back to opening GitHub Releases.

