## Visibility Enhancements for Feature Flags

### Background
Feature flags are already manageable through `FeatureFlagScreen`, but there is no surface for users to get there unless they push it programmatically. We want a Settings-based discovery path that feels playful yet lets folks reach the toggles without digging into developer-only menus.

### Goals
1. Add an always-visible entry on `SettingsScreen` so users can launch `FeatureFlagScreen` directly.
2. Keep the language light and playful, avoid over-promising, and make it clear the toggles are experimental.
3. Use existing navigation patterns (`MaterialPageRoute`) so we don't need new router plumbing.

### Proposed Design
- **Settings tile**: Add a `ListTile` right after the `Nostr Settings` row with title `Experimental Features` and subtitle `Tweaks that may hiccup—try them if you are curious.` `onTap` pushes `FeatureFlagScreen` via `MaterialPageRoute`. The tile uses the same `VineTheme` colors as other tiles so it feels hidden among the less experimental settings.
- **Navigation behavior**: Tapping the row immediately transitions to `FeatureFlagScreen`. No dialog or secret code; the copy signals that the area is for experimental tweaks. We rely on the README guidance (`Navigator.push(... FeatureFlagScreen())`).
- **Testing/QA**: Add widget tests verifying the new tile appears, uses expected copy, and pushes the screen. Update any existing `SettingsScreen` tests to account for the extra tile count. Manual smoke test: run Settings screen, tap the row, confirm `FeatureFlagScreen` pushes.

### Open Questions
1. Should the tile be gated behind any permissions or developer-locking? Not required now; we rely on the copy to signal caution.
2. Any analytics needed when toggles are accessed? Not in scope for this change.

If this plan looks good, we can move on to writing the implementation plan.
