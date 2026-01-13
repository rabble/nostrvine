# Video Feed Refactor Plan

> **Goal:** Split `VideoEventService` (god class) into BLoC + Repository pattern following VGE standards.

## Current Problem

`VideoEventService` is a ~3000 line ChangeNotifier mixing 5 concerns:
1. Nostr subscription management
2. In-memory caching
3. Event processing/transformation
4. Pagination state
5. Profile coordination

## Proposed Architecture

Following the `likes_repository` pattern with `db_client` integration:

```
┌─────────────────────────────────────────────────────────────┐
│ UI (Screens)                                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ BLoCs (Business Logic + UI State)                           │
├─────────────────┬─────────────────┬─────────────────────────┤
│ HomeFeedBloc    │ DiscoveryBloc   │ ProfileFeedBloc         │
│                 │ (+ buffering)   │                         │
└────────┬────────┴────────┬────────┴────────┬────────────────┘
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ VideoRepository (Orchestration)                             │
│ ├─ Coordinates Nostr ↔ Storage                              │
│ ├─ In-memory cache (fast lookups)                           │
│ └─ Exposes reactive streams                                 │
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
                       │ └─ VideoEventsDao                    │
                       └──────────────────────────────────────┘
```

## Supporting Classes (Avoid God Class)

To keep `VideoRepository` focused, extract these helpers:

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
| Hashtag matching | Subscription parameters |

Keeps filtering logic out of repository.

### PaginationManager

Manages cursor state per subscription type:

| Responsibility |
|----------------|
| Track `oldestTimestamp` per feed |
| Deduplication via `seenEventIds` |
| `hasMore` state |
| Build `until` filter for next page |

Could be internal to repository or standalone.

## Component Responsibilities

### VideoRepository

Single class handling all video data operations:

| Responsibility | Methods |
|----------------|---------|
| Fetch home feed | `getHomeFeedVideos(authors, limit)` → `Stream<List<VideoEvent>>` |
| Fetch discovery | `getDiscoveryVideos(limit, sort)` → `Stream<List<VideoEvent>>` |
| Fetch profile | `getProfileVideos(pubkey, limit)` → `Stream<List<VideoEvent>>` |
| Pagination | `loadMore(feedType)` → Appends older videos to stream |
| Cache management | Internal - coordinates between Nostr and local DB |

**Key principle:** Repository exposes Streams, not raw lists. BLoCs subscribe and manage state.

### HomeFeedBloc

| State | Events |
|-------|--------|
| `HomeFeedInitial` | `HomeFeedStarted` |
| `HomeFeedLoading` | `HomeFeedRefreshRequested` |
| `HomeFeedLoaded(videos, hasMore)` | `HomeFeedLoadMoreRequested` |
| `HomeFeedError(message)` | `HomeFeedFollowingChanged(pubkeys)` |

**Owns:**
- Current video list state
- Loading/error states
- Coordination with following list changes

### DiscoveryBloc

| State | Events |
|-------|--------|
| `DiscoveryInitial` | `DiscoveryStarted` |
| `DiscoveryLoading` | `DiscoveryRefreshRequested` |
| `DiscoveryLoaded(videos, bufferedCount)` | `DiscoveryLoadMoreRequested` |
| `DiscoveryError(message)` | `DiscoveryBufferLoadRequested` |

**Owns:**
- Current video list state
- Buffering logic (accumulate vs auto-insert)
- Sorting mode (new vs popular)

### ProfileFeedBloc

Similar pattern for user profile video grids.

## Migration Strategy

### Phase 1: Create Repository
1. Create `VideoRepository` class
2. Move subscription logic from `VideoEventService`
3. Move cache coordination logic
4. Keep `VideoEventService` as a facade initially (delegates to repository)

### Phase 2: Create BLoCs
1. Create `HomeFeedBloc` consuming `VideoRepository`
2. Create `DiscoveryBloc` with buffering logic
3. Update screens to use BLoCs instead of Riverpod providers

### Phase 3: Cleanup
1. Remove old Riverpod providers (`homeFeedProvider`, `videoEventsProvider`)
2. Remove `VideoEventService` facade
3. Update tests

## Key Decisions Needed

| Decision | Options |
|----------|---------|
| **Buffering location** | Keep in DiscoveryBloc? Or move to Repository? |
| **Cache invalidation** | Time-based? Event-based? Manual only? |
| **Profile fetching** | Keep in VideoRepository? Or separate UserRepository? |
| **Pagination strategy** | Cursor-based (current)? Or offset-based? |

## File Structure (Proposed)

```
lib/
├── repositories/
│   └── video_repository.dart
├── blocs/
│   ├── home_feed/
│   │   ├── home_feed_bloc.dart
│   │   ├── home_feed_event.dart
│   │   └── home_feed_state.dart
│   ├── discovery/
│   │   ├── discovery_bloc.dart
│   │   ├── discovery_event.dart
│   │   └── discovery_state.dart
│   └── profile_feed/
│       └── ...
```

## What Gets Deleted

After migration completes:
- `lib/services/video_event_service.dart` (3000+ lines)
- `lib/providers/home_feed_provider.dart`
- `lib/providers/video_events_providers.dart`

## Open Questions

1. Should we keep Riverpod for DI and use BLoC for state, or go full `flutter_bloc` with `RepositoryProvider`?
2. How to handle the transition period where both systems coexist?
3. Priority order: Home feed first? Or Discovery first?

---

*Document created for refactoring planning. Last updated: January 2025*
