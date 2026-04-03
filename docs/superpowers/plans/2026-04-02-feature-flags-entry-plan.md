# Feature Flags Entry Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a playful, always-visible Settings entry that pushes `FeatureFlagScreen` so power users can toggle feature flags.

**Architecture:** Reuse the existing Settings list structure and `Navigator.push(MaterialPageRoute)` to keep navigation localized, and pair the UI change with widget tests that confirm the row exists and navigates correctly.

**Tech Stack:** Flutter / Dart (Settings UI, routing, Riverpod), `flutter_test` for widget tests.

---

## Chunk 1: Settings tile entry

**Files:**
- Modify: `mobile/lib/screens/settings/settings_screen.dart` (new tile insertion, layout adjustments near Nostr Settings/Legal)
- Modify: `mobile/lib/features/feature_flags/screens/feature_flag_screen.dart` and README already exist; no change unless doc update required

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

Ensure the tile sits between `Nostr Settings` and `Legal` and uses the same style as other `_SettingsTile`s.

- [ ] **Step 2: Run the app to sanity-check the layout**

Command: `cd mobile && flutter test --no-pub --update-goldens` *(no actual tests yet; run smoke `flutter test --no-pub test/screens/settings/settings_screen_test.dart` after step 2 instead, expecting the Settings tile count change to be reflected when we add the test).*

Expected: Layout builds, new tile visible when running the screen test.

## Chunk 2: Widget coverage

**Files:**
- Modify: `mobile/test/screens/settings/settings_screen_test.dart` (add assertions for new tile and navigation)
- Create: `mobile/test/screens/feature_flag_screen_test.dart` already there; ensure no updates needed beyond verifying the tile triggers navigation.

- [ ] **Step 1: Update the Settings screen test**

Add assertions to confirm the “Try Edgey Features” tile exists and tapping it pushes `FeatureFlagScreen`. If the test harness uses `TestNavigatorObserver`, verify it recorded the push.

- [ ] **Step 2: Run the updated test**

Command: `cd mobile && flutter test --no-pub test/screens/settings/settings_screen_test.dart`

Expected: PASS.

### Task 3: Manual verification

- [ ] **Step 1: Launch the app (simulator/emulator)**

Navigate to Settings, confirm the tile sits right after Nostr Settings and before Legal, tap it, and verify `FeatureFlagScreen` opens immediately.

***

Plan complete and saved to `docs/superpowers/plans/2026-04-02-feature-flags-entry-plan.md`. Ready to execute?
