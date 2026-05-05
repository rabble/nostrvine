# Seamless Video Looping Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Apple playback gap caused by manual end-of-item loop replay.

**Architecture:** Android already uses native ExoPlayer repeat mode and remains unchanged. iOS and macOS should use `AVQueuePlayer` with `AVPlayerLooper` when looping is enabled, while non-looping completion still uses the existing completed-state path.

**Tech Stack:** Flutter package tests, Swift AVFoundation, iOS/macOS native plugin code.

---

### Task 1: Add Apple Looping Contract Test

**Files:**
- Modify: `mobile/packages/divine_video_player/test/src/apple_threading_contract_test.dart`

- [ ] **Step 1: Write the failing test**

Add a test for both Apple platform files that expects `AVPlayerLooper`, `AVQueuePlayer`, and no manual `player?.seek(to: .zero)` inside looping completion handling.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test packages/divine_video_player/test/src/apple_threading_contract_test.dart`

Expected: FAIL because current iOS/macOS loop code does not use `AVPlayerLooper`.

### Task 2: Implement Apple Native Looping

**Files:**
- Modify: `mobile/packages/divine_video_player/ios/Classes/DivineVideoPlayerInstance.swift`
- Modify: `mobile/packages/divine_video_player/macos/Classes/DivineVideoPlayerInstance.swift`

- [ ] **Step 1: Add Apple looper state**

Use `AVQueuePlayer` for `player` and add `private var playerLooper: AVPlayerLooper?`.

- [ ] **Step 2: Create or clear the looper when clips/looping change**

After a player item is installed, if `isLooping` is true, create `AVPlayerLooper(player: queuePlayer, templateItem: playerItem)`. If looping is false, clear the looper.

- [ ] **Step 3: Remove manual loop replay**

Update `playerDidFinish()` so looping playback does not seek to zero and replay. It should only handle non-looping completion.

- [ ] **Step 4: Run focused tests**

Run: `flutter test packages/divine_video_player/test`

Expected: PASS.

### Task 3: Verify and Commit

**Files:**
- Check: `git diff`
- Check: `git status --short`

- [ ] **Step 1: Run analyze for the package**

Run from `mobile/packages/divine_video_player`: `flutter analyze`

Expected: No issues.

- [ ] **Step 2: Commit**

Stage only the spec, plan, test, and Swift files. Commit with:

```bash
git commit -m "fix(video-player): use native Apple loop playback"
```

