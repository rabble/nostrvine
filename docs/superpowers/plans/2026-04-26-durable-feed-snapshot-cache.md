# Durable Feed Snapshot Cache Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable durable feed metadata cache so Home, New Vines, Classics, and Recommendations can restore last known good content immediately on cold app startup.

**Architecture:** Keep the existing video/media cache separate. Add a repository-owned feed snapshot cache under `videos_repository`, backed by Drift/SQLite through `db_client`, with memory cache as L1 and durable snapshots as L2. UI paths should use stale-while-revalidate: show a valid cached snapshot immediately, refresh from Funnelcake/Nostr in the background, and keep cached content visible if refresh fails.

**Tech Stack:** Flutter, Dart, Riverpod, BLoC, Drift/SQLite, `videos_repository`, `db_client`, `models`, Funnelcake REST API, Nostr fallback.

---

## Scope

This plan is for **feed metadata caching**, not media-file caching.

Feed cache answers:

```text
Which videos should this feed show, in what order, with what cursor/offset?
```

Existing media caches answer:

```text
Do we already have the actual playable media bytes on disk?
```

Do not replace or merge with:

- `mobile/lib/services/openvine_media_cache.dart`
- `mobile/packages/media_cache`
- `mobile/packages/divine_video_player`
- `mobile/lib/providers/individual_video_providers.dart`
- `mobile/lib/mixins/video_prefetch_mixin.dart`

## Current Findings To Preserve

- `HomeFeedCache` is a one-off `SharedPreferences` cache with a 1 hour TTL.
  - `mobile/lib/blocs/video_feed/home_feed_cache.dart`
- `InMemoryFeedCache` is intentionally session-scoped and lost on app restart.
  - `mobile/packages/videos_repository/lib/src/in_memory_feed_cache.dart`
- New Vines, Classics, and Recommendations mostly fetch directly from providers, bypassing durable feed snapshots.
  - `mobile/lib/providers/popular_now_feed_provider.dart`
  - `mobile/lib/providers/classic_vines_provider.dart`
  - `mobile/lib/providers/for_you_provider.dart`
- `VideoEvent.toJson()` exists, but there is no generated `VideoEvent.fromJson()`, and generated JSON includes computed fields. Do not use that JSON shape directly for durable snapshots.
  - `mobile/packages/models/lib/src/video_event.dart`
  - `mobile/packages/models/lib/src/video_event.g.dart`
- The repository package already owns feed fetching and has optional local storage injection.
  - `mobile/packages/videos_repository/lib/src/videos_repository.dart`
  - `mobile/packages/videos_repository/lib/src/video_local_storage.dart`
- The app's state-management direction prefers `UI -> BLoC/Cubit -> Repository -> Client`, with Riverpod remaining for legacy/provider wiring.
  - `docs/BLOC_UI_MIGRATION_PRD.md`

## Target File Structure

### New Files

- `mobile/packages/videos_repository/lib/src/feed_cache_key.dart`
  - Stable key model for feed snapshots.
- `mobile/packages/videos_repository/lib/src/feed_cache_policy.dart`
  - Per-feed soft-stale and hard-expiry policy.
- `mobile/packages/videos_repository/lib/src/feed_video_snapshot.dart`
  - Durable DTO for the subset of `VideoEvent` fields needed to restore UI.
- `mobile/packages/videos_repository/lib/src/feed_snapshot.dart`
  - Snapshot model: videos, cursor, metadata, timestamps, source, version.
- `mobile/packages/videos_repository/lib/src/feed_snapshot_store.dart`
  - Abstract read/write/delete interface.
- `mobile/packages/videos_repository/lib/src/db_feed_snapshot_store.dart`
  - `db_client` backed implementation.
- `mobile/packages/videos_repository/test/src/feed_cache_key_test.dart`
- `mobile/packages/videos_repository/test/src/feed_cache_policy_test.dart`
- `mobile/packages/videos_repository/test/src/feed_video_snapshot_test.dart`
- `mobile/packages/videos_repository/test/src/feed_snapshot_store_test.dart`
- `mobile/packages/db_client/lib/src/database/daos/feed_snapshots_dao.dart`
- `mobile/packages/db_client/test/src/database/daos/feed_snapshots_dao_test.dart`

### Modified Files

- `mobile/packages/videos_repository/lib/videos_repository.dart`
  - Export new cache interfaces/models.
- `mobile/packages/videos_repository/lib/src/videos_repository.dart`
  - Inject `FeedSnapshotStore`.
  - Read/write snapshots for initial-page feed requests.
  - Keep `InMemoryFeedCache` as L1.
- `mobile/packages/videos_repository/pubspec.yaml`
  - Add any needed dependency only if unavoidable. Prefer no new dependency.
- `mobile/packages/videos_repository/test/src/videos_repository_test.dart`
  - Add durable-cache behavior tests.
- `mobile/packages/db_client/lib/src/database/tables.dart`
  - Add `FeedSnapshots` Drift table.
- `mobile/packages/db_client/lib/src/database/app_database.dart`
  - Add table and DAO to `@DriftDatabase`.
  - Follow the current guarded missing-table creation pattern in `_createMissingTables()`.
- `mobile/packages/db_client/lib/src/database/app_database.g.dart`
  - Generated.
- `mobile/packages/db_client/lib/src/database/daos/feed_snapshots_dao.g.dart`
  - Generated.
- `mobile/packages/db_client/lib/db_client.dart`
  - Export DAO/table types if needed by app providers.
- `mobile/lib/providers/app_providers.dart`
  - Provide `FeedSnapshotStore` and inject it into `VideosRepository`.
- `mobile/lib/blocs/video_feed/video_feed_bloc.dart`
  - Replace `HomeFeedCache` reads/writes with shared feed snapshot cache.
- `mobile/lib/blocs/video_feed/home_feed_cache.dart`
  - Keep temporarily for migration fallback, then remove in a follow-up PR.
- `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`
  - Update startup-cache tests.
- `mobile/test/blocs/video_feed/home_feed_cache_test.dart`
  - Keep until fallback is removed, or replace with migration tests.
- `mobile/lib/providers/popular_now_feed_provider.dart`
  - Use repository/cache path for New Vines.
- `mobile/lib/providers/classic_vines_provider.dart`
  - Use repository/cache path for Classics.
- `mobile/lib/providers/for_you_provider.dart`
  - Use repository/cache path for Recommendations.
- `mobile/lib/providers/readiness_gate_providers.dart`
  - Fix misleading readiness gating so Nostr fallback does not build before Nostr is ready.

---

## Chunk 1: Cache Models And Policies

### Task 1: Add Feed Cache Key

**Files:**

- Create: `mobile/packages/videos_repository/lib/src/feed_cache_key.dart`
- Test: `mobile/packages/videos_repository/test/src/feed_cache_key_test.dart`

- [ ] **Step 1: Write failing tests**

Test cases:

- Same feed type, user scope, params, and schema version produce the same key.
- Param order does not affect `paramsHash`.
- Different pubkeys produce different keys for user-scoped feeds.
- Anonymous/global feeds use a stable `global` scope.
- Schema version changes produce a different key.

- [ ] **Step 2: Implement `FeedCacheKey`**

Model fields:

```dart
enum FeedCacheType {
  home,
  latest,
  popular,
  classics,
  recommendations,
}

class FeedCacheKey {
  const FeedCacheKey({
    required this.type,
    required this.userScope,
    required this.paramsHash,
    required this.schemaVersion,
  });

  final FeedCacheType type;
  final String userScope;
  final String paramsHash;
  final int schemaVersion;

  String get storageKey =>
      '${type.name}:$schemaVersion:$userScope:$paramsHash';
}
```

Use a deterministic JSON encoding helper for params. Sort map keys before hashing. Use `crypto` only if already available to the package through workspace constraints; otherwise use a small deterministic string hash only if tests prove stable output. Prefer adding `crypto` to `videos_repository` only if necessary.

- [ ] **Step 3: Run tests**

Run:

```bash
cd mobile/packages/videos_repository
flutter test test/src/feed_cache_key_test.dart
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add mobile/packages/videos_repository/lib/src/feed_cache_key.dart \
  mobile/packages/videos_repository/test/src/feed_cache_key_test.dart
git commit -m "feat(videos_repository): add feed cache keys"
```

### Task 2: Add Feed Snapshot DTOs

**Files:**

- Create: `mobile/packages/videos_repository/lib/src/feed_video_snapshot.dart`
- Create: `mobile/packages/videos_repository/lib/src/feed_snapshot.dart`
- Test: `mobile/packages/videos_repository/test/src/feed_video_snapshot_test.dart`

- [ ] **Step 1: Write failing tests**

Test cases:

- `VideoEvent -> FeedVideoSnapshot -> VideoEvent` preserves fields needed by feed UI:
  - `id`, `pubkey`, `createdAt`, `content`, `timestamp`
  - `title`, `videoUrl`, `thumbnailUrl`, `duration`, `dimensions`
  - `mimeType`, `sha256`, `fileSize`
  - `hashtags`, `categories`, `publishedAt`, `rawTags`
  - `vineId`, `group`, `altText`, `blurhash`
  - `originalLoops`, `originalLikes`, `originalComments`, `originalReposts`
  - `nostrLikeCount`, `authorName`, `authorAvatar`
  - `textTrackRef`, `textTrackContent`
  - `contentWarningLabels`, `moderationLabels`, `warnLabels`
- Snapshot parsing drops invalid videos with empty id or empty/missing video URL.
- Unknown JSON fields are ignored.
- Corrupt snapshot JSON returns a cache miss at store/read layer, not a thrown UI error.

- [ ] **Step 2: Implement `FeedVideoSnapshot`**

Use a hand-written DTO. Do not depend on generated `VideoEvent.toJson()` because it includes computed fields and has no matching generated factory.

Provide:

```dart
factory FeedVideoSnapshot.fromVideoEvent(VideoEvent video)
VideoEvent toVideoEvent()
factory FeedVideoSnapshot.fromJson(Map<String, dynamic> json)
Map<String, dynamic> toJson()
bool get isRenderable => id.isNotEmpty && videoUrl != null && videoUrl!.isNotEmpty
```

- [ ] **Step 3: Implement `FeedSnapshot`**

Fields:

```dart
class FeedSnapshot {
  const FeedSnapshot({
    required this.videos,
    required this.fetchedAt,
    required this.staleAt,
    required this.expiresAt,
    required this.source,
    this.cursor,
    this.offset,
    this.hasMore = true,
    this.extra = const {},
  });

  final List<FeedVideoSnapshot> videos;
  final DateTime fetchedAt;
  final DateTime staleAt;
  final DateTime expiresAt;
  final String source;
  final String? cursor;
  final int? offset;
  final bool hasMore;
  final Map<String, Object?> extra;
}
```

Use ISO-8601 UTC strings for timestamps in JSON. Keep `extra` limited to JSON-safe primitive/list/map values.

- [ ] **Step 4: Run tests**

Run:

```bash
cd mobile/packages/videos_repository
flutter test test/src/feed_video_snapshot_test.dart
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/videos_repository/lib/src/feed_video_snapshot.dart \
  mobile/packages/videos_repository/lib/src/feed_snapshot.dart \
  mobile/packages/videos_repository/test/src/feed_video_snapshot_test.dart
git commit -m "feat(videos_repository): add feed snapshot DTOs"
```

### Task 3: Add Cache Policy

**Files:**

- Create: `mobile/packages/videos_repository/lib/src/feed_cache_policy.dart`
- Test: `mobile/packages/videos_repository/test/src/feed_cache_policy_test.dart`

- [ ] **Step 1: Write failing tests**

Test policies:

- Home/following cache can be shown stale, but expires after hard expiry.
- Latest cache has a short soft-stale window.
- Classics hard expiry is long enough to restore last session's slice.
- Recommendations are user-scoped and expire faster than Classics.

- [ ] **Step 2: Implement policies**

Initial defaults:

```text
home: soft stale 30 min, hard expiry 7 days
latest: soft stale 5 min, hard expiry 3 days
popular: soft stale 10 min, hard expiry 3 days
classics: soft stale 24 hours, hard expiry 14 days
recommendations: soft stale 30 min, hard expiry 3 days
```

Key behavior:

- Soft-stale means "show cached content and refresh".
- Hard-expired means "do not show cached content".

- [ ] **Step 3: Run tests**

Run:

```bash
cd mobile/packages/videos_repository
flutter test test/src/feed_cache_policy_test.dart
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add mobile/packages/videos_repository/lib/src/feed_cache_policy.dart \
  mobile/packages/videos_repository/test/src/feed_cache_policy_test.dart
git commit -m "feat(videos_repository): add feed cache policies"
```

---

## Chunk 2: Drift Storage

### Task 4: Add Feed Snapshots Table And DAO

**Files:**

- Modify: `mobile/packages/db_client/lib/src/database/tables.dart`
- Modify: `mobile/packages/db_client/lib/src/database/app_database.dart`
- Create: `mobile/packages/db_client/lib/src/database/daos/feed_snapshots_dao.dart`
- Test: `mobile/packages/db_client/test/src/database/daos/feed_snapshots_dao_test.dart`
- Generated: `mobile/packages/db_client/lib/src/database/app_database.g.dart`
- Generated: `mobile/packages/db_client/lib/src/database/daos/feed_snapshots_dao.g.dart`

- [ ] **Step 1: Write failing DAO tests**

Test cases:

- `upsertSnapshot` writes a snapshot row.
- Writing the same `cache_key` replaces the row.
- `getSnapshot(cacheKey)` returns the latest row and updates `last_accessed_at`.
- `deleteSnapshot(cacheKey)` removes one row.
- `deleteExpired(now)` removes only rows where `expires_at < now`.
- `clearByUserScope(userScope)` removes user-scoped snapshots on logout/account switch.

- [ ] **Step 2: Add Drift table**

Add a table similar to:

```dart
@DataClassName('FeedSnapshotRow')
class FeedSnapshots extends Table {
  @override
  String get tableName => 'feed_snapshots';

  TextColumn get cacheKey => text().named('cache_key')();
  TextColumn get feedType => text().named('feed_type')();
  TextColumn get userScope => text().named('user_scope')();
  TextColumn get paramsHash => text().named('params_hash')();
  IntColumn get schemaVersion => integer().named('schema_version')();
  TextColumn get payloadJson => text().named('payload_json')();
  DateTimeColumn get fetchedAt => dateTime().named('fetched_at')();
  DateTimeColumn get staleAt => dateTime().named('stale_at')();
  DateTimeColumn get expiresAt => dateTime().named('expires_at')();
  DateTimeColumn get lastAccessedAt =>
      dateTime().named('last_accessed_at')();

  @override
  Set<Column> get primaryKey => {cacheKey};

  List<Index> get indexes => [
    Index(
      'idx_feed_snapshots_type_scope',
      'CREATE INDEX IF NOT EXISTS idx_feed_snapshots_type_scope '
      'ON feed_snapshots (feed_type, user_scope)',
    ),
    Index(
      'idx_feed_snapshots_expires_at',
      'CREATE INDEX IF NOT EXISTS idx_feed_snapshots_expires_at '
      'ON feed_snapshots (expires_at)',
    ),
  ];
}
```

- [ ] **Step 3: Register table and DAO**

Update `@DriftDatabase` in `app_database.dart` to include:

- `FeedSnapshots`
- `FeedSnapshotsDao`

Follow the existing project pattern in `_createMissingTables()` by adding a guarded `CREATE TABLE feed_snapshots` and index creation for existing installs. Do not silently drop existing data. If the team decides to bump `schemaVersion`, add a proper `onUpgrade` path and migration tests in the same task.

- [ ] **Step 4: Implement DAO**

Required methods:

```dart
Future<FeedSnapshotRow?> getSnapshot(String cacheKey)
Future<void> upsertSnapshot(FeedSnapshotsCompanion row)
Future<int> deleteSnapshot(String cacheKey)
Future<int> deleteExpired(DateTime now)
Future<int> clearByUserScope(String userScope)
Future<int> clearAll()
```

- [ ] **Step 5: Generate Drift code**

Run:

```bash
cd mobile/packages/db_client
dart run build_runner build --delete-conflicting-outputs
```

Expected: generated files update without conflicts.

- [ ] **Step 6: Run db_client tests**

Run:

```bash
cd mobile/packages/db_client
flutter test test/src/database/daos/feed_snapshots_dao_test.dart
flutter test
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add mobile/packages/db_client/lib/src/database/tables.dart \
  mobile/packages/db_client/lib/src/database/app_database.dart \
  mobile/packages/db_client/lib/src/database/app_database.g.dart \
  mobile/packages/db_client/lib/src/database/daos/feed_snapshots_dao.dart \
  mobile/packages/db_client/lib/src/database/daos/feed_snapshots_dao.g.dart \
  mobile/packages/db_client/test/src/database/daos/feed_snapshots_dao_test.dart
git commit -m "feat(db_client): add feed snapshot storage"
```

### Task 5: Add DbFeedSnapshotStore

**Files:**

- Create: `mobile/packages/videos_repository/lib/src/feed_snapshot_store.dart`
- Create: `mobile/packages/videos_repository/lib/src/db_feed_snapshot_store.dart`
- Modify: `mobile/packages/videos_repository/lib/videos_repository.dart`
- Test: `mobile/packages/videos_repository/test/src/feed_snapshot_store_test.dart`

- [ ] **Step 1: Write failing store tests**

Use a fake DAO or mock storage boundary. Test:

- Store returns `null` for missing row.
- Store returns `null` for expired row.
- Store returns stale snapshot when past `staleAt` but before `expiresAt`.
- Store treats corrupt JSON as a miss and deletes or ignores it.
- Store writes payload JSON with cache key metadata.

- [ ] **Step 2: Implement abstract store**

```dart
class FeedSnapshotRead {
  const FeedSnapshotRead({
    required this.snapshot,
    required this.isStale,
  });

  final FeedSnapshot snapshot;
  final bool isStale;
}

abstract class FeedSnapshotStore {
  Future<FeedSnapshotRead?> read(FeedCacheKey key);
  Future<void> write(FeedCacheKey key, FeedSnapshot snapshot);
  Future<void> delete(FeedCacheKey key);
  Future<int> clearExpired();
  Future<int> clearUserScope(String userScope);
}
```

- [ ] **Step 3: Implement DB-backed store**

`DbFeedSnapshotStore` should depend on the DAO, not on app UI or providers.

Log or expose errors only at repository boundary. Store parsing failures should not crash feed startup.

- [ ] **Step 4: Export store interfaces**

Update `mobile/packages/videos_repository/lib/videos_repository.dart`.

- [ ] **Step 5: Run tests**

Run:

```bash
cd mobile/packages/videos_repository
flutter test test/src/feed_snapshot_store_test.dart
```

Expected: pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/videos_repository/lib/src/feed_snapshot_store.dart \
  mobile/packages/videos_repository/lib/src/db_feed_snapshot_store.dart \
  mobile/packages/videos_repository/lib/videos_repository.dart \
  mobile/packages/videos_repository/test/src/feed_snapshot_store_test.dart
git commit -m "feat(videos_repository): add durable feed snapshot store"
```

---

## Chunk 3: Repository Integration

### Task 6: Wire Store Into VideosRepository

**Files:**

- Modify: `mobile/packages/videos_repository/lib/src/videos_repository.dart`
- Modify: `mobile/packages/videos_repository/test/src/videos_repository_test.dart`

- [ ] **Step 1: Add failing repository tests**

Test cases:

- `getHomeFeedVideos` initial page writes durable snapshot after fresh fetch.
- `getNewVideos` initial page writes durable snapshot after fresh fetch.
- Pagination requests do not read durable first-page snapshot.
- `skipCache: true` bypasses L1/L2 reads but still writes fresh successful result.
- Network failure after cached content is already used does not delete snapshot.
- Content preferences are applied after reading snapshot.

- [ ] **Step 2: Inject `FeedSnapshotStore`**

Add optional constructor args:

```dart
FeedSnapshotStore? feedSnapshotStore,
DateTime Function()? clock,
```

Keep `InMemoryFeedCache` as L1.

- [ ] **Step 3: Add repository cache helpers**

Add private helpers:

```dart
Future<HomeFeedResult?> _readDurableFeed(FeedCacheKey key)
Future<void> _writeDurableFeed(...)
FeedCacheKey _homeFeedKey(...)
FeedCacheKey _latestFeedKey(...)
FeedCacheKey _popularFeedKey(...)
```

Do not make providers compute storage keys manually. Providers should pass semantic params to repository methods.

- [ ] **Step 4: Integrate Home, Latest, Popular**

Initial-page flow:

1. If `skipCache == false`, check L1 memory.
2. If L1 misses, check L2 durable snapshot.
3. If L2 hit, return cached result quickly.
4. Caller can force network refresh with `skipCache: true`.
5. Successful fresh initial-page fetch writes L1 and L2.

Note: this step alone returns cached content instead of network content for existing Future-returning methods. BLoC/provider stale-while-revalidate integration comes in later tasks so cached content is followed by background refresh.

- [ ] **Step 5: Add logs**

Use existing `Log` only if accessible from package. If package should not depend on app logger, expose cache status in result or use `dart:developer` sparingly. Required messages at app boundary:

```text
feed_cache hit feed=latest age=... videos=...
feed_cache stale feed=home age=... videos=... revalidating=true
feed_cache miss feed=classics reason=no_entry
feed_cache expired feed=recommendations age=...
feed_cache write feed=home videos=... source=funnelcake
```

- [ ] **Step 6: Run repository tests**

Run:

```bash
cd mobile/packages/videos_repository
flutter test test/src/videos_repository_test.dart
flutter test --coverage
```

Expected: pass and coverage remains acceptable for this package.

- [ ] **Step 7: Commit**

```bash
git add mobile/packages/videos_repository/lib/src/videos_repository.dart \
  mobile/packages/videos_repository/test/src/videos_repository_test.dart
git commit -m "feat(videos_repository): use durable cache for core feeds"
```

### Task 7: Add Classics And Recommendations Repository Methods

**Files:**

- Modify: `mobile/packages/videos_repository/lib/src/videos_repository.dart`
- Modify: `mobile/packages/videos_repository/test/src/videos_repository_test.dart`

- [ ] **Step 1: Write failing tests for Classics**

Tests:

- First `getClassicVideos` fetch chooses provided offset and writes snapshot.
- Cached Classics restore the same order and offset.
- Refresh with `forceNewSlice: true` chooses a new offset and overwrites snapshot.
- Load-more does not replace first-page snapshot incorrectly.

- [ ] **Step 2: Write failing tests for Recommendations**

Tests:

- Recommendations cache is keyed by user pubkey.
- Different users do not share recommendations snapshots.
- Different category/fallback params do not collide.
- Recommendations source is preserved in snapshot metadata.

- [ ] **Step 3: Implement methods**

Add methods similar to:

```dart
Future<HomeFeedResult> getClassicVideos({
  int limit = 100,
  int? offset,
  bool forceNewSlice = false,
  bool skipCache = false,
})

Future<HomeFeedResult> getRecommendedVideos({
  required String pubkey,
  int limit = 50,
  String fallback = 'popular',
  String? category,
  bool skipCache = false,
})
```

Return `HomeFeedResult` for consistency even if list attribution is empty.

For Classics, store `offset` and a deterministic shuffle seed in snapshot `extra`. Use the same seed to restore order after restart. Pull-to-refresh should deliberately generate a new seed/offset.

- [ ] **Step 4: Run tests**

Run:

```bash
cd mobile/packages/videos_repository
flutter test test/src/videos_repository_test.dart
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/videos_repository/lib/src/videos_repository.dart \
  mobile/packages/videos_repository/test/src/videos_repository_test.dart
git commit -m "feat(videos_repository): cache classics and recommendations"
```

---

## Chunk 4: App Wiring And UI Behavior

### Task 8: Provide FeedSnapshotStore To The App

**Files:**

- Modify: `mobile/lib/providers/app_providers.dart`
- Modify: `mobile/lib/providers/app_providers.g.dart`

- [ ] **Step 1: Add provider**

Add a keepAlive provider near `videoLocalStorageProvider`:

```dart
@Riverpod(keepAlive: true)
FeedSnapshotStore feedSnapshotStore(Ref ref) {
  final db = ref.watch(databaseProvider);
  return DbFeedSnapshotStore(dao: db.feedSnapshotsDao);
}
```

- [ ] **Step 2: Inject into repository**

Update `videosRepositoryProvider` to pass:

```dart
feedSnapshotStore: ref.watch(feedSnapshotStoreProvider),
```

- [ ] **Step 3: Generate Riverpod code**

Run:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

Expected: `app_providers.g.dart` updates.

- [ ] **Step 4: Run targeted app provider tests or analyze**

Run:

```bash
cd mobile
flutter analyze
```

Expected: no new analyzer errors.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/app_providers.dart \
  mobile/lib/providers/app_providers.g.dart
git commit -m "feat(feed): inject durable feed snapshot store"
```

### Task 9: Replace HomeFeedCache With Shared Cache Path

**Files:**

- Modify: `mobile/lib/blocs/video_feed/video_feed_bloc.dart`
- Modify: `mobile/test/blocs/video_feed/video_feed_bloc_test.dart`
- Keep temporarily: `mobile/lib/blocs/video_feed/home_feed_cache.dart`
- Keep temporarily: `mobile/test/blocs/video_feed/home_feed_cache_test.dart`

- [ ] **Step 1: Add failing BLoC tests**

Tests:

- First load emits durable cached home videos immediately.
- After cached emit, fresh network result replaces videos.
- If fresh network fails, cached videos remain visible.
- Expired durable cache is not emitted.
- `skipCache: true` refresh bypasses cache read.
- The legacy `HomeFeedCache` fallback is used only if durable cache misses and SharedPreferences contains old data.

- [ ] **Step 2: Update BLoC load flow**

In `_loadVideos`:

1. Read durable cached snapshot through repository/helper for home/following/forYou.
2. Emit cached videos if present and renderable.
3. Continue network refresh with `skipCache: true`.
4. On successful fresh fetch, repository writes durable snapshot.
5. On failure, do not emit failure if cached videos are already visible.

- [ ] **Step 3: Add legacy migration fallback**

For one release cycle:

- If durable home snapshot misses, read old `HomeFeedCache`.
- If old cache returns videos, emit them and write them into durable snapshot.
- Leave old SharedPreferences keys untouched unless a product decision says to clear them.

- [ ] **Step 4: Run BLoC tests**

Run:

```bash
cd mobile
flutter test test/blocs/video_feed/video_feed_bloc_test.dart
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/blocs/video_feed/video_feed_bloc.dart \
  mobile/test/blocs/video_feed/video_feed_bloc_test.dart
git commit -m "feat(feed): restore home feed from durable snapshots"
```

### Task 10: Move New Vines To Repository Cache Path

**Files:**

- Modify: `mobile/lib/providers/popular_now_feed_provider.dart`
- Modify or add tests under: `mobile/test/providers/`

- [ ] **Step 1: Add failing provider tests**

Tests:

- Provider returns cached New Vines state immediately when durable snapshot exists.
- Provider triggers background refresh after returning cached state.
- Failed refresh keeps cached videos visible and sets non-fatal error only if the current UI supports it.
- Pull-to-refresh bypasses cache and updates snapshot.

- [ ] **Step 2: Replace direct REST initial load**

For Funnelcake available path, use repository:

```dart
videosRepository.getNewVideos(...)
```

or add a repository method that returns `HomeFeedResult` for latest feed with cache metadata.

Do not duplicate cache key construction in the provider.

- [ ] **Step 3: Preserve Nostr fallback**

If REST is unavailable and Nostr fallback is needed, do not start Nostr subscription before Nostr is ready. See Task 13.

- [ ] **Step 4: Run tests**

Run:

```bash
cd mobile
flutter test test/providers
```

Expected: relevant provider tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/popular_now_feed_provider.dart \
  mobile/test/providers
git commit -m "feat(feed): restore new vines from durable snapshots"
```

### Task 11: Move Classics To Repository Cache Path

**Files:**

- Modify: `mobile/lib/providers/classic_vines_provider.dart`
- Modify or add tests under: `mobile/test/providers/`

- [ ] **Step 1: Add failing provider tests**

Tests:

- Startup restores last Classics snapshot with same video order.
- Startup does not choose a new random offset when a valid snapshot exists.
- Pull-to-refresh chooses a new offset and overwrites the snapshot.
- Load-more appends next page based on restored offset.

- [ ] **Step 2: Update provider**

Use repository `getClassicVideos`.

Important behavior:

- `build()` may restore cached Classics.
- `refresh()` must intentionally generate a new slice.
- `loadMore()` must use the restored/current offset from state or repository metadata.

- [ ] **Step 3: Run tests**

Run:

```bash
cd mobile
flutter test test/providers
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/providers/classic_vines_provider.dart \
  mobile/test/providers
git commit -m "feat(feed): restore classics from durable snapshots"
```

### Task 12: Move Recommendations To Repository Cache Path

**Files:**

- Modify: `mobile/lib/providers/for_you_provider.dart`
- Modify or add tests under: `mobile/test/providers/`

- [ ] **Step 1: Add failing provider tests**

Tests:

- Recommendations restore by current user pubkey.
- User A cache is not shown for User B.
- Cached recommendations render while refresh runs.
- If recommendations endpoint is unavailable, valid cached recommendations may still show with stale state.

- [ ] **Step 2: Update provider**

Use repository `getRecommendedVideos`.

Keep source metadata from `RecommendationsResponse.source` in snapshot `extra`, even if the UI does not display it yet.

- [ ] **Step 3: Run tests**

Run:

```bash
cd mobile
flutter test test/providers
```

Expected: pass.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/providers/for_you_provider.dart \
  mobile/test/providers
git commit -m "feat(feed): restore recommendations from durable snapshots"
```

### Task 13: Fix Readiness Gate For Nostr Fallback

**Files:**

- Modify: `mobile/lib/providers/readiness_gate_providers.dart`
- Modify generated: `mobile/lib/providers/readiness_gate_providers.g.dart`
- Test: add or update provider tests if present.

- [ ] **Step 1: Write failing test**

Test:

- `appReadyProvider` or a new Nostr-specific provider is false when foregrounded but Nostr is not ready.
- REST-backed feed restoration is not blocked by Nostr readiness.
- Nostr fallback subscription waits for Nostr readiness.

- [ ] **Step 2: Split readiness concepts**

Avoid making all feed cache restoration wait on Nostr. Use two gates:

```text
appForegroundReady: foreground only
nostrSubscriptionReady: foreground && isNostrReadyProvider
```

Providers using REST or durable cache can build while Nostr is not ready. Providers starting Nostr subscriptions should wait for `nostrSubscriptionReady`.

- [ ] **Step 3: Generate Riverpod code**

Run:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run targeted tests/analyze**

Run:

```bash
cd mobile
flutter analyze
```

Expected: no new analyzer errors.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/readiness_gate_providers.dart \
  mobile/lib/providers/readiness_gate_providers.g.dart
git commit -m "fix(feed): gate nostr fallback on nostr readiness"
```

---

## Chunk 5: Cleanup, Observability, And Verification

### Task 14: Add Cache Logs And Startup Metrics

**Files:**

- Modify relevant repository/provider/BLoC files from earlier tasks.
- Optional: `mobile/lib/services/feed_performance_tracker.dart`

- [ ] **Step 1: Add logs for every feed cache decision**

Required log events:

```text
feed_cache hit feed=<type> age=<duration> videos=<count>
feed_cache stale feed=<type> age=<duration> videos=<count> revalidating=true
feed_cache miss feed=<type> reason=<no_entry|expired|parse_error|wrong_scope>
feed_cache write feed=<type> videos=<count> source=<funnelcake|nostr|recommendations>
feed_cache refresh_failed feed=<type> keeping_cached=true error=<message>
```

Do not truncate Nostr IDs in logs. Use full IDs if logged.

- [ ] **Step 2: Add startup timing markers**

Feed startup should distinguish:

```text
first_cached_videos_received
first_fresh_videos_received
feed_displayed_from_cache
feed_displayed_from_network
```

- [ ] **Step 3: Validate with current log scenario**

Manual run should no longer show New Vines and Classics waiting from zero if a valid snapshot exists.

- [ ] **Step 4: Commit**

```bash
git add <only files modified for logging>
git commit -m "chore(feed): log feed cache startup decisions"
```

### Task 15: Remove Or Deprecate HomeFeedCache

**Files:**

- Delete or deprecate: `mobile/lib/blocs/video_feed/home_feed_cache.dart`
- Delete or deprecate: `mobile/test/blocs/video_feed/home_feed_cache_test.dart`
- Modify imports in `mobile/lib/blocs/video_feed/video_feed_bloc.dart`

- [ ] **Step 1: Decide removal timing**

If this branch includes legacy migration fallback, do not delete `HomeFeedCache` yet. Instead add a TODO with issue/PR reference and remove it in a follow-up after one release cycle.

If migration fallback is not needed, remove it in this task.

- [ ] **Step 2: Run targeted tests**

Run:

```bash
cd mobile
flutter test test/blocs/video_feed/video_feed_bloc_test.dart
```

Expected: pass.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/blocs/video_feed/video_feed_bloc.dart \
  mobile/lib/blocs/video_feed/home_feed_cache.dart \
  mobile/test/blocs/video_feed/home_feed_cache_test.dart
git commit -m "refactor(feed): retire legacy home feed cache"
```

Only stage files that still exist. If deleting, use `git rm`.

### Task 16: Full Verification

**Files:** none unless failures require fixes.

- [ ] **Step 1: Run generated-code check**

Run:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
git status --short
```

Expected: no stale generated files beyond intentional changes.

- [ ] **Step 2: Run package tests**

Run:

```bash
cd mobile/packages/db_client
flutter test

cd ../videos_repository
flutter test --coverage
```

Expected: pass.

- [ ] **Step 3: Run app targeted tests**

Run:

```bash
cd mobile
flutter test test/blocs/video_feed/video_feed_bloc_test.dart
flutter test test/providers
```

Expected: pass.

- [ ] **Step 4: Run analyzer**

Run:

```bash
cd mobile
flutter analyze
```

Expected: no new analyzer errors.

- [ ] **Step 5: Manual startup validation**

Manual validation:

1. Launch app and let Home, New Vines, Classics, and Recommendations load.
2. Close/restart app.
3. Confirm cached snapshots display immediately for valid feeds.
4. Confirm network refresh replaces cached content when fresh results arrive.
5. Confirm media cache still serves cached files independently.
6. Confirm logs show feed cache hit/stale/write decisions.

- [ ] **Step 6: Final commit if any fixes were needed**

```bash
git add <only relevant files>
git commit -m "test(feed): verify durable feed cache behavior"
```

---

## PR Notes

Suggested PR title:

```text
feat(feed): add durable feed snapshot cache
```

Suggested PR summary:

```markdown
## Summary
- Add a reusable durable feed snapshot cache backed by Drift.
- Restore Home, New Vines, Classics, and Recommendations from last known good feed metadata on startup.
- Keep media/video file caching separate and unchanged.
- Add cache hit/stale/miss/write logs for startup debugging.

## Testing
- flutter test from mobile/packages/db_client
- flutter test --coverage from mobile/packages/videos_repository
- flutter test test/blocs/video_feed/video_feed_bloc_test.dart from mobile
- flutter test test/providers from mobile
- flutter analyze from mobile
```

## Risks

- Feed snapshots can become stale. Mitigation: soft-stale renders cached content but refreshes in background; hard-expiry prevents very old content from showing.
- User-scoped cache leakage would be serious. Mitigation: include full pubkey user scope in cache keys and add explicit tests for account switching.
- Classics currently randomizes every build. Mitigation: cache the selected offset and shuffle seed so startup restores continuity, while pull-to-refresh still intentionally randomizes.
- Drift schema changes need generated files. Mitigation: run build_runner and commit generated output.
- Current checkout may contain unrelated dirty files. Mitigation: implement this in a fresh worktree from up-to-date `main`, stage only relevant files.

## Out Of Scope

- Changing video/media byte caching.
- Rewriting all Riverpod feed providers to BLoC in the same PR.
- Changing Funnelcake API contracts.
- Changing Nostr event shapes.
