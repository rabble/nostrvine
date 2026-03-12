# Play/Pause Control Design

**Date:** 2026-03-12

**Goal**

Implement the Figma center play/pause control everywhere short-form video playback appears, remove duplicate control styling, and fix the pooled-player bug where playback can stop without the play affordance reappearing.

**Current State**

- Pooled feed surfaces use `PausedVideoPlayOverlay` for the centered paused state.
- Legacy `VideoFeedItem` surfaces render their own centered play and fading pause controls inline.
- The pooled overlay keeps "has playback started" as widget-local state, so rebuilding the overlay while the player is paused can permanently suppress the play affordance for that player instance.

**Design**

1. Introduce a shared centered playback control widget for the Figma design.
   - Render the same `64x64` scrim button for both play and pause states.
   - Use the existing `assets/icon/content-controls/play.svg` and `pause.svg` assets.
   - Keep semantics labels explicit for accessibility and tests.

2. Reuse that shared widget in both playback paths.
   - `PausedVideoPlayOverlay` will render the shared control in the play state.
   - `VideoFeedItem` will render the shared control for its centered play state and for the fading pause animation.

3. Fix the pooled paused-state bug at the shared overlay boundary.
   - Track "this player has played before" per `Player` instance rather than per overlay widget instance.
   - Preserve the existing first-frame guard so the play affordance does not appear before the video is visually ready.
   - Continue hiding the play affordance while buffering or actively playing.

**Testing**

- Add a widget test that remounts `PausedVideoPlayOverlay` with the same paused `Player` after playback was previously observed, and verify the play affordance still appears.
- Add a widget test that validates the shared control styling/semantics in both play and pause modes where practical.
- Update feed-overlay coverage to ensure pooled surfaces still hide the play affordance before first frame and while actively playing.

**Non-Goals**

- Unifying the legacy `VideoFeedItem` backend and the pooled `media_kit` backend in this change.
- Broad playback architecture changes outside the center-control behavior.

**Follow-Up**

- File a separate issue to migrate remaining legacy `VideoFeedItem` surfaces onto the pooled playback stack so the app no longer maintains two playback implementations.
