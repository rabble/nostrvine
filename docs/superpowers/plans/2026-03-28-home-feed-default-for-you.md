# Home Feed Default To For You Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Home default to `For You` when no preference exists, while preserving the user's remembered `For You` / `New` / `Following` choice across app restarts.

**Architecture:** Reuse the existing `VideoFeedBloc` persistence path instead of adding new state. The change is limited to aligning default feed-mode values and tightening tests around startup and restore behavior.

**Tech Stack:** Flutter, flutter_bloc, SharedPreferences, flutter_test, bloc_test

---

## Chunk 1: Default And Restore Behavior

### Task 1: Lock the desired startup behavior in tests

**Files:**
- Modify: `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests that:
- assert `VideoFeedStarted()` uses `FeedMode.forYou` when `selected_feed_mode` is absent
- assert a saved `selected_feed_mode` still overrides the default
- assert any initial-state expectation matches the new default

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test --no-pub test/blocs/video_feed/video_feed_bloc_test.dart`
Expected: FAIL on the old `following` default assumptions

- [ ] **Step 3: Write minimal implementation**

Align the default Home feed mode in:
- `mobile/lib/screens/feed/video_feed_page.dart`
- `mobile/lib/blocs/video_feed/video_feed_state.dart`

Do not change the existing persistence key or add new storage.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test --no-pub test/blocs/video_feed/video_feed_bloc_test.dart`
Expected: PASS

- [ ] **Step 5: Run focused regression tests**

Run:
- `cd mobile && flutter test --no-pub test/screens/feed/feed_mode_switch_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add \
  docs/superpowers/specs/2026-03-28-home-feed-default-for-you-design.md \
  docs/superpowers/plans/2026-03-28-home-feed-default-for-you.md \
  mobile/lib/screens/feed/video_feed_page.dart \
  mobile/lib/blocs/video_feed/video_feed_state.dart \
  mobile/test/blocs/video_feed/video_feed_bloc_test.dart
git commit -m "fix(home): default feed to for you"
```
