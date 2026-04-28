# Architecture Issues

Issues related to layer violations, dependency direction, state management patterns, and project organization.

Note: The layered architecture (`UI → BLoC → Repository → Client`) is established in 42 BLoC directories and packages like `videos_repository` and `comments_repository`. These issues cover the structural gaps — primarily the 140-file `services/` directory that bypasses the BLoC layer, three concurrent state management patterns, and missing documentation for data source and caching strategy.

---

### VideoEvent is a 1,500-line model with embedded business logic
**Problem**: `VideoEvent` has ~70 fields, URL scoring algorithms, and 46 `developer.log` calls with emoji prefixes that run in production.

**Evidence**: `mobile/packages/models/lib/src/video_event.dart`: 1,502 lines total. 46 `developer.log` calls (lines 91–619). URL scoring logic `_scoreVideoUrl` (lines 1360–1413). URL selection logic `_selectBestVideoUrl` (lines 1417–1444). URL extraction `_extractVideoUrlFromContent` (lines 1447–1466). The URL resolution logic is business logic embedded in a data model, violating single-responsibility.

**Done well**: `SocialCounts` (`mobile/packages/models/lib/src/social_counts.dart`, 46 lines) and `ActorInfo` (`mobile/packages/models/lib/src/actor_info.dart`, 25 lines) demonstrate properly scoped, single-responsibility models in the same package.

**Impact**: High. Debug logging runs in production wasting CPU on every video event parse; URL resolution is business logic that should be in a utility or repository; the size makes the class hard to maintain and test.

**Effort**: Medium. Extract URL resolution into a separate utility class. Remove or gate the `developer.log` calls behind a debug flag. Consider splitting the model's factory method into a dedicated parser.

**GitHub ticket**: TBD

---

### Schema stuck at version 1 with ad-hoc migration logic
**Problem**: The database schema version is permanently 1 while new tables and columns are added via `_createMissingTables()` which runs raw SQL on every app startup, bypassing Drift's built-in migration framework.

**Evidence**: `mobile/packages/db_client/lib/src/database/app_database.dart` line 62: `int get schemaVersion => 1;`. Lines 84–417: `_createMissingTables()` contains ~330 lines of raw `customStatement` SQL for 8+ tables and 20+ `ALTER TABLE ADD COLUMN` operations, all running on `beforeOpen`. This approach: (1) runs 50+ SQL statements on every cold start, (2) cannot be tested incrementally, (3) makes rollback impossible, (4) uses N+1 `PRAGMA table_info` queries per column check, (5) provides no way to know which "version" a given device is at.

**Impact**: High. Performance cost on every cold start; untestable migrations; risk of silent failures if a `customStatement` fails mid-migration.

**Related**: See "Startup cleanup runs synchronously on every cold start" in [issues-performance.md](issues-performance.md), which covers the performance angle of this same `beforeOpen` hook.

**Effort**: High. Migrating to proper schema versioning requires numbering the current state as a base version, writing incremental migration callbacks for future changes, and carefully handling the transition for existing users at arbitrary intermediate states.

**GitHub ticket**: TBD

---

### `services/` directory has no layer identity
**Problem**: 140 files mixing repositories, clients, utilities, and business logic in one flat directory.

**Evidence**: `mobile/lib/services/` contains ~138 files across auth (~15 files), video pipeline (~20), content moderation (~10), notifications (~10), analytics/observability (~9), upload (~3), relay/nostr (~8), preferences (~6), and misc utilities (~20+). BLoCs import services directly (30+ imports: `CommentsBloc` imports `AuthService`, `ContentBlocklistService`, `ContentReportingService`, `ContentModerationService`). Widgets/screens also import services directly (40+ screen files, 40+ widget files), creating a bypass around the BLoC layer. The largest files (`video_event_service.dart` at 5,652 lines, `auth_service.dart` at 4,223 lines, `upload_manager.dart` at 2,720 lines) are de facto repositories that belong in `packages/`.

**Done well**: `videos_repository`, `comments_repository`, and `categories_repository` are well-structured packages with barrel files, DI-friendly constructors, and dedicated tests, the pattern that services should migrate toward.

**Impact**: High. Creates a bypass around the BLoC layer; widgets and screens import services directly, leaking business logic into the UI. Every service change can ripple into both BLoC and UI layers simultaneously.

**Effort**: High. Requires classifying all ~138 files by VGV layer (Client/Repository/Utility), extracting repository and client packages incrementally, and updating all import sites.

**Related**: Each extracted package should ship with tests in the same PR. 50+ services currently have zero test coverage (see [issues-testing.md](issues-testing.md)), and the VGV per-package CI template enforces coverage, so extraction is the natural moment to add tests rather than treating it as separate work.

**GitHub ticket**: TBD

---

### UI bypasses the BLoC layer
**Problem**: 40+ widget and 40+ screen files import services directly instead of going through BLoCs. Additionally, 13 screen files perform filtering, sorting, or data transformation directly in `build()` methods instead of the BLoC/Cubit layer.

**Evidence**: `share_video_menu.dart` (2,864 lines) imports `BookmarkService`, `ContentDeletionService`, `ContentModerationService`, `SocialService` as a `ConsumerStatefulWidget`. `explore_screen.dart` (1,229 lines) imports `ErrorAnalyticsTracker`, `FeedPerformanceTracker`, `ScreenAnalyticsService`, `TopHashtagsService`. `video_feed_page.dart` (1,032 lines) imports `FeedPerformanceTracker`, `StartupPerformanceService`. `app_lifecycle_handler.dart` imports `AuthService`, `BackgroundActivityManager`, `FeedPerformanceTracker`, `ScreenAnalyticsService`. `pooled_fullscreen_video_feed_screen.dart` imports `FeedPerformanceTracker`, `OpenvineMediaCache`, `ViewEventPublisher`.

Beyond direct service imports, 13 screens perform data transformation logic inside `build()`: `explore_screen.dart` calls `videoEventService.filterVideoList(ref.watch(exploreTabVideosProvider))` inside the build method, a service-level filter operation that should live in a BLoC. `creator_analytics_screen.dart` performs chart data transformation in build. `content_filters_screen.dart` manipulates filter lists during build. `relay_diagnostic_screen.dart`, `developer_options_screen.dart`, `safety_settings_screen.dart`, `app_language_screen.dart`, `message_requests_view.dart`, `video_clip_editor_screen.dart`, and `sounds_screen.dart` also contain data transformation logic in build methods. The project's own `architecture.md` rule states: "filtering, sorting, data transformation must NOT live in widgets."

**Done well**: `CategoriesBloc` (`mobile/lib/blocs/categories/categories_bloc.dart`) depends only on `CategoriesRepository` with no direct service imports. `ProfileLikedVideosBloc` orchestrates two repositories cleanly. These demonstrate the correct BLoC -> Repository -> Client flow.

**Impact**: High. Business logic leaks into widgets; service changes ripple into both BLoC and UI layers simultaneously; widgets become untestable without service mocks. Build methods run frequently (every frame during animations), so data transformation in build also wastes CPU cycles on re-computation.

**Effort**: High. Each widget/screen needs a BLoC or Cubit intermediary. For analytics/cross-cutting services, consider a `BlocObserver` or dedicated analytics middleware that observes state transitions rather than being called from widgets. For filtering/sorting in build, extract the logic into the corresponding BLoC or Cubit with the result stored in state. Priority: `explore_screen.dart` (highest traffic screen with service call in build).

**GitHub ticket**: TBD

---

### Three concurrent state management patterns
**Problem**: Riverpod (176 files), BLoC (125 files), and ChangeNotifier/ValueNotifier (49 files) coexist in the app layer. ChangeNotifier is not tracked in the migration plan.

**Evidence**: Riverpod: 176 files using `ConsumerWidget`/`ConsumerStatefulWidget`/`HookConsumerWidget` (128 Consumer widgets in screens with 385 `ref.watch/read` calls, 141 in widgets with 300 calls). BLoC: 125 files using `BlocBuilder`/`BlocProvider`/`BlocListener`/`context.read`/`context.watch`/`context.select`, 42 BLoC directories. ChangeNotifier/ValueNotifier/StateNotifier: 49 files not acknowledged in the BLoC migration PRD. Key Riverpod files: `app_providers.dart` (2,500 lines), `individual_video_providers.dart` (1,434), `video_recorder_provider.dart` (1,182), `relay_notifications_provider.dart` (1,102).

**Done well**: The 42 BLoC directories with 61 test files show the target pattern is well-established and well-tested. `features/feature_flags/` demonstrates a complete BLoC-based feature end to end.

**Impact**: High. Developers must reason about three patterns simultaneously; the 49 ChangeNotifier files represent untracked migration scope. Note: ChangeNotifier is acceptable in framework-agnostic packages (e.g., `pooled_video_player`'s `VideoFeedController`) where decoupling from Riverpod/BLoC is intentional.

**Effort**: High. BLoC migration is underway but Riverpod dominates by volume. ChangeNotifier usage needs to be added to migration tracking. Multi-quarter effort; priority targets are the 6 largest provider files totaling 8,000+ lines.

**GitHub ticket**: TBD

---

### Features scattered across 4+ directories
**Problem**: Only 3 of 40+ features use the co-located `features/` pattern. The rest are spread across `blocs/`, `screens/`, `widgets/`, `providers/`, and `services/`.

**Evidence**: `features/` has 3 entries (app, creator_analytics, feature_flags). The rest: `blocs/` (42 BLoC directories), `screens/` (~120 files in 15 subdirectories), `widgets/` (234 files in 10 subdirectories), `providers/` (74 files, flat). Finding "comments" requires checking `lib/blocs/comments/`, `lib/screens/comments/`, `lib/providers/`, `lib/services/`, and `packages/comments_repository/`. The `features/feature_flags/` co-located pattern is documented in the architecture audit as "proven better."

**Done well**: `features/feature_flags/` is a proven co-located feature with models, services, providers, widgets, and a comprehensive README, all concerns in one directory.

**Impact**: Medium. Main impact is about discoverability.

**Recommendation**: Define and commit to a single architecture approach. Our recommended approach is co-locating by feature, where each feature owns its BLoC, screens, and widgets in one directory. This makes the codebase navigable and ensures consistency as the team grows.

**Effort**: Medium. Migration is opportunistic: colocate when touching a feature for BLoC migration or a major change. Low risk per move but 40+ features to eventually migrate.

**GitHub ticket**: TBD

---

### Singleton services bypass DI
**Problem**: 13+ services use `factory => _instance` singletons while also being wrapped in Riverpod providers.

**Evidence**: Services using the `factory ... => static _instance` singleton pattern: `NotificationServiceEnhanced`, `FeedPerformanceTracker`, `PageLoadHistory`, `VideoFormatPreferenceService`, `StartupPerformanceService`, `LoggingConfigService`, `PerformanceMonitoringService`, `ScreenAnalyticsService`, `TopHashtagsService`, `CrashReportingService`, `VideoThumbnailService`, `BackgroundActivityManager`, `VideoLoadingMetrics`, `ErrorAnalyticsTracker`, `BandwidthTrackerService`. These are also wrapped in Riverpod providers in `app_providers.dart`, providing the appearance of DI while tests cannot replace them with mocks without reaching into static state.

**Done well**: `CategoriesRepository`, `CommentsRepository`, and `VideosRepository` use constructor injection for all dependencies, making their test files straightforward mock injection.

**Impact**: Medium. Tests cannot mock singletons through normal DI; Riverpod providers that wrap singletons add a layer without improving testability; hidden global mutable state across 13+ services.

**Effort**: Medium. Convert to constructor-injected services incrementally. For services with early-initialization requirements, exposing the instance via a Riverpod override is acceptable as an exception, not the norm.

**GitHub ticket**: TBD

---

### No unified caching architecture: 13 independent caches across 4 storage backends
**Problem**: Each feature has built its own caching solution independently, resulting in 13 cache systems with no shared strategy for invalidation, eviction, or resource budgeting. For an app where offline-readiness and instant content display are core to the experience, caching deserves a deliberate architecture rather than ad-hoc per-feature solutions.

**Evidence**: Current cache inventory:

| Cache | Storage | TTL/Eviction | Config Location |
|-------|---------|-------------|-----------------|
| Video file cache | flutter_cache_manager | 30 days, 1000 objects | `openvine_media_cache.dart` |
| Image file cache | flutter_cache_manager | 7 days, 200 objects | `vine_cached_image.dart` |
| Native video player cache | Platform-native | 500 MB LRU | `main.dart` |
| Home feed cache | SharedPreferences | 1 hour | `home_feed_cache.dart` |
| Profile feed session cache | In-memory LRU | 25 profiles, session | `profile_feed_session_cache.dart` |
| Feed mode cache | In-memory map | Session, no TTL | `in_memory_feed_cache.dart` |
| Video event cache | In-memory list | No TTL, manual clear | `video_cache_service.dart` |
| Subscribed list video cache | In-memory map | Session, relay fallback | `subscribed_list_video_cache.dart` |
| Personal event cache | Hive | No TTL, per-user | `personal_event_cache_service.dart` |
| Hashtag cache | Hive | 1 hour | `hashtag_cache_service.dart` |
| Nostr events | Drift/SQLite | `expire_at` field | `app_database.dart` |
| Profile stats | Drift/SQLite | 5 minutes | `app_database.dart` |
| Notifications | Drift/SQLite | 7 days | `app_database.dart` |

Four storage backends (in-memory, Hive, SharedPreferences, Drift/SQLite) serve overlapping purposes. TTLs range from 5 minutes to 30 days with no coordination. No shared cache budget manages total memory or disk usage across systems. Each cache has its own initialization path, corruption recovery approach, and cleanup trigger.

**Related**: "Migrate Hive CE usage to Drift" in [issues-dependencies.md](issues-dependencies.md) addresses one piece of this: consolidating the two persistent storage backends.

**Impact**: Medium. Individual caches work, but the fragmentation makes it hard to reason about total resource usage, implement consistent offline behavior, or answer "what happens when the device is low on storage." Adding new cached data requires choosing from 4 backends with no guidance on which to use.

**Effort**: High. A unified caching strategy is a design exercise first (define cache tiers, TTL policies, eviction budget) and an incremental migration second. This is a long-term architectural direction.

**GitHub ticket**: TBD

---

### App behavior analytics have no architecture: no package, no unified schema, UI-layer calls
**Problem**: App behavior analytics (screen views, performance metrics, user interactions, i.e. the typical Google Analytics use case) has no architecture: no dedicated package, no unified event schema, and most tracking calls made directly from the UI layer instead of the business logic layer.

**Evidence**: Two overlapping systems handle app behavior tracking:

1. **Firebase Analytics**: 5 files in `lib/services/` import `FirebaseAnalytics` directly: `screen_analytics_service.dart`, `feed_performance_tracker.dart`, `video_loading_metrics.dart`, `error_analytics_tracker.dart`, and `app_router.dart`. No shared wrapper, no unified event schema.

2. **Internal observability**: 9 services (2,629 LOC total) in `lib/services/`: `analytics_service.dart` (318), `screen_analytics_service.dart` (378), `error_analytics_tracker.dart` (276), `feed_performance_tracker.dart` (346), `startup_performance_service.dart` (462), `video_loading_metrics.dart` (640), `bandwidth_tracker_service.dart` (209), `page_load_observer.dart` (54), `page_load_history.dart` (134). Related services like `page_load_observer` and `page_load_history` are separate singletons with no clear reason for the split.

Where analytics calls are made from:
- **13 screen files**: UI layer calls analytics services directly
- **6 widget files**: UI layer calls analytics services directly
- **3 BLoC files**: only 3 BLoCs use analytics
- **No `BlocObserver`**: zero matches in the codebase. State transitions are not tracked centrally; each screen/widget manually calls the relevant analytics service

No analytics package exists; all 9 services live in `lib/services/` as unpackaged singletons with direct Firebase imports.

**Impact**: Medium. Analytics calls in the UI layer violate the layered architecture (widgets should not call services directly). No `BlocObserver` means state transitions, the most reliable signal for user behavior, are not tracked. The 9 services with no unified event schema make dashboards harder to reason about and lead to redundant trackers.

**Effort**: High. Design an analytics architecture: (1) extract a shared analytics package with a unified event schema, (2) introduce a `BlocObserver` for centralized state-transition tracking(where flutter_bloc is used), (3) move UI-layer analytics calls into BLoCs or the observer, (4) consolidate the 9 services behind a facade. Incremental: start with the `BlocObserver` and facade, migrate call sites opportunistically.

**GitHub ticket**: TBD

---

### Adopt optimistic updates as the default pattern for user write actions
**Problem**: User-initiated write actions should update the UI immediately and publish to relays in the background, rather than showing loading indicators and waiting for confirmation. For a Nostr-based app where relay latency is variable, this is essential for a responsive experience.

**Evidence**: `VideoInteractionsBloc._onLikeToggled` sets `isLikeInProgress: true`, awaits the repository call, and only updates the like state after relay confirmation, leaving the user to see the heart in a "pending" state while waiting for the network. The goal is to make the optimistic approach the standard, not the exception.

This is closely related to the caching architecture (see "No unified caching architecture" above). A robust local cache layer makes optimistic updates natural, since local state becomes the source of truth with eventual relay consistency.

**Done well**: `CommentsBloc` already updates the UI immediately on comment post and vote toggle, rolling back only on confirmed failure, the pattern to adopt as the standard.

**Impact**: High. Directly affects perceived app responsiveness.

**Effort**: Medium. The pattern is proven in the codebase. Adopt incrementally as features are touched.

**GitHub ticket**: TBD

---

### No documented data source strategy — 4 ad-hoc read patterns

**Problem**: The app reads data through 4 distinct patterns (Funnelcake-only, Relay-only, API-first with relay fallback, and progressive multi-source merge), but there is no documented strategy for when to use which. Each feature chose its own approach independently, leading to inconsistent resilience, unnecessary relay load, and unwired API endpoints.

**Evidence**: A full data source audit identified 4 patterns across all read paths:

| Pattern | Where | Behavior on failure |
|---|---|---|
| **Funnelcake-only** | Categories, Classics, Trending hashtags, Notifications, Hashtag search | Empty UI, no fallback |
| **Relay-only** | Video overlay counts, like/repost history, comments real-time, DMs | No API acceleration |
| **API-first → relay fallback** | Home feed, Collabs, Comments page 1, Profile header | Graceful degradation (loses ranking/counts) |
| **Progressive merge** | Search, Popular, Profile reposts | Most complex, requires dedup |

No documentation explains why a given feature uses one pattern over another. Some choices are intentional (DMs must be relay-only for encryption; notifications have no relay equivalent), but others are gaps where Funnelcake endpoints exist but aren't wired:

| Gap | Today | Available API endpoint | Impact |
|---|---|---|---|
| Video overlay counts | 3 separate relay NIP-45 COUNTs per video | `GET /api/videos/{id}/stats` — all counts in one call | **High** — fires on every video |
| Profile grids (liked/reposted) | Relay fetch by ID, one by one | `POST /api/videos/bulk` — batch lookup | **High** — 20+ videos per grid |
| Comment pagination (page 2+) | Falls back to relay after first page | `GET /api/videos/{id}/comments` supports `offset` | **Medium** |
| Hashtag feed | No fallback when API is down | Relay can query by `t` tag | **Medium** |
| Notifications | No fallback at all, tab goes empty | Raw events exist on relay (complex to aggregate) | **Medium** |

**Related**: See "No unified caching architecture" (this file) for the local caching side of the same problem. See "Video overlay fires 3 relay round-trips per video" in [issues-performance.md](issues-performance.md) for the highest-impact specific gap. See "Inconsistent error handling in notification methods" in [issues-error-handling.md](issues-error-handling.md) for the notification endpoint's error suppression.

**Impact**: High. Every video in the app pays a 3x relay cost that a single API call could replace. Profile grids make N+1 relay queries instead of one batch call. Two user-facing screens (hashtag feed, notifications) go completely empty on API failure with no fallback. New features have no guidance on which pattern to adopt.

**Effort**: Medium. The work splits into two tracks: (1) **Document the strategy** — define when each pattern should be used, add it as a decision tree to the architecture docs, and classify existing features against it. (2) **Wire the gaps** — prioritize by impact: video overlay counts first (every video), profile grid batch second (every profile visit), comment pagination third. Hashtag and notification fallbacks are lower priority since they require more complex relay aggregation.

**GitHub ticket**: TBD
