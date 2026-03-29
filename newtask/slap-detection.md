# Slap Detection — Experimental Feature

## Branch
`feat/slap-detection` (2 commits ahead of `main`, not pushed)

## What It Does
Detects physical slaps/taps on the MacBook chassis using the built-in Apple Silicon accelerometer (Bosch BMI286 IMU via IOKit HID). When the configured number of slaps is detected within a 1-second window, it triggers a configurable action.

## Files Created
| File | Purpose |
|------|---------|
| `NotchTerminal/Services/SlapDetectionService.swift` | Core service — IOKit HID accelerometer reader, STA/LTA deviation detection, multi-slap counting |

## Files Modified
| File | What Changed |
|------|-------------|
| `NotchTerminal/App/AppPreferences.swift` | Added `SlapAction` enum, `slapDetectionEnabled/sensitivity/requiredSlaps/action` to `ExperimentalFeatureConfiguration`, keys, defaults, and `int()` helper |
| `NotchTerminal/App/NotchTerminalApp.swift` | `applySlapDetectionPreference()` starts/stops service on toggle; `handleSlapAction()` dispatches to openTerminal or expandNotch |
| `NotchTerminal/Settings/ExperimentalSettingsView.swift` | Added slap detection section: toggle, sensitivity slider, required slaps slider, action picker |
| `NotchTerminal/Features/Notch/NotchOverlayController.swift` | Changed `pinDisplayExpanded`/`unpinDisplayExpanded` from `private` to `internal` |
| `NotchTerminal/*/Localizable.strings` (10 languages) | Added ~12 strings per language for slap detection UI |

## Files Deleted
| File | Why |
|------|-----|
| `NotchTerminal/Features/Windows/SlapHelloWorldView.swift` | Replaced with real actions (open terminal / expand notch) |

## Architecture

### Sensor Access (IOKit HID)
1. `wakeSPUDrivers()` — Enumerates `AppleSPUHIDDriver` services via `IOServiceMatching`, sets `SensorPropertyReportingState=1`, `SensorPropertyPowerState=1`, `ReportInterval=1000` on each
2. `registerHIDDevices()` — Enumerates `AppleSPUHIDDevice` services, filters by `PrimaryUsagePage=0xFF00` + `PrimaryUsage=3` (accelerometer), calls `IOHIDDeviceCreate` → `IOHIDDeviceOpen` → `IOHIDDeviceRegisterInputReportCallback`
3. Reports are 22 bytes: 6-byte header + 3x Int32 little-endian (x, y, z), scaled by `/65536.0`

### Detection Algorithm
1. **Baseline filter** — Exponential moving average (`alpha=0.001`) learns the rest position (gravity ~1g on Z axis)
2. **Deviation** — `sqrt(dx² + dy² + dz²)` where `d*` = sample − baseline
3. **STA/LTA ratio** — Short-term average (window=5) vs long-term average (window=150) of squared deviation
4. **Slap trigger** — When `ratio > threshold` AND `deviation > minDeviation` AND cooldown elapsed (0.75s)
5. **Multi-slap** — Counts slaps in a 1-second window; fires action when count ≥ `requiredSlaps`

### Configurable Parameters
| Parameter | Type | Range | Default | Storage Key |
|-----------|------|-------|---------|-------------|
| Enabled | Bool | — | `false` | `experimentalSlapDetectionEnabled` |
| Sensitivity | Double | 0–100 | `50` | `experimentalSlapDetectionSensitivity` |
| Required slaps | Int | 1–5 | `2` | `experimentalSlapDetectionRequiredSlaps` |
| Action | String | `openTerminal` / `expandNotch` | `expandNotch` | `experimentalSlapDetectionAction` |

Sensitivity maps to:
- `staLTAOnThreshold` = 8.0 − (sensitivity/100 × 6.0) → range 2.0–8.0
- `minDeviation` = 0.16 − (sensitivity/100 × 0.12) → range 0.04–0.16

### Actions
- **Open Terminal** — Calls `notchController?.openBlackWindowForCurrentInteractionScreen()`
- **Expand Notch** — Calls `notchController?.pinDisplayExpanded(displayID)`, auto-collapses after 3 seconds via `unpinDisplayExpanded`

## Requirements / Limitations
- **Root access required** — `IOHIDDeviceOpen` needs `sudo`. App must be launched with `sudo /path/to/NotchTerminal`
- **Apple Silicon only** — Only MacBooks with M2+ (or M1 Pro/Max/Ultra) have the BMI286 IMU
- **macOS 14+** per project minimum
- The `pinDisplayExpanded`/`unpinDisplayExpanded` methods on `NotchOverlayController` were changed from `private` to `internal` — this is the programmatic API for notch expand/collapse

## How to Test
1. Build in Xcode
2. Run with `sudo` from terminal: `sudo /path/to/NotchTerminal.app/Contents/MacOS/NotchTerminal`
3. Settings → Experimental → Enable "Slap Detection"
4. Configure sensitivity, required slaps, and action
5. Slap the MacBook the required number of times within 1 second
6. Check logs: `log stream --predicate 'process == "NotchTerminal"' --level debug | grep SlapDetection`

## Known Issues / TODO
- Requires `sudo` — could explore HelperTool (SMJobBless) for privilege escalation without sudo
- Baseline adaptation is slow (`alpha=0.001`) — if laptop orientation changes during monitoring, detection may be temporarily unreliable
- No visual feedback that detection is active (only status text in settings)
- The expand notch action hardcodes a 3-second collapse delay
- NSLog diagnostic logs should be removed or gated behind a debug flag before merging to main
