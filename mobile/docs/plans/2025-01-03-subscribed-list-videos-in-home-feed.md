# Subscribed List Videos in Home Feed

## Summary

Videos from subscribed curated lists should appear in the home feed, interleaved with videos from followed users by creation date.

## Requirements

1. **Interleaved by time** - All videos sorted by `createdAt`, regardless of source
2. **Deduplicated** - Each video appears once, even if in multiple lists or from a followed user
3. **List attribution chip** - Tappable pill showing which list(s) a video is from
   - Only shown for videos that are in feed BECAUSE of a subscribed list
   - NOT shown for videos from followed users (they'd appear anyway)
4. **Background sync** - Videos fetched and cached in background
   - Sync on subscribe (immediate)
   - Sync on app launch (refresh all)

## Architecture

### Data Flow

```
HomeFeedProvider.build()
    │
    ├── [Line 187-192] videoEventService.subscribeToHomeFeed()
    │
    ├── [Line 199-242] Stability wait (300ms stable or 3s timeout)
    │
    ├── [Line 257-259] Get followingVideos from service  ←── MERGE POINT
    │   │
    │   └── MERGE: Add subscribedListVideoCache.getVideos()
    │       - Deduplicate by video ID
    │       - Track which videos came from lists (for attribution)
    │
    ├── [Line 261-274] Client-side follow filter
    │
    ├── [Line 282-293] Platform filter (WebM on iOS)
    │
    ├── [Line 298-305] Sort by createdAt DESC
    │
    └── [Line 313-314] Fetch profiles
```

### Merge Implementation (in HomeFeedProvider.build)

```dart
// After line 256, replace current video fetching:

// Get videos from followed users
var followingVideos = List<VideoEvent>.from(
  videoEventService.homeFeedVideos,
);
final followingVideoIds = followingVideos.map((v) => v.id).toSet();

// Get videos from subscribed lists
final subscribedListCache = ref.read(subscribedListVideoCacheProvider);
final subscribedVideos = subscribedListCache.getVideos();

// Track which videos are ONLY from subscribed lists (not from follows)
// These will show the list attribution chip
final listOnlyVideoIds = <String>{};
final videoListSources = <String, Set<String>>{}; // videoId → listIds

for (final video in subscribedVideos) {
  final listIds = subscribedListCache.getListsForVideo(video.id);
  videoListSources[video.id] = listIds;

  if (!followingVideoIds.contains(video.id)) {
    // Video is ONLY in feed because of subscribed list
    listOnlyVideoIds.add(video.id);
    followingVideos.add(video);
  }
}

// Store list sources for UI to access
_currentListSources = videoListSources;
_listOnlyVideoIds = listOnlyVideoIds;
```

---

## New Components

### 1. SubscribedListVideoCache Service

**Location**: `lib/services/subscribed_list_video_cache.dart`

```dart
// ABOUTME: Cache for videos from subscribed curated lists
// ABOUTME: Syncs on subscribe and app launch, provides videos for home feed merge

class SubscribedListVideoCache extends ChangeNotifier {
  SubscribedListVideoCache({
    required NostrService nostrService,
    required VideoEventService videoEventService,
    required CuratedListService curatedListService,
  }) : _nostrService = nostrService,
       _videoEventService = videoEventService,
       _curatedListService = curatedListService;

  final NostrService _nostrService;
  final VideoEventService _videoEventService;
  final CuratedListService _curatedListService;

  // videoId → Set of list IDs containing this video
  final Map<String, Set<String>> _videoToLists = {};

  // Cached video events
  final Map<String, VideoEvent> _cachedVideos = {};

  /// Get all cached videos
  List<VideoEvent> getVideos() => _cachedVideos.values.toList();

  /// Get list IDs for a video
  Set<String> getListsForVideo(String videoId) =>
      _videoToLists[videoId] ?? {};

  /// Sync a single list's videos (called on subscribe)
  Future<void> syncList(String listId, List<String> videoIds) async {
    // Separate event IDs from addressable coordinates
    final hexRegex = RegExp(r'^[a-fA-F0-9]{64}$');
    final eventIds = <String>[];
    final addressableCoords = <String>[];

    for (final id in videoIds) {
      if (id.contains(':')) {
        addressableCoords.add(id);
      } else if (hexRegex.hasMatch(id)) {
        eventIds.add(id);
      }
    }

    // Check VideoEventService cache first
    final missingIds = <String>[];
    for (final eventId in eventIds) {
      final cached = _videoEventService.getVideoById(eventId);
      if (cached != null) {
        _addVideoToCache(cached, listId);
      } else {
        missingIds.add(eventId);
      }
    }

    // Fetch missing videos from relays
    if (missingIds.isNotEmpty || addressableCoords.isNotEmpty) {
      await _fetchVideosFromRelays(missingIds, addressableCoords, listId);
    }

    notifyListeners();
  }

  /// Sync all subscribed lists (called on app launch)
  Future<void> syncAllSubscribedLists() async {
    final subscribedLists = _curatedListService.subscribedLists;

    for (final list in subscribedLists) {
      await syncList(list.id, list.videoEventIds);
    }
  }

  /// Remove a list from cache (called on unsubscribe)
  void removeList(String listId) {
    // Remove list from all video mappings
    for (final videoId in _videoToLists.keys.toList()) {
      _videoToLists[videoId]?.remove(listId);

      // If video is no longer in any subscribed list, remove from cache
      if (_videoToLists[videoId]?.isEmpty ?? true) {
        _videoToLists.remove(videoId);
        _cachedVideos.remove(videoId);
      }
    }
    notifyListeners();
  }

  void _addVideoToCache(VideoEvent video, String listId) {
    _cachedVideos[video.id] = video;
    _videoToLists.putIfAbsent(video.id, () => {}).add(listId);
  }

  Future<void> _fetchVideosFromRelays(
    List<String> eventIds,
    List<String> addressableCoords,
    String listId,
  ) async {
    final filters = <Filter>[];

    if (eventIds.isNotEmpty) {
      filters.add(Filter(ids: eventIds));
    }

    for (final coord in addressableCoords) {
      final parts = coord.split(':');
      if (parts.length >= 3) {
        final kind = int.tryParse(parts[0]);
        final pubkey = parts[1];
        final dTag = parts[2];
        if (kind != null) {
          filters.add(Filter(kinds: [kind], authors: [pubkey], d: [dTag]));
        }
      }
    }

    if (filters.isEmpty) return;

    final eventStream = _nostrService.subscribe(filters);
    final seenIds = <String>{};

    await for (final event in eventStream.timeout(
      const Duration(seconds: 5),
      onTimeout: (sink) => sink.close(),
    )) {
      if (seenIds.contains(event.id)) continue;
      seenIds.add(event.id);

      try {
        final video = VideoEvent.fromNostrEvent(event, permissive: true);
        _addVideoToCache(video, listId);
        _videoEventService.addVideoEvent(video);
      } catch (e) {
        Log.warning(
          'Failed to parse video ${event.id}: $e',
          name: 'SubscribedListVideoCache',
          category: LogCategory.video,
        );
      }
    }
  }
}
```

### 2. Provider Definition

**Location**: Add to `lib/providers/app_providers.dart`

```dart
/// Cache for videos from subscribed curated lists
@Riverpod(keepAlive: true)
SubscribedListVideoCache subscribedListVideoCache(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);

  // Get CuratedListService from the state notifier
  final curatedListState = ref.watch(curatedListsStateProvider);
  final curatedListService = curatedListState.whenOrNull(
    data: (_) => ref.read(curatedListsStateProvider.notifier).service,
  );

  if (curatedListService == null) {
    // Return empty cache if service not ready
    return SubscribedListVideoCache(
      nostrService: nostrService,
      videoEventService: videoEventService,
      curatedListService: CuratedListService.empty(),
    );
  }

  final cache = SubscribedListVideoCache(
    nostrService: nostrService,
    videoEventService: videoEventService,
    curatedListService: curatedListService,
  );

  ref.onDispose(() => cache.dispose());

  return cache;
}
```

### 3. ListAttributionChip Widget

**Location**: `lib/widgets/video_feed_item/list_attribution_chip.dart`

```dart
// ABOUTME: Tappable chip showing which curated list(s) a video is from
// ABOUTME: Navigates to list feed when tapped

class ListAttributionChip extends ConsumerWidget {
  const ListAttributionChip({
    required this.listIds,
    super.key,
  });

  final Set<String> listIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (listIds.isEmpty) return const SizedBox.shrink();

    // Get list names from CuratedListService
    final curatedListService = ref.watch(curatedListsStateProvider).whenOrNull(
      data: (_) => ref.read(curatedListsStateProvider.notifier).service,
    );

    return Wrap(
      spacing: 4,
      children: listIds.take(2).map((listId) {
        final list = curatedListService?.getListById(listId);
        final listName = list?.name ?? 'List';

        return GestureDetector(
          onTap: () {
            if (list != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CuratedListFeedScreen(
                    listId: list.id,
                    listName: list.name,
                    videoIds: list.videoEventIds,
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VineTheme.vineGreen.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.playlist_play,
                  size: 14,
                  color: VineTheme.vineGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  listName,
                  style: TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
```

### 4. VideoFeedItem Changes

**Location**: Modify `lib/widgets/video_feed_item/video_feed_item.dart`

Add to widget parameters:
```dart
class VideoFeedItem extends ConsumerStatefulWidget {
  const VideoFeedItem({
    required this.video,
    this.listSources, // NEW: Set of list IDs this video is from
    this.showListAttribution = false, // NEW: Whether to show attribution
    // ... existing params
  });

  final Set<String>? listSources;
  final bool showListAttribution;
}
```

Add to build method (below author info):
```dart
// Show list attribution chip if video is from subscribed list
// and NOT from a followed user
if (widget.showListAttribution &&
    widget.listSources != null &&
    widget.listSources!.isNotEmpty) {
  ListAttributionChip(listIds: widget.listSources!),
}
```

---

## Sync Triggers

### On Subscribe (CuratedListService.subscribeToList)

```dart
Future<bool> subscribeToList(String listId, [CuratedList? listData]) async {
  // Existing subscription logic...
  _subscribedListIds.add(listId);
  await _saveSubscribedListIds();

  // NEW: Sync videos from this list
  if (listData != null) {
    final cache = // get from provider or injected
    await cache.syncList(listId, listData.videoEventIds);
  }

  return true;
}
```

### On App Launch (CuratedListService.initialize)

```dart
Future<void> initialize() async {
  // Existing initialization...
  await _loadFromStorage();
  await _syncWithRelays();

  // NEW: Sync all subscribed list videos
  final cache = // get from provider or injected
  await cache.syncAllSubscribedLists();
}
```

### On Unsubscribe (CuratedListService.unsubscribeFromList)

```dart
Future<bool> unsubscribeFromList(String listId) async {
  // Existing unsubscribe logic...
  _subscribedListIds.remove(listId);
  await _saveSubscribedListIds();

  // NEW: Remove list from video cache
  final cache = // get from provider or injected
  cache.removeList(listId);

  return true;
}
```

---

## Checking if Video Author is Followed

Use FollowRepository in HomeFeedProvider:

```dart
// In HomeFeedProvider.build(), after merging videos:
final followRepository = ref.read(followRepositoryProvider);

// When building VideoFeedState, determine which videos show attribution
for (final video in mergedVideos) {
  final isFromFollowedUser = followRepository.isFollowing(video.pubkey);
  final isFromSubscribedList = listOnlyVideoIds.contains(video.id);

  // Show attribution only if:
  // - Video is from a subscribed list AND
  // - Video author is NOT followed
  final showAttribution = isFromSubscribedList && !isFromFollowedUser;
}
```

---

## Files to Create/Modify

### New Files
- `lib/services/subscribed_list_video_cache.dart`
- `lib/widgets/video_feed_item/list_attribution_chip.dart`

### Modified Files
- `lib/providers/app_providers.dart` - Add cache provider
- `lib/providers/home_feed_provider.dart` - Merge video sources at line 257
- `lib/services/curated_list_service.dart` - Add sync triggers
- `lib/widgets/video_feed_item/video_feed_item.dart` - Add attribution chip

---

## Testing

### Unit Tests
- `SubscribedListVideoCache.syncList()` - fetches and caches videos
- `SubscribedListVideoCache.removeList()` - cleans up properly
- `SubscribedListVideoCache.getListsForVideo()` - returns correct list IDs
- Deduplication logic in HomeFeedProvider

### Widget Tests
- `ListAttributionChip` renders list name
- `ListAttributionChip` navigates on tap
- `VideoFeedItem` shows/hides attribution correctly

### Integration Tests
- Subscribe to list → videos appear in home feed
- Unsubscribe → videos removed from home feed
- Video in multiple lists → shows all list names
- Video from followed user in list → no attribution shown
