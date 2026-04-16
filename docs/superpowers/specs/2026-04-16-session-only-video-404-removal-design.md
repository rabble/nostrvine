# Session-Only Video 404 Removal — Fix Design

## Problem

When a video in the fullscreen feed resolves to a real playback 404, the app currently treats it as a player error and leaves the broken item visible. The user sees a "Video not found" error overlay, the feed does not advance, and the same broken video can remain visible in grids during the session.

This is the wrong product behavior for missing content. A confirmed 404 means the current session should treat that item as unavailable content, skip past it in fullscreen, and remove it from in-memory feed/grid data so the user does not keep landing on the same broken item.

## Goals

- Confirmed playback 404s are treated as unavailable content for the current app session.
- The active fullscreen feed auto-advances to the next item after removing the broken video.
- Grids and other feed-backed UI stop showing the broken video during the same session.
- The fix reuses existing in-memory feed removal mechanisms instead of adding persistence or a new broken-video store.

## Non-Goals

- Persisting hidden 404 videos across app launches.
- Changing moderation or age-restriction behavior for 401/403 content.
- Reworking single-video deep-link screens to auto-navigate away when there is no next item.
- Adding new backend APIs or relay metadata for unavailable content.

## Existing Hooks

The current code already has most of the plumbing required:

- `VideoFeedController._classifyError()` in `mobile/packages/pooled_video_player/lib/src/controllers/video_feed_controller.dart` maps playback 404s and generic Divine-hosted failures to `VideoErrorType.notFound`.
- `playbackStatusFromError()` in `mobile/lib/blocs/video_playback_status/video_playback_status_state.dart` maps `VideoErrorType.notFound` to `PlaybackStatus.notFound`.
- `VideoEventService.removeVideoCompletely()` in `mobile/lib/services/video_event_service.dart` already removes a video ID from all in-memory subscription lists, author buckets, hashtag buckets, and adds it to the session-only `_locallyDeletedVideoIds` guard so pagination does not resurrect it in the same run.
- The pooled fullscreen feed already has a `_skipToNextVideo()` helper used by moderation overlays.

The missing piece is a feed-level reaction to `PlaybackStatus.notFound`.

## Design

### 1. Treat playback 404 as session-unavailable content

When the pooled fullscreen feed reports `PlaybackStatus.notFound` for the active video, the screen should:

1. Remove that `video.id` from `VideoEventService` via `removeVideoCompletely(video.id)`.
2. Clear the playback-status entry for that video so stale error state does not linger after removal.
3. Auto-advance to the next page using the existing feed navigation helper.

This keeps the behavior scoped to the current session because `removeVideoCompletely()` only updates in-memory structures plus the existing session-only local-deletion guard.

### 2. Only auto-remove from fullscreen feed-driven flows

The auto-removal should happen in the pooled fullscreen feed path, not in every widget that can render a thumbnail or error overlay. That keeps the behavior tied to a user actually landing on a broken playback item, which is the strongest signal that the content is unavailable.

Deep-linked single-video pages should continue to show a "not found" state because there is no surrounding feed context to advance through.

### 3. Let existing feed/grid consumers update naturally

No grid-specific hide state should be introduced. Once `VideoEventService.removeVideoCompletely()` fires and notifies listeners:

- profile grids
- hashtag feeds
- discovery/home lists
- any other UI backed by the same cached event buckets

will naturally drop the removed item on rebuild.

This keeps one source of truth for session-only unavailable content.

## Recommended Approach

Use the existing playback-status cubit as the trigger, and `VideoEventService` as the source-of-truth mutator.

Why this approach:

- It matches the current architecture: playback error classification stays in the pooled player layer, while feed membership stays in the feed service layer.
- It reuses `removeVideoCompletely()` instead of inventing a parallel "hidden broken items" store.
- It solves both requested user outcomes with one mutation: auto-skip in fullscreen and disappearance from grids.

## Rejected Alternatives

### UI-only skip/hide

Hide the broken tile in widget state and auto-advance locally, without removing it from feed data.

Rejected because the same broken video can reappear from another screen, provider rebuild, or cached feed list during the same session.

### Persist a broken-video registry

Store 404 video IDs in local storage and filter them out across launches.

Rejected because the requirement is explicitly session-only, and a later republish/recovery would remain incorrectly hidden until storage is cleared.

## Error Handling

- Only `PlaybackStatus.notFound` should trigger removal.
- `PlaybackStatus.forbidden` and `PlaybackStatus.ageRestricted` must keep the existing moderated-content behavior.
- If the broken item is the last visible item and there is no next page to animate to, the removal should still happen. The feed can then settle on the updated list length without crashing.
- Repeated notFound callbacks for the same video in the same frame should be idempotent. The reaction logic should guard against double-removal/double-skip.

## Testing Strategy

### Unit / widget-level

- Add a failing test proving that a `PlaybackStatus.notFound` on the active pooled fullscreen item calls `removeVideoCompletely(video.id)` and requests a skip.
- Add a test proving that non-notFound statuses do not trigger removal.
- Add a test proving duplicate notFound emissions do not repeatedly remove/skip the same video.

### Focused verification

- Analyze the touched feed screen, playback-status code, and tests.
- Run the targeted fullscreen-feed test file and any playback-status regression file touched by the change.

## Files Likely Touched

| File | Change |
|------|--------|
| `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` | React to `PlaybackStatus.notFound` by removing the current video and advancing |
| `mobile/lib/blocs/video_playback_status/video_playback_status_cubit.dart` or state helpers | Possibly add a clear/reset helper if needed for one-shot status handling |
| `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart` | Add regression coverage for session-only removal + auto-skip |
| `mobile/test/blocs/video_playback_status/...` | Only if a new clear/reset API is added |

## Risks & Mitigations

**Risk:** Removing a video from all in-memory buckets on first 404 could hide content that was only temporarily unavailable.
**Mitigation:** Scope the behavior to the current session only, exactly as requested. Fresh app launches or fresh data fetches can reintroduce the item.

**Risk:** Auto-advancing while the feed list is mutating could produce page-index races.
**Mitigation:** Reuse the existing `animateToPage()`/skip helper in the fullscreen feed and keep the reaction tightly scoped to the active item.

**Risk:** The notFound signal may fire more than once for the same video.
**Mitigation:** Add a one-shot guard keyed by active video ID in the fullscreen feed state, or clear the playback status immediately after handling.
