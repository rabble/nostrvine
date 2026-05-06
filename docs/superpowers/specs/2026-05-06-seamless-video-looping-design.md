# Seamless Video Looping

**Date:** 2026-05-06
**Status:** Approved

## Problem

Users report a visible or audible gap when short videos loop. The Apple native player currently waits for `AVPlayerItemDidPlayToEndTime`, then seeks to zero and calls `play()` again. That restart happens only after the item has ended, so it can create a loop boundary gap.

Android already uses ExoPlayer `REPEAT_MODE_ALL`, which is the native repeat path for queued media.

## Design

Keep Android unchanged.

On iOS and macOS, replace manual end-notification loop replay with `AVQueuePlayer` plus `AVPlayerLooper`. Apple documents `AVPlayerLooper` as the AVFoundation API for looping media content through a queue player by inserting replica items. That lets the next loop iteration be queued before the current one ends.

When looping is disabled, Apple playback should preserve the current behavior: send `completed`, pause/deactivate audio overlays, and keep normal end-of-item state updates.

## Testing

Add a native contract test that inspects the Apple Swift sources and fails if loop handling still uses manual end-notification seek/replay instead of `AVPlayerLooper`. Run the focused `divine_video_player` package tests from `mobile/`.

