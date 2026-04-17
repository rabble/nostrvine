# Feed-Scoped Auto Advance Mode

**Date:** 2026-04-16
**Status:** Draft

## Problem

Divine feeds already feel like a sequence of short videos, but each clip currently loops in place until the user manually swipes. That works for active browsing, but it does not support the more passive "compilation" behavior the product wants: turn on a lightweight mode and let the current feed keep moving after each video plays once.

This needs to work across feed surfaces like For You, hashtags, profile feeds, and curated lists without turning into a global app preference. The user intent is "auto this feed right now," not "change playback behavior everywhere forever."

## Design

### Feed-scoped `Auto` mode

Add a lightweight `Auto` control to the video action rail above the like button. It uses a quiet double-arrow treatment (`>>`) with an active and inactive visual state.

`Auto` is scoped to the current feed session only:
- It defaults to `off` every time a feed is entered
- It is not stored in Settings
- It is not persisted in `SharedPreferences`
- Leaving the feed clears its state

Each feed surface owns its own `Auto` session state. Turning it on in one feed does not affect any other feed.

### Playback behavior

When `Auto` is enabled:
- The current video should play once
- On normal completion, the feed should advance to the next video

Advance order:
1. If a next item already exists in the current feed, move to it
2. If the feed supports pagination and more content can be loaded, request more and continue forward
3. If the feed is exhausted and no more content can be loaded, wrap to the first item in the list

This behavior should only appear on surfaces with real feed navigation semantics. If a surface is truly single-video with no next/previous model, the control should be hidden.

### Interaction rules

There are two feed-session concepts:
- `autoEnabled`: whether the user has turned `Auto` on for this feed
- `autoSuppressed`: whether a non-swipe interaction has temporarily stopped auto-advance

Effective auto behavior is active only when:
- `autoEnabled == true`
- `autoSuppressed == false`

Non-swipe interactions suppress `Auto` immediately for the current feed session:
- pause/play tap
- like
- comment
- repost
- share
- opening profile
- opening metadata/details

Once suppressed, auto-advance stays stopped until one of these happens:
- the user taps `>>` again
- the user manually swipes to another video

Manual swipe does not disable `Auto`. It clears suppression and allows auto-advance to apply again on the newly active video.

### Completion and failure boundaries

Auto-advance should happen only after a normal completed play.

It should not blindly skip on:
- playback errors
- content warning overlays
- moderation blocks
- age gates

Those flows should continue to honor their existing UX. Any skip behavior for moderated or blocked items must remain explicit and surface-driven rather than being introduced by `Auto` mode.

## Architecture

### Keep the logic in the feed layer

This should be implemented in Divine's feed layer, not in the shared `pooled_video_player` package.

Reasoning:
- The state is feed-session scoped, not generic player state
- The rules depend on Divine-specific user interactions
- Pagination, wrapping, and route/feed semantics belong to app screens and blocs

### Fullscreen feed

The fullscreen pooled feed is the primary seam for implementation because it already owns:
- active index changes
- pagination requests
- programmatic page movement

The screen or its adjacent state holder should:
- track `autoEnabled`
- track `autoSuppressed`
- detect normal video completion
- advance to next, paginate, or wrap
- clear suppression on manual swipe
- suppress on non-swipe actions triggered from the rail or overlay flows

### Other feed surfaces

Other navigable feed surfaces should adopt the same feed-session contract through their own controller/state seams rather than pushing this down into shared player code.

The action rail button should be reusable, but the effective state should be provided by the current feed surface.

## UI details

- Placement: above the heart in the action rail
- Labeling: lightweight `Auto` treatment paired with the `>>` visual
- Tone: should read as a playback mode, not a primary social action
- Active state must be visually obvious enough to understand whether the current feed will keep advancing

## Files likely involved

| File | Likely change |
|------|---------------|
| `mobile/lib/widgets/video_feed_item/video_feed_item.dart` | Add rail button wiring and interaction suppression hooks |
| `mobile/lib/widgets/video_feed_item/actions/` | Add `AutoActionButton` or equivalent rail control |
| `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` | Own feed-session auto state and advance behavior |
| `mobile/lib/blocs/fullscreen_feed/` | Add events/state only if needed for clearer feed-session coordination |
| Other feed surfaces | Mirror feed-scoped state where they own sequencing outside fullscreen |

## Out of scope

- Any global Settings entry for this feature
- Persisting auto state across feeds or app relaunches
- A single app-wide "autoplay all feeds" preference
- New moderation skip behavior
- New player-package abstractions for Divine-specific feed semantics

## Testing

- Widget test: action rail shows `Auto` control above like on supported feed surfaces
- Widget test: `Auto` starts off for a fresh feed session
- Feed behavior test: normal completion advances to the next video
- Feed behavior test: non-swipe interaction suppresses auto-advance
- Feed behavior test: manual swipe clears suppression and re-enables effective auto behavior
- Feed behavior test: pagination is requested and playback continues when more content is available
- Feed behavior test: exhausted feed wraps to the first item
- Regression test: error/moderation/content-warning states do not auto-skip just because `Auto` is enabled
