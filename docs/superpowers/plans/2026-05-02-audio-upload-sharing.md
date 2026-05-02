# Reusable Sounds Library Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users save sounds they choose from videos into their library without mutating editor draft state outside the recording or editing flow.

**Architecture:** Treat reusable sounds as persisted `AudioEvent` records in a small user sound library backed by `SharedPreferences`. `Use Sound` on a sound detail or browse screen saves the sound and shows feedback; it does not select editor audio, change `VideoEditorProvider`, or close the screen. The Library Sounds tab reads from this saved user library only. Editor integration should later add a "My Sounds" category inside the editor audio bottom sheet after product/design input from @Chardot.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, existing `AudioEvent`, existing sound detail/browser/library UI.

---

## Research Notes

- `VideoEditorNotifier.restoreDraft()` restores `DivineVideoDraft.selectedSound`, so selecting audio outside the recording/editor flow can be overwritten when an autosaved draft is restored.
- The first implementation in this branch wrote `selectedSoundProvider` and `videoEditorProvider.selectedSound` from `SoundDetailScreen` and `SoundsScreen`. That is the wrong behavior for out-of-flow sound reuse.
- `SoundLibraryService` stores `VineSound` asset records and the Library Sounds tab currently converts those assets into bundled `AudioEvent` values. That makes the tab mostly an asset browser, not a user library.
- Reusable video audio is already represented as `AudioEvent` through Kind 1063 events or synthetic `AudioEvent.fromVideoOriginalSound(...)`. Persisting these directly avoids lossy conversion through `VineSound`.
- A future editor bottom-sheet category ("My Sounds") should read from the same saved sound provider, but should not be added in this PR until @Chardot gives input on the editor UX.

## File Map

- Create `mobile/lib/services/saved_sounds_service.dart`: serialize saved reusable `AudioEvent` values, dedupe by full sound ID, and load gracefully from SharedPreferences.
- Create `mobile/lib/providers/saved_sounds_provider.dart`: expose a manual Riverpod notifier for saved sounds without generated code.
- Modify `mobile/lib/screens/sound_detail_screen.dart`: save sounds to the user library, stop preview if needed, show saved/already-saved feedback, and stay on the screen.
- Modify `mobile/lib/screens/sounds_screen.dart`: keep callback selection behavior for in-flow callers; when no callback is supplied, save to the user library and show feedback instead of selecting editor state or popping.
- Modify `mobile/lib/widgets/library/sounds_tab.dart`: show saved user sounds only, with search, preview, and detail navigation.
- Modify tests under `mobile/test/services`, `mobile/test/providers`, `mobile/test/screens`, and `mobile/test/widgets/library` to cover persistence, UI feedback, and the corrected Library Sounds tab.

## Chunk 1: Persist Saved Reusable Sounds

### Task 1: Add Saved Sounds Service

**Files:**
- Create: `mobile/lib/services/saved_sounds_service.dart`
- Test: `mobile/test/services/saved_sounds_service_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('saves and reloads a reusable sound', () async {
  final service = SavedSoundsService(sharedPreferences);
  final result = await service.saveSound(sound);

  expect(result, SavedSoundSaveResult.saved);
  expect(service.loadSounds(), [sound]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/saved_sounds_service_test.dart`

Expected: FAIL because `SavedSoundsService` does not exist.

- [ ] **Step 3: Implement minimal persistence**

Store a JSON array of `AudioEvent.toJson()` maps under a dedicated key such as `saved_reusable_sounds`. Decode with `AudioEvent.fromJson`, ignore corrupt payloads by returning an empty list, and keep newest saved sounds first.

- [ ] **Step 4: Add dedupe and corruption coverage**

Cover duplicate saves returning `SavedSoundSaveResult.alreadySaved`, no duplicate rows, full-ID dedupe, and corrupt JSON fallback.

- [ ] **Step 5: Run tests**

Run: `flutter test test/services/saved_sounds_service_test.dart`

Expected: PASS.

### Task 2: Add Riverpod Provider

**Files:**
- Create: `mobile/lib/providers/saved_sounds_provider.dart`
- Test: `mobile/test/providers/saved_sounds_provider_test.dart`

- [ ] **Step 1: Write failing provider tests**

```dart
test('saveSound updates provider state', () async {
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
  ]);

  final result = await container
      .read(savedSoundsProvider.notifier)
      .saveSound(sound);

  expect(result, SavedSoundSaveResult.saved);
  expect(container.read(savedSoundsProvider), [sound]);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/saved_sounds_provider_test.dart`

Expected: FAIL because `savedSoundsProvider` does not exist.

- [ ] **Step 3: Implement provider**

Create `savedSoundsServiceProvider` from `sharedPreferencesProvider` and a `NotifierProvider<SavedSoundsNotifier, List<AudioEvent>>`. Keep mutation methods on the notifier and refresh `state` from the service after save/remove.

- [ ] **Step 4: Run tests**

Run: `flutter test test/providers/saved_sounds_provider_test.dart`

Expected: PASS.

## Chunk 2: Correct Save UX Outside The Editor

### Task 3: Fix Sound Detail "Use Sound"

**Files:**
- Modify: `mobile/lib/screens/sound_detail_screen.dart`
- Modify: `mobile/test/screens/sound_detail_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Assert tapping `Use Sound` saves the sound, shows `Saved to Sounds`, does not call `context.pop(true)`, and does not mutate `videoEditorProvider`.

- [ ] **Step 2: Run targeted test to verify failure**

Run: `flutter test test/screens/sound_detail_screen_test.dart --plain-name "tapping Use Sound saves sound to library"`

Expected: FAIL because the current implementation still selects editor state and pops.

- [ ] **Step 3: Implement corrected behavior**

Change `_onUseSound` to call `savedSoundsProvider.notifier.saveSound(widget.sound)`, stop preview if needed, show either `Saved to Sounds` or `Already in Sounds`, and remain on the detail screen.

- [ ] **Step 4: Run targeted tests**

Run: `flutter test test/screens/sound_detail_screen_test.dart --plain-name "Use Sound"`

Expected: PASS.

### Task 4: Fix Sounds Browser Fallback Selection

**Files:**
- Modify: `mobile/lib/screens/sounds_screen.dart`
- Modify: `mobile/test/screens/sounds_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Assert tapping a sound without `onSoundSelected` saves it to the library, shows feedback, does not pop, and does not mutate editor state. Keep the callback path unchanged for in-flow selection.

- [ ] **Step 2: Run targeted test to verify failure**

Run: `flutter test test/screens/sounds_screen_test.dart --plain-name "tapping sound without callback saves it to library"`

Expected: FAIL because the current implementation still selects editor state and pops.

- [ ] **Step 3: Implement corrected fallback behavior**

When `onSoundSelected` is present, call it exactly as before. Otherwise, save the tapped sound to the saved sounds provider and show feedback.

- [ ] **Step 4: Run targeted tests**

Run: `flutter test test/screens/sounds_screen_test.dart --plain-name "Sound Selection"`

Expected: PASS.

## Chunk 3: Make Library Sounds A User Library

### Task 5: Replace Asset/Trending Library Tab With Saved Sounds

**Files:**
- Modify: `mobile/lib/widgets/library/sounds_tab.dart`
- Test: `mobile/test/widgets/library/sounds_tab_test.dart`

- [ ] **Step 1: Write failing widget tests**

Assert the Sounds tab renders saved user sounds, filters them by search, and does not render bundled "Featured Sounds" or relay "Trending Sounds" sections.

- [ ] **Step 2: Run targeted test to verify failure**

Run: `flutter test test/widgets/library/sounds_tab_test.dart`

Expected: FAIL because the current tab still reads bundled/trending sounds.

- [ ] **Step 3: Implement saved-sounds tab**

Read `savedSoundsProvider`, keep search/preview/detail behavior, and show an empty state that tells users saved sounds will appear here after they tap `Use Sound`.

- [ ] **Step 4: Run targeted tests**

Run: `flutter test test/widgets/library/sounds_tab_test.dart`

Expected: PASS.

## Chunk 4: Verification And Handoff

- [ ] Run `flutter test test/services/saved_sounds_service_test.dart test/providers/saved_sounds_provider_test.dart test/screens/sound_detail_screen_test.dart test/screens/sounds_screen_test.dart test/widgets/library/sounds_tab_test.dart`
- [ ] Run `flutter analyze`
- [ ] Review `git diff` for any remaining editor-state mutations from out-of-flow sound selection.
- [ ] Commit with a Conventional Commit message.
- [ ] Push the follow-up commit to the existing PR branch.

## Plan Review

- This plan addresses the review feedback by removing out-of-flow editor state writes.
- The implementation reuses `AudioEvent` instead of forcing reusable sounds through `VineSound`.
- The Library Sounds tab becomes a user library as requested.
- The editor bottom sheet "My Sounds" category is explicitly deferred pending @Chardot input.
