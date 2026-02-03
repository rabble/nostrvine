# Video Feed Refactor Plan

> **Goal:** Split `VideoEventService` (god class) into BLoC + Repository pattern following VGE standards.

## Current Problem

`VideoEventService` is a ~3000 line ChangeNotifier mixing 5 concerns:
1. Nostr subscription management
2. In-memory caching
3. Event processing/transformation
4. Pagination state
5. Profile coordination

## UI Changes

**Before:** Separate Home feed and Explore page (with grid tabs)

**After:** Unified Home page with mode switching:
- **Home** - Videos from followed users
- **New** - Latest videos (chronological)
- **Popular** - Trending videos (by loop count)

Grid view is **only** used in profile tabs, not the main feed.

## Proposed Architecture

Following the `likes_repository` pattern with `db_client` integration:

```
┌─────────────────────────────────────────────────────────────┐
│ UI (VideoFeedScreen)                                        │
│ └─ Mode selector: Home | New | Popular                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ BLoCs (Business Logic + UI State)                           │
├─────────────────────────────┬───────────────────────────────┤
│ VideoFeedBloc               │ ProfileVideosBloc             │
│ (unified feed modes)        │ (profile grid tabs)           │
└────────────┬────────────────┴────────────┬──────────────────┘
             │                             │
             └──────────────┬──────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ VideosRepository (Orchestration)                            │
│ ├─ Coordinates Nostr ↔ Storage                              │
│ ├─ In-memory cache (fast lookups)                           │
│ └─ Pagination-based loading (no streams)                    │
└──────────┬──────────────────────────────────────────────────┘
           │
     ┌─────┴─────────────────────────┐
     │                               │
     ▼                               ▼
┌─────────────────┐    ┌──────────────────────────────────────┐
│ NostrClient     │    │ VideoLocalStorage (abstract)         │
│ (Relay I/O)     │    └──────────────┬───────────────────────┘
└─────────────────┘                   │
                                      ▼
                       ┌──────────────────────────────────────┐
                       │ DbVideoLocalStorage                  │
                       │ (db_client implementation)           │
                       │ └─ NostrEventsDao                    │
                       └──────────────────────────────────────┘
```

## Supporting Classes (Avoid God Class)

To keep `VideosRepository` focused, extract these helpers:

### VideoEventTransformer

Handles conversion between data formats:

| Input | Output | Logic |
|-------|--------|-------|
| Nostr `Event` | `VideoEvent` | Parse tags, extract URLs, validate |
| `VideoEvent` | DB row | Serialize for storage |
| DB row | `VideoEvent` | Deserialize from storage |

Also handles:
- NIP-33 replaceable event logic (newer replaces older)
- URL validation
- Hashtag extraction

### VideoFilterService

Applies filtering rules:

| Filter | Source |
|--------|--------|
| Blocklist | `ContentBlocklistService` |
| Adult content | `AgeVerificationService` |
| Platform (WebM on iOS) | Device detection |

Keeps filtering logic out of repository.

### PaginationManager

Manages cursor state per feed mode:

| Responsibility |
|----------------|
| Track `oldestTimestamp` per mode |
| Deduplication via `seenEventIds` |
| `hasMore` state |
| Build `until` filter for next page |

Could be internal to repository or standalone.

## Component Responsibilities

### VideosRepository

Single class handling all video data operations:

| Responsibility | Methods |
|----------------|---------|
| Fetch home feed | `getHomeFeedVideos(authors, limit, until?)` → `Future<List<VideoEvent>>` |
| Fetch new videos | `getNewVideos(limit, until?)` → `Future<List<VideoEvent>>` |
| Fetch popular | `getPopularVideos(limit, until?)` → `Future<List<VideoEvent>>` |
| Fetch profile | `getProfileVideos(pubkey, limit, until?)` → `Future<List<VideoEvent>>` |
| Refresh | `refresh(mode)` → Fetches latest, returns new videos |
| Cache management | Internal - coordinates between Nostr and local DB |

**Key principle:** Repository returns `Future<List>`, not Streams. Loading is triggered by scroll (pagination) or pull-to-refresh, not real-time subscriptions.

### VideoFeedBloc

Unified bloc for the main feed with mode switching:

| State | Events |
|-------|--------|
| `VideoFeedInitial` | `VideoFeedStarted(mode)` |
| `VideoFeedLoading` | `VideoFeedModeChanged(mode)` |
| `VideoFeedLoaded(videos, mode, hasMore)` | `VideoFeedLoadMoreRequested` |
| `VideoFeedError(message)` | `VideoFeedRefreshRequested` |

**Feed Modes:**
```dart
enum FeedMode { home, latest, popular }
```

**Owns:**
- Current video list state
- Active feed mode
- Loading/error states
- Pagination state (hasMore, isLoadingMore)

### ProfileVideosBloc

For profile page video grids:

| State | Events |
|-------|--------|
| `ProfileVideosInitial` | `ProfileVideosRequested(pubkey)` |
| `ProfileVideosLoading` | `ProfileVideosLoadMoreRequested` |
| `ProfileVideosLoaded(videos, hasMore)` | `ProfileVideosRefreshRequested` |
| `ProfileVideosError(message)` | |

---

## Progress Tracker

### Phase 1: Create Repository ✅ COMPLETE

| Task | Status | Notes |
|------|--------|-------|
| Create `VideoLocalStorage` interface | ✅ Done | `packages/videos_repository/lib/src/video_local_storage.dart` |
| Create `DbVideoLocalStorage` implementation | ✅ Done | `packages/videos_repository/lib/src/db_video_local_storage.dart` |
| Create `VideosRepository` class | ✅ Done | `packages/videos_repository/lib/src/videos_repository.dart` |
| Implement `getHomeFeedVideos()` | ✅ Done | Filters by author list |
| Implement `getNewVideos()` | ✅ Done | Chronological order |
| Implement `getPopularVideos()` | ✅ Done | NIP-50 with client-side fallback |
| Implement `getProfileVideos()` | ✅ Done | Single author filter |
| Add repository tests | ✅ Done | Full test coverage |
| Create `videosRepositoryProvider` | ✅ Done | In `app_providers.dart` |

### Phase 2: Create BLoCs ✅ COMPLETE

| Task | Status | Notes |
|------|--------|-------|
| Create `VideoFeedBloc` | ✅ Done | `lib/blocs/video_feed/video_feed_bloc.dart` |
| Create `VideoFeedEvent` | ✅ Done | Started, ModeChanged, LoadMore, Refresh |
| Create `VideoFeedState` | ✅ Done | With FeedMode enum, status, pagination |
| Handle mode switching | ✅ Done | Clears videos, reloads for new mode |
| Handle pagination | ✅ Done | Cursor-based with `until` param |
| Handle empty home feed | ✅ Done | Detects no followed users |
| Add bloc tests | ✅ Done | 25 tests in `test/blocs/video_feed/video_feed_bloc_test.dart` |
| Create `ProfileVideosBloc` | ❌ TODO | For profile page grids |

### Phase 3: UI Integration 🔄 IN PROGRESS

| Task | Status | Notes |
|------|--------|-------|
| Create `VideoFeedPage` | ✅ Done | Full implementation with BlocProvider |
| Mode selector UI | ✅ Done | `_FeedModeSwitch` with PopupMenuButton |
| Loading states | ✅ Done | `BrandedLoadingIndicator` |
| Error states | ✅ Done | `_FeedErrorWidget` |
| Empty states | ✅ Done | `FeedEmptyWidget` with mode-specific messages |
| Pagination trigger | ✅ Done | `onLoadMore` callback to VideoPageView |
| Fix rebuild on menu open | ✅ Done | Convert to ConsumerStatefulWidget |
| Remove `ExploreScreen` | ❌ TODO | After VideoFeedPage is stable |
| Update navigation | ❌ TODO | Replace explore with new feed |

### Phase 4: Cleanup ❌ NOT STARTED

| Task | Status | Notes |
|------|--------|-------|
| Remove `homeFeedProvider` | ❌ TODO | |
| Remove `videoEventsProvider` | ❌ TODO | |
| Remove `VideoEventService` facade | ❌ TODO | Keep for profile until ProfileVideosBloc done |
| Update all tests | ❌ TODO | |

---

## Known Issues & Improvements

### 1. ~~VideoFeedPage Build Method Incomplete~~ ✅ FIXED
~~**Issue:** `VideoFeedPage.build()` creates `BlocProvider` but missing `child: const _VideoFeedView()`~~
**Status:** Fixed - child widget is present

### 2. Repository Not Using Local Storage
**Issue:** `VideosRepository` only fetches from Nostr, doesn't cache to `VideoLocalStorage`
**Impact:** No offline support, slower repeated loads
**Fix:** Inject `VideoLocalStorage` and implement cache-first strategy

### 3. NIP-50 `sort:hot` Not Standard
**Issue:** `sort:hot` is a custom relay extension, not standard NIP-50
**Status:** Has fallback to client-side sorting ✅
**Improvement:** Update comment to clarify it's relay-specific

### 4. No Content Filtering
**Issue:** Repository doesn't apply blocklist, age verification, or platform filters
**Current:** VideoEventService handles this
**Fix:** Either inject filter services into repository OR apply filters in BLoC

### 5. ~~Missing Tests~~ ✅ FIXED
~~**Issue:** No tests for `VideoFeedBloc`~~
**Status:** Fixed - 25 comprehensive tests in `test/blocs/video_feed/video_feed_bloc_test.dart`

---

## Recommended Next Steps

### Immediate (High Priority)
1. **Test the full flow** - VideoFeedPage → VideoFeedBloc → VideosRepository → Relay
2. **Remove debug overlay** - Remove the debug info overlay from VideoFeedPage before production

### Short-term
4. **Add local storage to repository** - Implement cache-first strategy for offline support
5. **Add content filtering** - Either in repository or bloc layer
6. **Create ProfileVideosBloc** - For profile page video grids

### Medium-term
7. **Replace ExploreScreen** - Make VideoFeedPage the main feed
8. **Remove old providers** - homeFeedProvider, videoEventsProvider
9. **Deprecate VideoEventService** - Gradual removal after all features migrated

---

## Key Decisions

| Decision | Choice |
|----------|--------|
| **Streams vs Futures** | Futures - loading is scroll-triggered, not real-time |
| **Buffering** | Not needed - no real-time updates during browsing |
| **Feed modes** | Single `VideoFeedBloc` with mode enum |
| **Grid view** | Profile tabs only, not main feed |
| **DI approach** | Riverpod for DI + BLoC for state management |

## File Structure

```
packages/videos_repository/
├── lib/src/
│   ├── video_local_storage.dart      ✅ Done
│   ├── db_video_local_storage.dart   ✅ Done
│   └── videos_repository.dart        ✅ Done
├── test/src/
│   ├── videos_repository_test.dart   ✅ Done
│   └── db_video_local_storage_test.dart ✅ Done

lib/
├── blocs/
│   ├── video_feed/
│   │   ├── video_feed_bloc.dart      ✅ Done
│   │   ├── video_feed_event.dart     ✅ Done
│   │   └── video_feed_state.dart     ✅ Done
│   └── profile_videos/
│       ├── profile_videos_bloc.dart  ❌ TODO
│       ├── profile_videos_event.dart ❌ TODO
│       └── profile_videos_state.dart ❌ TODO
├── screens/feed/
│   ├── video_feed_page.dart          ✅ Done
│   └── video_page_view.dart          ✅ Done (reused)
```

## What Gets Deleted (After Full Migration)

- `lib/services/video_event_service.dart` (3000+ lines)
- `lib/providers/home_feed_provider.dart`
- `lib/providers/video_events_providers.dart`
- `lib/screens/explore_screen.dart`
- `lib/screens/explore/` directory

## Open Questions

1. ~~Should we keep Riverpod for DI and use BLoC for state, or go full `flutter_bloc` with `RepositoryProvider`?~~ **Answer:** Riverpod for DI + BLoC for state
2. ~~How to handle the transition period where both systems coexist?~~ **Answer:** Keep VideoEventService for features not yet migrated
3. ~~Mode selector UI: Tabs? Dropdown? Swipe gestures?~~ **Answer:** PopupMenuButton dropdown

---

*Document created for refactoring planning. Last updated: January 2025*