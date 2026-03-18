# Explore Background Loading Design

**Problem**

Explore providers are already `keepAlive`, but first-open and refresh paths can still feel loading-heavy. The providers and tabs are not uniformly stale-while-revalidate, which means existing data is not always treated as the primary UI while background work happens.

**Goals**

- Keep Explore tabs showing existing data during refresh and provider invalidation.
- Minimize full-screen loading states to truly cold paths.
- Preserve existing provider ownership instead of introducing a new global feed manager.

**Non-Goals**

- Replace all Explore providers with BLoC in this worktree.
- Change sort logic or backend selection.
- Fix Home feed lifecycle in this branch.

**Current Code References**

- `mobile/lib/providers/popular_now_feed_provider.dart`
- `mobile/lib/providers/popular_videos_feed_provider.dart`
- `mobile/lib/providers/for_you_provider.dart`
- `mobile/lib/widgets/new_videos_tab.dart`
- `mobile/lib/widgets/popular_videos_tab.dart`
- `mobile/lib/widgets/for_you_tab.dart`
- `mobile/test/providers/popular_now_feed_provider_test.dart`

**Proposed Design**

1. Normalize provider refresh behavior.
   - If a provider already has non-empty `AsyncData`, `refresh()` and invalidations should preserve that data until replacement results arrive.
   - Cold builds with no data still show loading normally.

2. Normalize tab rendering behavior.
   - Tabs should prefer existing `AsyncValue.value` while background loads run.
   - Full-screen loaders should only appear when a tab truly has no data yet.

3. Keep per-provider logic local.
   - Each provider remains responsible for its own pagination and enrichment.
   - Avoid introducing a new shared abstraction unless duplication becomes blocking during implementation.

**File Boundaries**

- Provider behavior:
  - `mobile/lib/providers/popular_now_feed_provider.dart`
  - `mobile/lib/providers/popular_videos_feed_provider.dart`
  - `mobile/lib/providers/for_you_provider.dart`
- Widget behavior:
  - `mobile/lib/widgets/new_videos_tab.dart`
  - `mobile/lib/widgets/popular_videos_tab.dart`
  - `mobile/lib/widgets/for_you_tab.dart`

**Verification**

- Provider tests for refresh-with-data and appReady/background preservation.
- Widget tests for tab rendering decisions.
- Focused suite:
  - `flutter test test/providers/popular_now_feed_provider_test.dart test/screens/explore_screen_pull_to_refresh_test.dart`

**Risks**

- Reusing stale data too aggressively can make tab state feel “stuck”.
- The three providers are not identical, so over-sharing code can create regressions.
- Widget loading logic can accidentally mask genuine errors if `hasValue` is used carelessly.
