# OG Viner Badge Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a local, eventually consistent "V" mark beside accounts known to have authored original Vine archive videos.

**Architecture:** Add a positive-only local cache service backed by `SharedPreferences`, expose it through Riverpod, populate it only from archive-backed video loading paths, and render a compact reusable OG Viner badge beside existing account badges. Name rendering reads local state only and never performs a per-user server lookup.

**Tech Stack:** Flutter, Riverpod `ChangeNotifierProvider`, `SharedPreferences`, `VideoEvent.isOriginalVine`, focused Flutter tests.

---

## File Structure

- Create `mobile/lib/services/og_viner_cache_service.dart`
  - Owns the positive-only pubkey set.
  - Loads/stores JSON under `og_viner_pubkeys_v1`.
  - Exposes `isOgViner(pubkey)` and `markFromArchiveVideos(videos)`.

- Create `mobile/lib/providers/og_viner_cache_provider.dart`
  - Provides `OgVinerCacheService` through Riverpod.
  - Uses `sharedPreferencesProvider` in the app.
  - Falls back to an in-memory empty cache only when a narrow widget test has not overridden `sharedPreferencesProvider`.

- Create `mobile/lib/widgets/og_viner_badge.dart`
  - Compact green "V" badge with stable dimensions.

- Modify `mobile/lib/providers/classic_vines_provider.dart`
  - Call `markFromArchiveVideos` after filtered Classic Vines pages are loaded in build, refresh, load more, and fallback.

- Modify `mobile/lib/widgets/user_name.dart`
  - Read the local cache for the effective pubkey and show `OgVinerBadge` beside `SpecialProfileCheckmark`.

- Modify `mobile/lib/widgets/video_feed_item/video_feed_item.dart`
  - Show `OgVinerBadge` beside the feed author name using the same local cache.

- Test `mobile/test/services/og_viner_cache_service_test.dart`
  - Cache loading, corrupt data, positive-only marking, duplicate behavior.

- Test `mobile/test/widgets/user_name_og_viner_badge_test.dart`
  - `UserName` shows the V only for locally known OG Viner pubkeys.

---

## Chunk 1: Local Cache Service

### Task 1: Add OG Viner Cache Service

**Files:**
- Create: `mobile/lib/services/og_viner_cache_service.dart`
- Test: `mobile/test/services/og_viner_cache_service_test.dart`

- [ ] **Step 1: Write failing service tests**

Cover:

```dart
test('loads existing pubkeys from SharedPreferences JSON');
test('ignores corrupt cache data and starts empty');
test('markFromArchiveVideos stores only original Vine video authors');
test('markFromArchiveVideos does not duplicate existing pubkeys');
test('markFromArchiveVideos returns zero and skips writes when nothing changes');
```

Use `SharedPreferences.setMockInitialValues(...)` and `VideoEvent` fixtures with `rawTags: {'platform': 'vine'}` for archive videos.

- [ ] **Step 2: Run service test and verify RED**

Run:

```bash
cd mobile
flutter test test/services/og_viner_cache_service_test.dart
```

Expected: FAIL because `OgVinerCacheService` does not exist.

- [ ] **Step 3: Implement minimal service**

Implement:

```dart
class OgVinerCacheService extends ChangeNotifier {
  OgVinerCacheService({SharedPreferences? prefs}) : _prefs = prefs {
    _load();
  }

  bool isOgViner(String pubkey);
  Future<int> markFromArchiveVideos(Iterable<VideoEvent> videos);
}
```

Persist positive pubkeys as sorted JSON for deterministic tests.

- [ ] **Step 4: Run service test and verify GREEN**

Run:

```bash
cd mobile
flutter test test/services/og_viner_cache_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit cache service**

```bash
git add mobile/lib/services/og_viner_cache_service.dart mobile/test/services/og_viner_cache_service_test.dart
git commit -m "feat: add OG Viner local cache"
```

---

## Chunk 2: Providers And Archive Feed Population

### Task 2: Provide Cache And Populate From Classic Vines

**Files:**
- Create: `mobile/lib/providers/og_viner_cache_provider.dart`
- Modify: `mobile/lib/providers/classic_vines_provider.dart`

- [ ] **Step 1: Write failing provider/feed tests if practical**

Prefer testing the service directly plus a small provider smoke test. If `ClassicVinesFeed` is too expensive to isolate, keep this integration covered by code review and service tests.

- [ ] **Step 2: Add Riverpod provider**

Create `ogVinerCacheServiceProvider` as a `ChangeNotifierProvider<OgVinerCacheService>`.

- [ ] **Step 3: Populate from Classic Vines pages**

In `classic_vines_provider.dart`, after each filtered archive page is built, call:

```dart
unawaited(ref.read(ogVinerCacheServiceProvider).markFromArchiveVideos(videos));
```

Use filtered/restored videos already loaded by the provider. Do not add per-user fetches.

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd mobile
flutter test test/services/og_viner_cache_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit provider/feed integration**

```bash
git add mobile/lib/providers/og_viner_cache_provider.dart mobile/lib/providers/classic_vines_provider.dart
git commit -m "feat: learn OG Viners from classic archive videos"
```

---

## Chunk 3: UI Badge Rendering

### Task 3: Add Badge Widget And Name UI

**Files:**
- Create: `mobile/lib/widgets/og_viner_badge.dart`
- Modify: `mobile/lib/widgets/user_name.dart`
- Modify: `mobile/lib/widgets/video_feed_item/video_feed_item.dart`
- Test: `mobile/test/widgets/user_name_og_viner_badge_test.dart`

- [ ] **Step 1: Write failing widget tests**

Cover:

```dart
testWidgets('UserName shows OG Viner badge for cached pubkey');
testWidgets('UserName hides OG Viner badge for unknown pubkey');
```

Use `SharedPreferences.setMockInitialValues({'og_viner_pubkeys_v1': jsonEncode([pubkey])})`.

- [ ] **Step 2: Run widget test and verify RED**

Run:

```bash
cd mobile
flutter test test/widgets/user_name_og_viner_badge_test.dart
```

Expected: FAIL because `OgVinerBadge` is not rendered.

- [ ] **Step 3: Implement badge widget and UI wiring**

Add a compact badge with semantic label `OG Viner`.

In `UserName`, compute the effective pubkey and watch:

```dart
final isOgViner = ref.watch(
  ogVinerCacheServiceProvider.select((service) {
    return service.isOgViner(effectivePubkey);
  }),
);
```

Render `OgVinerBadge` after the existing `SpecialProfileCheckmark`.

Add the same local-only badge beside the feed author name in `video_feed_item.dart`.

- [ ] **Step 4: Run widget tests and verify GREEN**

Run:

```bash
cd mobile
flutter test test/widgets/user_name_og_viner_badge_test.dart test/widgets/user_name_nip05_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit UI**

```bash
git add mobile/lib/widgets/og_viner_badge.dart mobile/lib/widgets/user_name.dart mobile/lib/widgets/video_feed_item/video_feed_item.dart mobile/test/widgets/user_name_og_viner_badge_test.dart
git commit -m "feat: show OG Viner badge for cached archive authors"
```

---

## Chunk 4: Verification

### Task 4: Focused Verification

**Files:**
- All files changed above.

- [ ] **Step 1: Format touched Dart files**

Run:

```bash
cd mobile
dart format lib/services/og_viner_cache_service.dart lib/providers/og_viner_cache_provider.dart lib/providers/classic_vines_provider.dart lib/widgets/og_viner_badge.dart lib/widgets/user_name.dart lib/widgets/video_feed_item/video_feed_item.dart test/services/og_viner_cache_service_test.dart test/widgets/user_name_og_viner_badge_test.dart
```

- [ ] **Step 2: Run focused tests**

Run:

```bash
cd mobile
flutter test test/services/og_viner_cache_service_test.dart test/widgets/user_name_og_viner_badge_test.dart test/widgets/user_name_nip05_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyzer on touched app files**

Run:

```bash
cd mobile
flutter analyze lib/services/og_viner_cache_service.dart lib/providers/og_viner_cache_provider.dart lib/providers/classic_vines_provider.dart lib/widgets/og_viner_badge.dart lib/widgets/user_name.dart lib/widgets/video_feed_item/video_feed_item.dart
```

Expected: no errors.

- [ ] **Step 4: Review diff**

Run:

```bash
git diff --check HEAD
git diff --stat origin/main...HEAD
```

Expected: no whitespace errors; diff limited to spec, plan, cache, provider, classic feed, badge UI, and tests.

- [ ] **Step 5: Commit final verification fixes if needed**

Commit any formatting or test fixes with a focused message.
