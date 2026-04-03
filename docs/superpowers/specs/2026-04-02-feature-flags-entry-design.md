## Visibility Enhancements for Feature Flags

### Background
Feature flags are already manageable through `FeatureFlagScreen`, but there is no surface for users to get there unless they push it programmatically. We want a Settings-based discovery path that feels playful yet lets folks reach the toggles without digging into developer-only menus.

### Goals
1. Add a subtly placed entry inside `Nostr Settings` so users can launch `FeatureFlagScreen` from the settings flow without cluttering the home list.
2. Keep the language light and playful, avoid over-promising, and make it clear the toggles are experimental.
3. Use existing navigation patterns (`MaterialPageRoute`) so we don't need new router plumbing.

### Proposed Design
- **Settings tile**: Add a `ListTile` inside `Nostr Settings` (after the developer options row) with title `Experimental Features` and subtitle `Tweaks that may hiccup—try them if you are curious.` `onTap` pushes `FeatureFlagScreen` via `MaterialPageRoute`. Keeping it inside Nostr Settings keeps the main settings list focused while still keeping the toggle discoverable for curious users.
- **Navigation behavior**: Tapping the row immediately transitions to `FeatureFlagScreen`. No dialog or secret code; the copy signals that the area is for experimental tweaks. We rely on the README guidance (`Navigator.push(... FeatureFlagScreen())`).
- **Testing/QA**: Add widget tests verifying the new tile appears inside `NostrSettingsScreen` and pushes `FeatureFlagScreen`. Update the general `SettingsScreen` test to stop looking for the tile. Manual smoke test: open Nostr Settings, tap the row, confirm `FeatureFlagScreen` opens.

### Open Questions
1. Should the tile be gated behind any permissions or developer-locking? Not required now; we rely on the copy to signal caution.
2. Any analytics needed when toggles are accessed? Not in scope for this change.

If this plan looks good, we can move on to writing the implementation plan.
