# Profile Cache-First Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make other-user profiles render from cached or seeded data immediately, then refresh in the background without wiping the visible page.

**Architecture:** Add a session-scoped first-page cache for profile feeds, route profile header rendering through already-owned cached/seeded profile data, and preserve visible content on refresh. Leave the seed manifest and asset import work to the separate classic-viner seed worktree.

**Tech Stack:** Flutter, Riverpod, `flutter_bloc`, Drift-backed profile cache, provider tests, bloc tests

---

## Chunk 1: Header Ownership and Cached Profile Data

### Task 1: Remove split ownership of other-user profile header data

**Files:**
- Modify: `mobile/lib/screens/other_profile_screen.dart`
- Modify: `mobile/lib/blocs/other_profile/other_profile_bloc.dart`
- Modify: `mobile/lib/widgets/profile/profile_header_widget.dart`
- Test: `mobile/test/blocs/other_profile/other_profile_bloc_test.dart`
- Test: `mobile/test/screens/profile_screen_refresh_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets(
  'other-user header uses cached or seeded profile data without waiting for a second fetch',
  ...
);
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `flutter test test/blocs/other_profile/other_profile_bloc_test.dart`

Expected: FAIL for new ownership assertions because the widget still reads `fetchUserProfileProvider(...)` directly.

- [ ] **Step 3: Route header reads through screen-owned state**

```dart
final headerProfile = switch (context.watch<OtherProfileBloc>().state) {
  OtherProfileLoading(:final profile) => profile,
  OtherProfileLoaded(:final profile) => profile,
  OtherProfileError(:final profile) => profile,
  _ => null,
};
```

- [ ] **Step 4: Add cached archived-count fallback for header stats**

Run: `flutter test test/blocs/other_profile/other_profile_bloc_test.dart test/screens/profile_screen_refresh_test.dart`

Expected: PASS

- [ ] **Step 5: Commit the header-ownership change**

```bash
git add mobile/lib/screens/other_profile_screen.dart mobile/lib/blocs/other_profile/other_profile_bloc.dart mobile/lib/widgets/profile/profile_header_widget.dart mobile/test/blocs/other_profile/other_profile_bloc_test.dart mobile/test/screens/profile_screen_refresh_test.dart
git commit -m "feat(profile): render other-user headers from cached state first"
```

## Chunk 2: Session-Cached Profile Feed

### Task 2: Preserve first-page profile feed data across revisits and refreshes

**Files:**
- Create: `mobile/lib/providers/profile_feed_session_cache.dart`
- Modify: `mobile/lib/providers/profile_feed_provider.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/providers/profile_feed_provider_test.dart`
- Test: `mobile/test/providers/profile_feed_providers_test.dart`

- [ ] **Step 1: Write the failing provider tests**

```dart
test('returns retained first-page profile feed immediately before refresh', () async {
  // seed session cache for pubkey, build provider, expect cached videos first
});

test('refresh preserves visible profile feed data while reloading', () async {
  // start from success state, call refresh, and expect no empty feed flash
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run: `flutter test test/providers/profile_feed_provider_test.dart test/providers/profile_feed_providers_test.dart`

Expected: FAIL because first open and refresh remain network-first.

- [ ] **Step 3: Implement the session cache**

```dart
class ProfileFeedSessionCache {
  final _snapshots = <String, VideoFeedState>{};

  VideoFeedState? read(String pubkey) => _snapshots[pubkey];
  void write(String pubkey, VideoFeedState state) => _snapshots[pubkey] = state;
}
```

- [ ] **Step 4: Update `ProfileFeed` to emit cached state first and refresh in background**

Run: `flutter test test/providers/profile_feed_provider_test.dart test/providers/profile_feed_providers_test.dart`

Expected: PASS

- [ ] **Step 5: Run the focused suite**

Run: `flutter test test/providers/profile_feed_provider_test.dart test/providers/profile_feed_providers_test.dart test/blocs/other_profile/other_profile_bloc_test.dart`

Expected: PASS

- [ ] **Step 6: Commit the feed-cache work**

```bash
git add mobile/lib/providers/profile_feed_session_cache.dart mobile/lib/providers/profile_feed_provider.dart mobile/lib/providers/app_providers.dart mobile/test/providers/profile_feed_provider_test.dart mobile/test/providers/profile_feed_providers_test.dart
git commit -m "feat(profile): retain first-page profile feeds in session cache"
```
