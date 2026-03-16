# AI Feature Boundary

## Goal

The AI layer can now be paused with a single runtime switch without deleting saved providers, jobs, prompts, or logs.

## Main Switch

The single source of truth lives here:

- `NotchTerminal/Features/AI/AIFeatureAvailability.swift`

The persisted preference lives here:

- `AppPreferences.Keys.aiFeaturesEnabled`

Default value:

- `true`

## What Happens When AI Is Disabled

When `aiFeaturesEnabled` is `false`:

- `AICronjobManager` does not schedule or run AI jobs.
- launchd background AI execution exits early.
- the notch button that opens `AI Control Center` is hidden.
- `AI Control Center` no longer opens and shows a paused state if already reached.
- saved providers, active provider selection, jobs, prompts, and logs remain stored.

This is meant to be a pause switch, not a destructive reset.

## Main Integration Points

If you want to understand or change the boundary, these are the main files:

- `NotchTerminal/Features/AI/AIFeatureAvailability.swift`
- `NotchTerminal/App/AppPreferences.swift`
- `NotchTerminal/App/NotchTerminalApp.swift`
- `NotchTerminal/Features/AI/AIControlCenterWindowController.swift`
- `NotchTerminal/Features/AI/AIControlCenterView.swift`
- `NotchTerminal/Features/Notch/NotchCapsuleView.swift`
- `NotchTerminal/Features/Notch/NotchOverlayController.swift`
- `NotchTerminal/Features/Notch/Models/AICronjobManager.swift`
- `NotchTerminal/Settings/SettingsView.swift`

## If You Want To Remove The Feature Completely

If pausing is not enough and you want to remove the AI feature from the app, start in this order.

### 1. Delete the main AI UI folder

Remove:

- `NotchTerminal/Features/AI/`

This removes:

- `AIControlCenterView`
- `AIControlCenterWindowController`
- provider editing UI
- installed app catalog
- automation helpers
- AI schedule formatter

### 2. Delete AI job models and runtime

Remove:

- `NotchTerminal/Features/Notch/Models/AICronjob.swift`
- `NotchTerminal/Features/Notch/Models/AICronjobLogs.swift`
- `NotchTerminal/Features/Notch/Models/AICronjobManager.swift`
- `NotchTerminal/Services/CronExpression.swift`

### 3. Delete AI settings screens

Remove:

- `NotchTerminal/Settings/AICronjobsSettingsView.swift`
- `NotchTerminal/Settings/AIProvidersSettingsView.swift`
- `NotchTerminal/Settings/Views/AICronjobEditView.swift`

### 4. Remove app-level references

Clean up references in:

- `NotchTerminal/App/AppPreferences.swift`
- `NotchTerminal/App/NotchTerminalApp.swift`
- `NotchTerminal/Features/Notch/NotchCapsuleView.swift`
- `NotchTerminal/Features/Notch/NotchOverlayController.swift`
- `NotchTerminal/Settings/SettingsView.swift`
- `NotchTerminal/Settings/NotchTerminalSettingsComponents.swift`
- `NotchTerminal/Services/LocalCommandExecutor.swift`

### 5. Remove tests and docs

Remove:

- `NotchTerminalTests/CronExpressionTests.swift`
- AI-specific tests that depend on providers/jobs/runtime
- AI sections from `README.md`
- AI docs under `docs/ai/`

## Safe Recommendation

Prefer pausing the feature first.

If the app still behaves correctly with `aiFeaturesEnabled = false`, then removing the feature becomes much safer because the runtime boundary has already been validated.
