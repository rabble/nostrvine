# Profile Grid Pagination Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Load more profile videos when the user scrolls to the bottom of the profile grid.

**Architecture:** Keep pagination ownership in `ProfileFeed` and add only the missing UI trigger in `ProfileVideosGrid`. Verify the behavior with a widget test that fails before the implementation and passes after the grid listens for near-bottom scroll.

**Tech Stack:** Flutter, Riverpod, flutter_test, mocktail

---

## Chunk 1: Reproduce The Missing Grid Trigger

### Task 1: Add a failing widget test for profile grid pagination

**Files:**
- Modify: `mobile/test/screens/profile_grid_tap_navigation_test.dart`
- Test: `mobile/test/screens/profile_grid_tap_navigation_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('scrolling profile grid near bottom requests more videos', ...)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/profile_grid_tap_navigation_test.dart`
Expected: FAIL because the grid never calls `loadMore()`

## Chunk 2: Add Grid-Only Pagination

### Task 2: Trigger existing profile pagination from the grid

**Files:**
- Modify: `mobile/lib/widgets/profile/profile_videos_grid.dart`
- Test: `mobile/test/screens/profile_grid_tap_navigation_test.dart`

- [ ] **Step 3: Write minimal implementation**

```dart
// Listen to profile feed state, observe scroll position, and call
// profileFeedProvider(userIdHex).notifier.loadMore() near the bottom.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/profile_grid_tap_navigation_test.dart`
Expected: PASS with the new pagination test green

### Task 3: Verify surrounding behavior

**Files:**
- Modify: `mobile/lib/widgets/profile/profile_videos_grid.dart`
- Test: `mobile/test/providers/profile_feed_provider_test.dart`

- [ ] **Step 5: Run targeted verification**

Run: `flutter test test/providers/profile_feed_provider_test.dart`
Expected: PASS

- [ ] **Step 6: Review diff and commit**

```bash
git add docs/superpowers/specs/2026-03-27-profile-grid-pagination-design.md \
        docs/superpowers/plans/2026-03-27-profile-grid-pagination.md \
        mobile/lib/widgets/profile/profile_videos_grid.dart \
        mobile/test/screens/profile_grid_tap_navigation_test.dart
git commit -m "fix(profile): paginate videos grid on scroll"
```
