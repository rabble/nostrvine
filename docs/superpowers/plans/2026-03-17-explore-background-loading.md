# Explore Background Loading Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Explore tabs showing existing videos while refresh and invalidation work happens in the background, so only genuinely cold loads show a blocking loader.

**Architecture:** Tighten each Explore provider’s stale-while-revalidate behavior, then update the tab widgets to treat existing `AsyncData` as the primary render path during refresh. Keep the provider-per-tab structure intact.

**Tech Stack:** Flutter, Riverpod, widget tests, provider tests

---

## Chunk 1: Provider Refresh Semantics

### Task 1: Make Explore providers preserve existing data while refreshing

**Files:**
- Modify: `mobile/lib/providers/popular_now_feed_provider.dart`
- Modify: `mobile/lib/providers/popular_videos_feed_provider.dart`
- Modify: `mobile/lib/providers/for_you_provider.dart`
- Test: `mobile/test/providers/popular_now_feed_provider_test.dart`

- [ ] **Step 1: Write the failing provider tests**

```dart
test('refresh preserves existing popular-now videos until replacement data arrives', () async {
  // seed AsyncData state, call refresh(), and assert UI-facing state
  // continues to expose existing videos
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `flutter test test/providers/popular_now_feed_provider_test.dart`

Expected: FAIL or require new coverage because current refresh paths invalidate too destructively.

- [ ] **Step 3: Update provider refresh paths**

```dart
final current = state.valueOrNull;
if (current != null && current.videos.isNotEmpty) {
  state = AsyncData(current.copyWith(isRefreshing: true));
}
```

- [ ] **Step 4: Verify provider tests**

Run: `flutter test test/providers/popular_now_feed_provider_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the provider changes**

```bash
git add mobile/lib/providers/popular_now_feed_provider.dart mobile/lib/providers/popular_videos_feed_provider.dart mobile/lib/providers/for_you_provider.dart mobile/test/providers/popular_now_feed_provider_test.dart
git commit -m "feat(explore): preserve provider data during refresh"
```

## Chunk 2: Tab Rendering Rules

### Task 2: Keep Explore tabs on existing data unless the path is truly cold

**Files:**
- Modify: `mobile/lib/widgets/new_videos_tab.dart`
- Modify: `mobile/lib/widgets/popular_videos_tab.dart`
- Modify: `mobile/lib/widgets/for_you_tab.dart`
- Test: `mobile/test/screens/explore_screen_pull_to_refresh_test.dart`
- Test: `mobile/test/screens/explore_screen_video_display_test.dart`

- [ ] **Step 1: Write the failing widget tests**

```dart
testWidgets(
  'popular tab shows existing grid while provider is refreshing',
  ...
);
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `flutter test test/screens/explore_screen_pull_to_refresh_test.dart test/screens/explore_screen_video_display_test.dart`

Expected: FAIL because loading UI still wins over existing data in the covered path.

- [ ] **Step 3: Update the tab widgets**

```dart
if (feedAsync.hasValue && feedAsync.value!.videos.isNotEmpty) {
  return _buildGrid(feedAsync.value!, isRefreshing: feedAsync.isLoading);
}
```

- [ ] **Step 4: Run the focused suite**

Run: `flutter test test/providers/popular_now_feed_provider_test.dart test/screens/explore_screen_pull_to_refresh_test.dart test/screens/explore_screen_video_display_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the widget behavior**

```bash
git add mobile/lib/widgets/new_videos_tab.dart mobile/lib/widgets/popular_videos_tab.dart mobile/lib/widgets/for_you_tab.dart mobile/test/screens/explore_screen_pull_to_refresh_test.dart mobile/test/screens/explore_screen_video_display_test.dart
git commit -m "feat(explore): prefer cached tab data during background loads"
```
