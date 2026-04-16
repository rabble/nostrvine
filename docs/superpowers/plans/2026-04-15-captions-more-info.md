# Captions More-Info Move Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the global captions toggle out of the video action rail and into the video more-info sheet, with a default-on preference persisted across app restarts.

**Architecture:** Keep a single global subtitle visibility provider and make it SharedPreferences-backed via the existing `sharedPreferencesProvider`. Update the metadata sheet to become the only in-feed control for that preference, and remove the now-redundant `CC` rail action from the feed overlay. Keep the change incremental and test-backed.

**Tech Stack:** Dart 3.11, Flutter, flutter_riverpod, SharedPreferences, flutter_test, divine_ui.

**Spec:** `docs/superpowers/specs/2026-04-15-captions-more-info-design.md`

**Working directory:** Run all `flutter` and `dart` commands from `mobile/`.

**Branch:** `codex/captions-more-info` in worktree `.worktrees/captions-more-info`

**Process rules:**
- TDD throughout. For each behavior change: write the failing test, run it to verify the failure, implement the minimum code, verify it passes, then refactor.
- Because this work touches an `@riverpod` provider, run `dart run build_runner build --delete-conflicting-outputs` after the provider implementation change and commit generated outputs if they change.
- Run `dart format` on every touched Dart file before commit.
- Reuse `VineTheme` and existing bottom-sheet patterns. Do not add one-off styling.
- Do not reintroduce a second captions control elsewhere in the feed.

---

## File Structure

### Modified files

| File | Responsibility |
|------|----------------|
| `mobile/lib/providers/subtitle_providers.dart` | Persist the global subtitle visibility preference, default it to `true`, and expose explicit setter/toggle APIs |
| `mobile/lib/widgets/video_feed_item/video_feed_item.dart` | Remove the `CC` action from the overlay action column |
| `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart` | Render a captions setting row in the more-info sheet and wire it to the global provider |
| `mobile/test/providers/subtitle_visibility_test.dart` | Verify default-on behavior, persistence, and toggle semantics |
| `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart` | Verify captions row rendering and interaction |

### Deleted files

| File | Responsibility |
|------|----------------|
| `mobile/lib/widgets/video_feed_item/actions/cc_action_button.dart` | Remove obsolete action-rail captions control |
| `mobile/test/widgets/video_feed_item/actions/cc_action_button_test.dart` | Remove obsolete widget tests for the deleted control |

---

## Chunk 1: Persist the global captions preference

### Task 1: Rewrite provider tests for default-on persistence

**Files:**
- Modify: `mobile/test/providers/subtitle_visibility_test.dart`
- Read for context: `mobile/lib/providers/shared_preferences_provider.dart`
- Read for context: `mobile/lib/providers/subtitle_providers.dart`

- [ ] **Step 1: Write the failing tests**

Replace the existing tests with cases that exercise `SharedPreferences` overrides through a `ProviderContainer`.

Add tests for:
- default state is `true` when no preference is stored
- stored `false` value is restored on initialization
- toggling from `true` to `false` persists the stored bool
- toggling from `false` to `true` persists the stored bool

Use this shape:

```dart
late SharedPreferences prefs;
late ProviderContainer container;

setUp(() async {
  SharedPreferences.setMockInitialValues({});
  prefs = await SharedPreferences.getInstance();
  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
});
```

- [ ] **Step 2: Run the provider test and verify it fails**

Run:

```bash
cd mobile
flutter test test/providers/subtitle_visibility_test.dart
```

Expected: at least the default-state test fails because the provider currently builds `false` and does not persist.

- [ ] **Step 3: Implement the provider change**

In `mobile/lib/providers/subtitle_providers.dart`:
- import `shared_preferences_provider.dart`
- add a private preference key constant near the visibility provider, for example:

```dart
const _subtitleVisibilityPreferenceKey = 'subtitle_visibility_enabled';
```

- update `SubtitleVisibility.build()` to read from `sharedPreferencesProvider` and return `prefs.getBool(...) ?? true`
- add an explicit async setter so UI can write a known value:

```dart
Future<void> setEnabled(bool enabled) async {
  state = enabled;
  final prefs = ref.read(sharedPreferencesProvider);
  await prefs.setBool(_subtitleVisibilityPreferenceKey, enabled);
}
```

- keep `toggle()` as a thin wrapper:

```dart
Future<void> toggle() => setEnabled(!state);
```

Do not move subtitle fetching logic out of this file in this task.

- [ ] **Step 4: Regenerate Riverpod outputs**

Run:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

Expected: `subtitle_providers.g.dart` is updated only if generator output changed.

- [ ] **Step 5: Run the provider test and verify it passes**

Run:

```bash
cd mobile
flutter test test/providers/subtitle_visibility_test.dart
```

Expected: all provider tests pass.

- [ ] **Step 6: Format and analyze touched files**

Run:

```bash
cd mobile
dart format lib/providers/subtitle_providers.dart test/providers/subtitle_visibility_test.dart
flutter analyze lib/providers/subtitle_providers.dart test/providers/subtitle_visibility_test.dart
```

Expected: no issues.

- [ ] **Step 7: Commit the persistence slice**

Run:

```bash
cd mobile
git add \
  lib/providers/subtitle_providers.dart \
  lib/providers/subtitle_providers.g.dart \
  test/providers/subtitle_visibility_test.dart
git commit -m "feat(feed): persist global captions preference"
```

---

## Chunk 2: Move the control into the more-info sheet

### Task 2: Add the captions row to the metadata sheet

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`
- Modify: `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart`
- Read for context: `mobile/packages/divine_ui/lib/src/theme/vine_theme.dart`

- [ ] **Step 1: Write the failing metadata-sheet tests**

Add widget tests covering:
- `Captions` row renders in `MetadataExpandedSheet` even when the current video has no subtitle track
- the row reflects the global provider state (`Switch` or equivalent control starts on when prefs are empty)
- tapping the row control updates the provider from on to off

Use a `ProviderContainer` override with mocked `SharedPreferences`, following the same pattern as the provider tests.

The assertions should look for:
- visible `Captions` label
- a material switch widget with `value == true` by default
- provider state becomes `false` after interaction

- [ ] **Step 2: Run the metadata-sheet test selection and verify it fails**

Run:

```bash
cd mobile
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart --plain-name "Captions"
```

Expected: failure because the sheet does not yet render a captions control.

- [ ] **Step 3: Implement the captions row**

In `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart`:
- import `openvine/providers/subtitle_providers.dart`
- convert `_MetadataContent` from `StatelessWidget` to `ConsumerWidget`, or introduce a focused `ConsumerWidget` section for captions
- insert a new row near the top of the sheet content, before the read-only metadata sections, so the user sees the setting immediately
- use existing sheet colors and typography; do not invent new styling
- wire the control to `subtitleVisibilityProvider`
- call `setEnabled(...)` rather than duplicating persistence logic in the widget

Keep the row always visible regardless of `video.hasSubtitles`.

A reasonable structure is:

```dart
class _CaptionsSettingSection extends ConsumerWidget {
  const _CaptionsSettingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(subtitleVisibilityProvider);
    return ...
  }
}
```

- [ ] **Step 4: Run the metadata-sheet tests and verify they pass**

Run:

```bash
cd mobile
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart --plain-name "Captions"
```

Expected: the new captions tests pass.

- [ ] **Step 5: Format and analyze the sheet files**

Run:

```bash
cd mobile
dart format \
  lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart \
  test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart
flutter analyze \
  lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart \
  test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart
```

Expected: no issues.

### Task 3: Remove the rail `CC` button and obsolete tests

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/video_feed_item.dart`
- Delete: `mobile/lib/widgets/video_feed_item/actions/cc_action_button.dart`
- Delete: `mobile/test/widgets/video_feed_item/actions/cc_action_button_test.dart`

- [ ] **Step 1: Write the failing overlay test**

If there is an existing widget test covering `VideoOverlayActionColumn`, extend it. If not, add a focused widget test in the nearest existing overlay test file for this feature area.

The test should assert that the overlay action column no longer renders a widget with semantics identifier `cc_button` for a subtitle-capable video.

If no stable overlay test harness exists, add the assertion to the metadata sheet task as a smaller safety check by pumping the feed item path already covered in tests.

- [ ] **Step 2: Run the targeted test and verify it fails**

Run the smallest relevant test command for the file you changed in Step 1. Expected: failure because the `CC` button still exists in `VideoOverlayActionColumn`.

- [ ] **Step 3: Remove the rail action**

In `mobile/lib/widgets/video_feed_item/video_feed_item.dart`, remove the `CcActionButton(video: video),` line from `VideoOverlayActionColumn`.

Delete the now-unused widget and test files:
- `mobile/lib/widgets/video_feed_item/actions/cc_action_button.dart`
- `mobile/test/widgets/video_feed_item/actions/cc_action_button_test.dart`

Also remove any now-unused exports/imports that referenced `CcActionButton`.

- [ ] **Step 4: Run targeted tests and verify they pass**

Run:

```bash
cd mobile
flutter test test/providers/subtitle_visibility_test.dart
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart --plain-name "Captions"
```

Also run the targeted overlay test command from Step 2.

Expected: all targeted tests pass.

- [ ] **Step 5: Format and analyze touched files**

Run:

```bash
cd mobile
dart format lib/widgets/video_feed_item/video_feed_item.dart
flutter analyze lib/widgets/video_feed_item/video_feed_item.dart
```

Expected: no issues.

- [ ] **Step 6: Commit the UI slice**

Run:

```bash
cd mobile
git add \
  lib/widgets/video_feed_item/video_feed_item.dart \
  lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart \
  test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart
git rm \
  lib/widgets/video_feed_item/actions/cc_action_button.dart \
  test/widgets/video_feed_item/actions/cc_action_button_test.dart
git commit -m "feat(feed): move captions control into more info"
```

---

## Final Verification

- [ ] Run:

```bash
cd mobile
flutter test test/providers/subtitle_visibility_test.dart
flutter test test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart
flutter analyze
```

Expected:
- provider tests pass
- metadata sheet tests pass
- analyzer passes for the app

- [ ] Review the final diff to confirm:
- `CC` is gone from the video rail
- the more-info sheet owns the captions toggle
- default captions state is on
- the preference is persisted with `SharedPreferences`

- [ ] Create a final commit if verification work changed anything:

```bash
cd mobile
git status --short
git add <any remaining task files>
git commit -m "test(feed): verify captions sheet migration"
```
