# AI Vision & Connected Apps

## Overview

NotchTerminal NotchAgent now supports visual verification of macOS apps through screenshot capture and AI vision capabilities.

## Connected Apps

Jobs can connect to both internal and external apps:

### Internal Apps
- **Notch Terminal**: control the built-in NotchTerminal terminal emulator

### Installed macOS Apps
- Any app installed in `/Applications`, `/System/Applications`, or `~/Applications`
- Apps are identified by bundle identifier (e.g., `com.apple.calculator`, `com.google.Chrome`)

## App Tokens

Connected apps generate prompt tokens that can be inserted into job prompts:

| App Type | Token Format | Example |
|----------|--------------|---------|
| Notch Terminal | `@notch-terminal` | `@notch-terminal open` |
| Installed App | `@app:bundle.id` | `@app:com.apple.calculator` |

### UI Helpers

The job editor provides visual helpers:
1. **Attach** - adds app to job's connected apps
2. **Insert Token** - inserts app token into prompt
3. **Insert Capture** - inserts screenshot instruction phrase
4. **Drag & Drop** - drag tokens directly into prompt editor

## AI Vision Workflow

### Basic Example

```txt
Open @app:com.apple.calculator
Type 2+2=
Capture the app window for @app:com.apple.calculator
Only answer using the final screenshot.
Do not infer or guess the result.
If you do not capture the final screenshot, answer FAILED.
```

### Automatic Verification

When a prompt contains phrases like:
- "capture the app window"
- "screenshot"
- "inspect the visible result"
- "do not infer"

The runtime will:
1. Track the last visual action (`type_text`, `press_key`)
2. Auto-capture screenshot after the action
3. Inject screenshot into AI context as base64 PNG
4. Require final answer to reference the captured image
5. Fail job if screenshot cannot be captured

## Tools

### `mac_app`

Controls connected macOS apps.

**Actions:**
- `open_app` - launch the app
- `activate_app` - bring app to front
- `type_text` - type text character-by-character
- `press_key` - press special keys (enter, escape, tab, arrows)

**Example:**
```json
{
  "name": "mac_app",
  "arguments": {
    "action": "type_text",
    "bundle_identifier": "com.apple.calculator",
    "text": "2+2="
  }
}
```

### `capture_app_window`

Captures a screenshot of a connected app's window.

**Arguments:**
- `bundle_identifier` - the connected app to capture

**Example:**
```json
{
  "name": "capture_app_window",
  "arguments": {
    "bundle_identifier": "com.apple.calculator"
  }
}
```

**Response:**
The tool returns a success message and appends a new user message containing:
- Text instruction: "Here is the latest screenshot for @app:..."
- Image URL: `data:image/png;base64,...` (base64 PNG)

### `notch_terminal`

Controls the internal NotchTerminal terminal emulator.

**Actions:**
- `open_terminal` - open a new terminal window
- `restore_all_windows` - restore minimized terminals
- `write_text` - type text into terminal (with optional Enter)

## Prompt Helpers

The UI provides ready-to-use phrases:

| Helper | Inserts |
|--------|---------|
| Insert Capture | `Capture the app window for @app:bundle.id` |

These helpers ensure the AI recognizes when visual verification is required.

## Permissions

### Accessibility

Required for:
- `type_text` action
- `press_key` action

Grant in: `System Settings > Privacy & Security > Accessibility`

### Screen Recording

Required for:
- `capture_app_window` tool
- Any visual verification workflow

Grant in: `System Settings > Privacy & Security > Screen Recording`

**Note:** After granting permissions, you must:
1. Close NotchTerminal completely
2. Reopen the app
3. Permissions take effect on next launch

## Development Workflow

For stable permission handling during development:

1. Build from Xcode (Debug configuration)
2. App is automatically installed to `/Applications/NotchTerminal.app`
3. Grant permissions to the installed app
4. Test using the installed copy, not the Xcode build

This ensures TCC (Transparency, Consent, and Control) properly tracks permissions.

## Failure Modes

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| "Screen Recording permission is required" | Permission not granted or app restarted after grant | Grant permission, close app, reopen |
| "App is not currently running" | Target app not launched | Use `open_app` action first |
| "No visible window found" | App has no on-screen windows | Check if app is minimized or has no windows |
| "FAILED: Final screenshot verification is required" | Prompt requires visual verification but no capture completed | Add explicit capture instruction or check auto-capture logic |

### Job Guards

The runtime enforces:
1. If prompt requires visual verification
2. And a visual action occurred (`type_text`, `press_key`)
3. But no screenshot was captured after that action
4. Then job fails with explicit error (does not allow AI to guess)

This prevents AI hallucination of app state.

## Implementation Notes

### Screenshot Capture

- Uses `CGWindowListCreateImage` for window-specific capture
- Targets on-screen windows only
- Excludes desktop elements
- Returns PNG encoded as base64

### Character-by-Character Typing

`type_text` sends each Unicode scalar individually with 60ms delays:
- More reliable for apps like Calculator
- Prevents dropped characters
- Respects app's text input handling

### Multimodal Messages

Screenshots are injected as:
```swift
AIMessageContent.parts([
  AIChatContentPart(type: "text", text: "..."),
  AIChatContentPart(type: "image_url", imageURL: AIImageURLContent(url: "data:image/png;base64,..."))
])
```

## Future Enhancements

Potential additions:
- Keyboard shortcuts with modifiers (`Command+L`, `Command+R`)
- UI element click automation via Accessibility API
- Live video stream for real-time UI monitoring
- Provider-specific vision optimizations
