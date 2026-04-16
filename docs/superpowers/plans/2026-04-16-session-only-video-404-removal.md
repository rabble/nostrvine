# Session-Only Video 404 Removal Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove confirmed playback-404 videos from in-memory feed/grid data for the current session and auto-skip past them in the fullscreen feed.

**Architecture:** Keep playback error classification where it already lives in the pooled player stack. Add a feed-level reaction in the pooled fullscreen screen that turns `PlaybackStatus.notFound` for the active item into a session-only `VideoEventService.removeVideoCompletely(video.id)` mutation plus a next-page advance. Reuse existing session-only feed caches instead of adding persistence.

**Tech Stack:** Flutter, flutter_bloc, Riverpod, pooled_video_player, Flutter test, mocktail

---

## Chunk 1: Fullscreen Feed Regression Test

### Task 1: Add a failing regression test for active-video 404 handling

**Files:**
- Modify: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
- Reference: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Reference: `mobile/lib/services/video_event_service.dart`

- [ ] **Step 1: Write the failing test**

Add a focused test that mounts the pooled fullscreen feed with:
- an active video item
- a mocked `VideoEventService`
- a playback-status state of `PlaybackStatus.notFound` for the active `video.id`

Assert that the screen:
- calls `removeVideoCompletely(video.id)`
- requests navigation to the next feed item

- [ ] **Step 2: Run the targeted test file to verify it fails**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: FAIL because the current screen only renders the not-found overlay and does not remove or skip.

## Chunk 2: Minimal Feed-Level Reaction

### Task 2: Implement one-shot notFound handling in the pooled fullscreen feed

**Files:**
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Reference: `mobile/lib/blocs/video_playback_status/video_playback_status_cubit.dart`
- Reference: `mobile/lib/blocs/video_playback_status/video_playback_status_state.dart`
- Reference: `mobile/lib/services/video_event_service.dart`

- [ ] **Step 1: Add a minimal reaction helper in the screen state**

Add a focused helper that:
- detects when the active video enters `PlaybackStatus.notFound`
- ensures the same `video.id` is only handled once
- removes the video via `VideoEventService.removeVideoCompletely(video.id)`
- clears any transient handling state needed to avoid duplicate reactions
- advances to the next page using the existing skip/navigation helper

- [ ] **Step 2: Keep 401/403 and generic errors unchanged**

Confirm the new path only runs for `PlaybackStatus.notFound`.
Do not change existing moderation overlays or retry flows for other statuses.

- [ ] **Step 3: Run the targeted test file to verify it passes**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: PASS for the new regression test.

## Chunk 3: Duplicate-Signal Guard

### Task 3: Add coverage for repeated notFound emissions

**Files:**
- Modify: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
- Modify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`

- [ ] **Step 1: Write a failing duplicate-signal test**

Add a test that emits `PlaybackStatus.notFound` for the same active `video.id` more than once and asserts:
- `removeVideoCompletely(video.id)` is called once
- skip/advance is triggered once

- [ ] **Step 2: Run the targeted test file to verify failure**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: FAIL if the implementation re-handles the same item.

- [ ] **Step 3: Implement the smallest possible one-shot guard**

Use a screen-local handled-video-ID guard or equivalent minimal state so repeated emissions for the same active item are ignored.

- [ ] **Step 4: Run the targeted test file to verify the duplicate case passes**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: PASS for both the original and duplicate-signal cases.

## Chunk 4: Non-notFound Safety Coverage

### Task 4: Prove other statuses do not remove feed items

**Files:**
- Modify: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`

- [ ] **Step 1: Add a failing non-notFound safety test**

Add a test proving that `PlaybackStatus.forbidden`, `PlaybackStatus.ageRestricted`, or `PlaybackStatus.generic` do not call `removeVideoCompletely`.

- [ ] **Step 2: Run the targeted test file to verify failure or missing coverage**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: FAIL or expose missing assertions before implementation is finalized.

- [ ] **Step 3: Adjust implementation only if needed**

If the safety test exposes overly broad handling, narrow the reaction so only `PlaybackStatus.notFound` triggers removal.

- [ ] **Step 4: Run the targeted test file to verify all cases pass**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: PASS for notFound, duplicate-signal, and non-notFound coverage.

## Chunk 5: Verification

### Task 5: Run focused verification and review the diff

**Files:**
- Verify: `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`
- Verify: `mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
- Verify: `mobile/lib/blocs/video_playback_status/video_playback_status_cubit.dart` (only if touched)
- Verify: `mobile/lib/blocs/video_playback_status/video_playback_status_state.dart` (only if touched)

- [ ] **Step 1: Run targeted analyze**

Run: `dart analyze lib/screens/feed/pooled_fullscreen_video_feed_screen.dart test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: `No issues found!`

- [ ] **Step 2: Run targeted fullscreen feed tests**

Run: `flutter test test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart`
Expected: All tests pass.

- [ ] **Step 3: Run playback-status tests if those files changed**

Run: `flutter test test/blocs/video_playback_status`
Expected: All tests pass.

- [ ] **Step 4: Review git diff for scope control**

Run: `git status --short` and `git diff --stat`
Expected: Only the spec, plan, fullscreen feed logic, and targeted tests are changed.
