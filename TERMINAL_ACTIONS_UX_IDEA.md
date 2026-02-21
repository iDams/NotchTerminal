# NotchTerminal – Terminal Actions UX Idea

## Goal
Make multi-terminal management fast from the notch without overloading the main UI.

## Recommended Placement

1. Notch expanded (top-level actions)
- `New`
- `Reorg`
- `Bulk` (new menu button)
- `Settings`

2. Bulk menu (global actions)
- `Restore All`
- `Minimize All`
- `Close All`
- `Close All on This Display`
- (Optional later) `Clear Workspace`

3. Per-terminal chip actions
- `Click`: Restore
- `Right click`: Context menu
  - `Restore`
  - `Minimize`
  - `Close`
  - (Optional) `Always on Top`

4. Hover quick close (optional)
- Show small `x` only on chip hover.
- Fast close for one terminal without opening menu.

5. Safety layer
- Confirm dialog for destructive bulk actions:
  - `Close All`
  - `Clear Workspace`
- Optional checkbox: `Don't ask again`

6. Settings toggles
- `Show chip close button on hover`
- `Confirm before Close All`
- `Close behavior`
  - `Close window only`
  - `Terminate process and close`

7. Power-user shortcuts
- `Option + click` chip: close directly
- `Cmd + Option + K`: Close All
- `Cmd + Option + M`: Minimize All
- `Cmd + Option + R`: Restore All

## Rollout Plan

Phase 1 (MVP)
- Add `Bulk` menu in notch
- Add chip context menu with `Close`
- Add `Close All` + confirmation

Phase 2
- Add hover `x` and keyboard shortcuts
- Add display-scoped close actions

Phase 3
- Add `Clear Workspace` and session restore options
