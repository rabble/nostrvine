# Play/Pause Control Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Figma-matched center play/pause control everywhere short-form playback appears and fix the pooled paused-state overlay bug without changing the underlying player architecture.

**Architecture:** Extract one reusable centered playback-control widget in the app layer and use it from both the pooled overlay path and the legacy `VideoFeedItem` path. Fix the pooled stale-state bug by persisting "played before" state per `Player` instance so widget remounts do not erase paused-state visibility.

**Tech Stack:** Flutter, Dart, `flutter_svg`, `media_kit`, `video_player`, Flutter widget tests

---

## Chunk 1: Shared Control And Pooled Overlay

### Task 1: Add failing pooled-overlay tests

**Files:**
- Create: `mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart`
- Modify: `mobile/test/screens/feed/feed_video_overlay_test.dart`

- [ ] **Step 1: Write the failing tests**

- [ ] **Step 2: Run the targeted tests and verify the pooled remount case fails for the current implementation**

Run: `flutter test test/widgets/video_feed_item/paused_video_play_overlay_test.dart test/screens/feed/feed_video_overlay_test.dart`

- [ ] **Step 3: Implement the minimal pooled-overlay fix**

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/paused_video_play_overlay.dart`
- Create: `mobile/lib/widgets/video_feed_item/center_playback_control.dart`

- [ ] **Step 4: Re-run the targeted pooled tests until green**

Run: `flutter test test/widgets/video_feed_item/paused_video_play_overlay_test.dart test/screens/feed/feed_video_overlay_test.dart`

## Chunk 2: Legacy Surface Reuse

### Task 2: Replace inline legacy controls with the shared widget

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/video_feed_item.dart`
- Test: `mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart`

- [ ] **Step 1: Write or extend a test that verifies the shared control remains accessible in play and pause states where practical**

- [ ] **Step 2: Replace the legacy inline play/pause button containers with the shared control**

- [ ] **Step 3: Re-run the smallest relevant tests**

Run: `flutter test test/widgets/video_feed_item/paused_video_play_overlay_test.dart test/screens/feed/feed_video_overlay_test.dart`

## Chunk 3: Follow-Up Tracking And Verification

### Task 3: File the architecture follow-up and verify the final diff

**Files:**
- Modify: `docs/superpowers/specs/2026-03-12-play-pause-control-design.md`

- [ ] **Step 1: Create a GitHub issue describing migration from legacy `VideoFeedItem` playback to pooled playback**

- [ ] **Step 2: Run final targeted verification**

Run: `flutter test test/widgets/video_feed_item/paused_video_play_overlay_test.dart test/screens/feed/feed_video_overlay_test.dart`

- [ ] **Step 3: Run one additional relevant regression test if legacy playback code changes materially**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 4: Review `git diff` and ensure only play/pause-control and issue-tracking changes remain**
