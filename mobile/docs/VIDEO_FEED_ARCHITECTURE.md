# Video Feed Architecture

> **Purpose:** Reference document for engineers refactoring VideoEventService to BLoC + Repository pattern.

## Current Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ UI SCREENS                                                  │
├──────────────────┬──────────────────────────────────────────┤
│ VideoFeedScreen  │ ExploreScreen                            │
│ (Home Feed)      │ ├─ NewVideosTab                          │
│                  │ └─ PopularVideosTab                      │
└────────┬─────────┴────────────┬─────────────────────────────┘
         │                      │
         ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│ RIVERPOD PROVIDERS                                          │
├──────────────────┬──────────────────────────────────────────┤
│ homeFeedProvider │ videoEventsProvider                      │
│ (AsyncNotifier)  │ (Stream + Buffering)                     │
└────────┬─────────┴────────────┬─────────────────────────────┘
         │                      │
         ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│ VideoEventService (ChangeNotifier) ← GOD CLASS             │
│ └─ _eventLists: Map<SubscriptionType, List<VideoEvent>>    │
│    ├─ homeFeed    → followed users' videos                 │
│    └─ discovery   → all public videos                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
              ┌─────────────────┐
              │ NostrClient     │
              │ + EventRouter   │
              │ (Relay + DB)    │
              └─────────────────┘
```

## Screens & What They Consume

### Home Feed (`VideoFeedScreen`)

| Aspect | Current Implementation |
|--------|------------------------|
| Provider | `homeFeedProvider` (AsyncNotifier) |
| Data | Videos from followed authors only |
| Subscription | `VideoEventService.subscribeToHomeFeed(followingPubkeys)` |
| Pagination | `homeFeedProvider.loadMore()` → `VideoEventService.loadMoreEvents()` |
| Refresh | Pull-to-refresh + auto-refresh every 10 minutes |

### Explore Page (`ExploreScreen`)

Both tabs use the same provider but display differently:

| Tab | Provider | Sorting | Notes |
|-----|----------|---------|-------|
| **New Videos** | `videoEventsProvider` | By `createdAt` (newest first) | Default chronological order |
| **Popular Videos** | `videoEventsProvider` | By `originalLoops` (most loops first) | Client-side sort on same data |

| Aspect | Current Implementation |
|--------|------------------------|
| Provider | `videoEventsProvider` (Stream) |
| Data | All public videos (no author filter) |
| Subscription | `VideoEventService.subscribeToDiscovery(nip50Sort: sort:hot)` |
| Buffering | See below |

### Buffering System (Explore only)

Prevents feed from jumping while user browses:

```
Screen visible → enableBuffering()
                      │
                      ▼
          ┌─────────────────────────┐
          │ New videos arrive       │
          │ → Added to _bufferedEvents │
          │ → Banner shows count    │
          └───────────┬─────────────┘
                      │
            User taps banner
                      │
                      ▼
          ┌─────────────────────────┐
          │ loadBufferedVideos()    │
          │ → Inserts at top of feed │
          │ → Clears buffer         │
          └─────────────────────────┘
                      │
Screen hidden → disableBuffering()
```

**Key files:**
- `videoEventsProvider` → `_bufferedEvents`, `enableBuffering()`, `loadBufferedVideos()`
- `bufferedVideoCountProvider` → Exposes count to UI
- `ExploreScreen._buildNewVideosBanner()` → Banner widget

## VideoEventService Responsibilities

> **Note:** This is a ~3000 line god class that mixes multiple concerns.

### 1. Subscription Management

Manages Nostr relay subscriptions for different feed types:

| Method | Feed Type | Filter |
|--------|-----------|--------|
| `subscribeToHomeFeed(pubkeys)` | Following feed | `authors: [pubkeys]`, kinds 34236 |
| `subscribeToDiscovery(nip50Sort)` | Explore feed | No author filter, NIP-50 `sort:hot` |
| `subscribeToUserVideos(pubkey)` | Profile feed | `authors: [pubkey]` |
| `subscribeToHashtagVideos(tags)` | Hashtag feed | `#t: [tags]` |

**Deduplication:** Tracks active subscriptions to avoid duplicate REQ messages. If parameters match an existing subscription, skips re-subscribing.

**Lifecycle:** Subscriptions are long-lived (persistent). When relay closes connection, service schedules reconnection.

### 2. In-Memory Cache

Maintains separate video lists per subscription type:

| SubscriptionType | Purpose |
|------------------|---------|
| `homeFeed` | Videos from followed users |
| `discovery` | All public videos (explore) |
| `profile` | Single user's videos |
| `hashtag` | Videos matching hashtag filter |
| `search` | NIP-50 search results |
| `editorial` | Curated content |
| `popularNow` | Trending videos |
| `trending` | By engagement metrics |

Each list is independent - a video can exist in multiple lists simultaneously.

### 3. Event Processing

Transforms raw Nostr events into `VideoEvent` models:

**Incoming event flow:**
1. Receive `Event` from relay
2. Check if video kind (34236) or repost (kind 16)
3. Apply filters (blocklist, adult content, hashtag match)
4. Convert to `VideoEvent` via `VideoEvent.fromNostrEvent()`
5. Handle replaceable events (NIP-33) - newer version replaces older
6. Add to appropriate `_eventLists` bucket
7. Call `notifyListeners()` to update providers

**Filtering applied:**
- Blocklist service (blocked users/content)
- Adult content filter (if user preference set)
- Hashtag filter (for hashtag subscriptions)
- URL validation (must have valid video URL)

### 4. Pagination

Tracks pagination state per subscription type:

| Field | Purpose |
|-------|---------|
| `oldestTimestamp` | Cursor for fetching older videos |
| `isLoading` | Prevents concurrent pagination requests |
| `hasMore` | False when relay returns fewer than requested |
| `seenEventIds` | Deduplicates across pagination batches |

**Flow:**
1. User scrolls to end of feed
2. Provider calls `loadMoreEvents(subscriptionType)`
3. Service queries relay with `until: oldestTimestamp`
4. New events appended to existing list (not prepended)
5. Cursor updated to oldest received timestamp

### 5. Profile Fetching

Coordinates with `UserProfileService` to load author metadata:

- When videos arrive, extracts unique author pubkeys
- Batch fetches profiles not already cached
- Uses `prefetchProfilesImmediately()` for cache-first loading
- Profiles displayed alongside videos in feed

### 6. Callbacks & Notifications

Two callback systems for external listeners:

| Callback | When Fired |
|----------|------------|
| `addVideoUpdateListener()` | Video metadata updated (e.g., loop count changed) |
| `addNewVideoListener()` | New video added to any feed |

Used by other services to react to video changes without polling.

## Cache Strategy

### Cache-First Flow

```
User opens feed
       │
       ▼
┌──────────────────────────────────┐
│ 1. Load from local DB            │ ← Instant UI update
│    _loadCachedEvents()           │
└──────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│ 2. Subscribe to Nostr relay      │ ← Fresh data streams in
│    _nostrService.subscribe()     │
└──────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│ 3. Merge & deduplicate           │
│    Events added to _eventLists   │
└──────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│ 4. notifyListeners()             │ ← Providers react
└──────────────────────────────────┘
```

### Where Data Lives

| Layer | Storage | Lifetime |
|-------|---------|----------|
| VideoEventService | `_eventLists` (in-memory) | App session |
| EventRouter | Drift database | Persistent |
| NostrClient | Relay connection | Real-time stream |

## Key Files

| File | Role |
|------|------|
| `lib/services/video_event_service.dart` | God class - subscriptions, cache, processing |
| `lib/providers/home_feed_provider.dart` | Home feed state, filtering, refresh logic |
| `lib/providers/video_events_providers.dart` | Discovery stream, buffering, debouncing |
| `lib/screens/video_feed_screen.dart` | Home feed UI |
| `lib/screens/explore_screen.dart` | Explore tabs UI |
| `lib/screens/explore/new_videos_tab.dart` | New videos grid/feed |
| `lib/screens/explore/popular_videos_tab.dart` | Popular videos grid/feed |

## Data Flow Example: Home Feed

```
1. User opens app
   └─► homeFeedProvider.build() called

2. Provider gets following list
   └─► ref.watch(followingProvider)

3. Provider triggers subscription
   └─► videoEventService.subscribeToHomeFeed(pubkeys)

4. VideoEventService:
   a. Loads cached events from DB
   b. Subscribes to Nostr relay with author filter
   c. Processes incoming events
   d. Calls notifyListeners()

5. Provider reacts to changes
   └─► Filters, sorts, emits new state

6. UI rebuilds with new videos
```

## Data Flow Example: Explore (Discovery)

```
1. User taps Explore tab
   └─► ExploreScreen builds

2. videoEventsProvider starts
   └─► Waits for appReadyProvider gate

3. Provider triggers subscription
   └─► videoEventService.subscribeToDiscovery(nip50Sort: hot)

4. VideoEventService:
   a. Loads cached discovery events
   b. Subscribes with NIP-50 search filter
   c. Processes events into _eventLists[discovery]
   d. Calls notifyListeners()

5. Provider:
   a. Debounces updates (500ms)
   b. Can buffer new videos while user browses
   c. Emits to UI

6. Tabs sort the same data differently:
   - NewVideosTab: by createdAt
   - PopularVideosTab: by originalLoops
```

---

*Document created for refactoring reference. Last updated: January 2025*
