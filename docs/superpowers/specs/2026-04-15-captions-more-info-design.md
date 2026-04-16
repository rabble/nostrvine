# Global Captions Toggle in Video More-Info Sheet

**Date:** 2026-04-15
**Status:** Approved

## Problem

The video feed currently gives `CC` a dedicated slot in the right-side action rail. That takes space away from higher-value social actions and treats captions like a per-video action, even though the app already models subtitle visibility as a single global preference.

The requested behavior is:
- Remove `CC` from the social interaction sidebar.
- Move the control into the video's more-info sheet.
- Make the toggle global for the whole app, not per-video.
- Default captions to `on` for everyone.
- Persist the preference across app restarts.

## Design

### UI behavior

Remove the `CC` button from the video overlay action column.

Add a `Captions` setting row to the more-info sheet opened by the three-dot action button. The row is always visible, even when the current video has no subtitle track, because it controls the global preference for the rest of the feed rather than the current item only.

The row should read as a persistent setting, not as a video action:
- Label: `Captions`
- Control: on/off switch
- Semantics should describe the current global state

### State model

Keep a single app-wide subtitle visibility state. Do not introduce per-video caption state.

When the user changes the toggle in the more-info sheet:
- Update the global subtitle visibility state immediately.
- Persist the new value immediately.
- Let all current and future subtitle-capable videos respect that value.

Videos without subtitle data continue to render no subtitle overlay, but the setting still updates globally for later videos that do have subtitles.

### Persistence

Persist the subtitle visibility preference with `SharedPreferences`, using the existing app-level `sharedPreferencesProvider`.

Behavior:
- If no value has been stored yet, default to `true`.
- After the first user change, subsequent app launches should restore the stored value.

### Implementation shape

Primary change surface:

| File | Change |
|------|--------|
| `mobile/lib/providers/subtitle_providers.dart` | Make the global subtitle visibility provider read/write a persisted preference and default to `true` |
| `mobile/lib/widgets/video_feed_item/video_feed_item.dart` | Remove `CcActionButton` from the overlay action column |
| `mobile/lib/widgets/video_feed_item/metadata/metadata_expanded_sheet.dart` | Add a captions setting section or row wired to the global provider |
| `mobile/lib/providers/shared_preferences_provider.dart` | Reuse existing provider only; no new initialization path needed |

Supporting cleanup:

| File | Change |
|------|--------|
| `mobile/lib/widgets/video_feed_item/actions/cc_action_button.dart` | Delete if no longer referenced |
| `mobile/test/providers/subtitle_visibility_test.dart` | Update expectations for default-on and persistence |
| `mobile/test/widgets/video_feed_item/actions/cc_action_button_test.dart` | Remove or replace with tests for the new sheet-based control |
| `mobile/test/widgets/video_feed_item/metadata/metadata_expanded_sheet_test.dart` | Add tests for captions row rendering and global toggle behavior |

## Out Of Scope

- Changing subtitle fetching behavior or subtitle parsing.
- Adding a second captions setting elsewhere in Settings.
- Per-video caption preferences.
- New protocol or Nostr event changes.

## Testing

- Provider tests for default `true`, toggling, and persisted initialization.
- Widget tests confirming the more-info sheet renders a `Captions` row and updates the global preference.
- Widget tests confirming the feed action rail no longer renders the `CC` button.
- Any required generated Riverpod outputs should be refreshed if the provider signature changes.
