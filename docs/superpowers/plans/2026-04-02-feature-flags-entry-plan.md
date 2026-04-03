# Feature Flags Entry Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a playful, always-visible Settings entry that pushes `FeatureFlagScreen` so power users can toggle feature flags.

**Architecture:** Reuse the existing Settings list structure and `Navigator.push(MaterialPageRoute)` to keep navigation localized, and pair the UI change with widget tests that confirm the row exists and navigates correctly.

**Tech Stack:** Flutter / Dart (Settings UI, routing, Riverpod), `flutter_test` for widget tests.

---

## Chunk 1: Settings entry relocation

**Files:**
- Modify: `mobile/lib/screens/settings/settings_screen.dart` (remove the standalone tile so the main list stays uncluttered)
- Modify: `mobile/lib/screens/settings/nostr_settings_screen.dart` (add a tile that pushes `FeatureFlagScreen` inside the Nostr section)

&nbsp;
- [ ] **Step 1: Add the new `ListTile`**

```dart
_SettingsTile(
  icon: Icons.science,
  title: 'Experimental Features',
  subtitle: 'Tweaks that may hiccup—try them if you are curious.',
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const FeatureFlagScreen()),
  ),
),
```

Ensure the new tile lives inside `Nostr Settings`, after the developer options row, and uses the same style as other `_SettingsTile`s.

- [ ] **Step 2: Run the app to sanity-check the layout**

Command: `cd mobile && flutter test --no-pub test/widgets/settings_screen_test.dart test/widgets/nostr_settings_screen_test.dart`

Expected: Layout builds, the Settings screen stops drawing the tile, and the Nostr screen shows it.

## Chunk 2: Widget coverage

**Files:**
- Modify: `mobile/test/widgets/settings_screen_test.dart` (remove assertions that looked for the tile and keep coverage focused on non-Nostr tiles)
- Create: `mobile/test/widgets/nostr_settings_screen_test.dart` (new test that asserts the Experimental Features row is present and navigates to `FeatureFlagScreen`)

- [ ] **Step 1: Retarget the Settings screen test**

Ensure the Settings screen test no longer looks for Experimental Features, keeping the existing tile coverage focused on the other rows.

- [ ] **Step 2: Create a Nostr settings widget test**

Add `mobile/test/widgets/nostr_settings_screen_test.dart` so it asserts the Experimental Features tile appears inside Nostr Settings and pushes `FeatureFlagScreen` when tapped.

### Task 3: Manual verification

- [ ] **Step 1: Launch the app (simulator/emulator)**

Navigate to Settings, confirm the tile sits right after Nostr Settings and before Legal, tap it, and verify `FeatureFlagScreen` opens immediately.

***

Plan complete and saved to `docs/superpowers/plans/2026-04-02-feature-flags-entry-plan.md`. Ready to execute?
