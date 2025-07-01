# VideoEventBridge Analysis & Riverpod Migration Design

## 📊 Current Architecture Analysis

### VideoEventBridge Dependencies Map
```
VideoEventBridge (360 lines)
├── VideoEventService (Nostr event subscription/management)
├── VideoManagerInterface/VideoManagerService (UI state management)
├── UserProfileService (profile fetching/caching)
├── SocialService (following list, likes, reposts)
└── CurationService (content discovery, editor picks)
```

### Key Responsibilities
1. **Event Flow Coordination**: Bridges Nostr events → VideoManager
2. **Feed Prioritization**: Following feed → Discovery feed
3. **Profile Batch Fetching**: Deduplicates profile requests
4. **Memory Management**: Coordinates preloading strategies
5. **Discovery Feed Logic**: Fallback timers and conditional loading

### Current Pain Points
1. **Manual Coordination**: Complex timer-based discovery feed loading
2. **State Synchronization**: Following list changes don't auto-update feed
3. **Imperative Logic**: Lots of conditional checks and manual state tracking
4. **Profile Race Conditions**: Manual deduplication with `_requestedProfiles` Set
5. **Discovery Feed Timing**: Multiple fallback timers with hardcoded delays

## 🎯 Target Riverpod Architecture

### Provider Dependency Graph
```
videoFeedProvider
├── socialDataProvider (following list)
├── videoEventsProvider (raw Nostr events)
├── userProfilesProvider (profile cache)
├── curationProvider (content discovery)
└── feedModeProvider (following/discovery/curated)
```

### Core Providers Design

#### 1. Video Events Provider (Replaces VideoEventService subscription)
```dart
@riverpod
class VideoEvents extends _$VideoEvents {
  @override
  Stream<List<VideoEvent>> build() async* {
    final nostrService = ref.watch(nostrServiceProvider);
    final subscriptionManager = ref.watch(subscriptionManagerProvider);
    
    // Auto-restart subscription on connection changes
    ref.listen(connectionStatusProvider, (_, __) {
      ref.invalidateSelf();
    });
    
    yield* _subscribeToVideoEvents(nostrService, subscriptionManager);
  }
  
  Stream<List<VideoEvent>> _subscribeToVideoEvents(
    INostrService nostrService,
    SubscriptionManager subscriptionManager,
  ) async* {
    final events = <VideoEvent>[];
    
    // Create subscription based on current feed mode
    final feedMode = ref.watch(feedModeProvider);
    final filter = _createFilter(feedMode);
    
    await for (final event in nostrService.subscribeToEvents(filters: [filter])) {
      try {
        final videoEvent = VideoEvent.fromNostrEvent(event);
        events.add(videoEvent);
        yield List.from(events); // Emit immutable copy
      } catch (e) {
        ref.read(errorLoggerProvider).logError('Video parsing error', e);
      }
    }
  }
}
```

#### 2. Feed Mode Provider (Controls what content to show)
```dart
enum FeedMode {
  following,    // User's following list
  curated,      // Classic vines only
  discovery,    // General content
  hashtag,      // Specific hashtag
  profile,      // Specific user
}

@riverpod
class FeedModeNotifier extends _$FeedModeNotifier {
  @override
  FeedMode build() => FeedMode.following;
  
  void setMode(FeedMode mode) => state = mode;
  
  void setHashtag(String hashtag) {
    state = FeedMode.hashtag;
    ref.read(feedContextProvider.notifier).setContext(hashtag);
  }
  
  void setProfile(String pubkey) {
    state = FeedMode.profile;
    ref.read(feedContextProvider.notifier).setContext(pubkey);
  }
}

@riverpod
class FeedContext extends _$FeedContext {
  @override
  String? build() => null;
  
  void setContext(String? context) => state = context;
}
```

#### 3. Video Feed Provider (Main orchestrator - replaces VideoEventBridge)
```dart
@riverpod
class VideoFeed extends _$VideoFeed {
  @override
  Future<VideoFeedState> build() async {
    // Watch dependencies - auto-updates when they change
    final feedMode = ref.watch(feedModeProvider);
    final followingList = ref.watch(socialDataProvider.select((s) => s.followingPubkeys));
    final videoEvents = await ref.watch(videoEventsProvider.future);
    final curationSets = ref.watch(curationProvider);
    
    // Determine primary content source
    final primaryPubkeys = _getPrimaryPubkeys(feedMode, followingList);
    
    // Filter and sort videos
    final filteredVideos = _filterVideos(videoEvents, feedMode, primaryPubkeys);
    final sortedVideos = _sortVideos(filteredVideos, feedMode);
    
    // Auto-fetch profiles for new videos
    _scheduleBatchProfileFetch(sortedVideos);
    
    return VideoFeedState(
      videos: sortedVideos,
      feedMode: feedMode,
      isFollowingFeed: feedMode == FeedMode.following,
      hasMoreContent: _hasMoreContent(sortedVideos),
      primaryVideoCount: _countPrimaryVideos(sortedVideos, primaryPubkeys),
    );
  }
  
  Set<String> _getPrimaryPubkeys(FeedMode mode, List<String> followingList) {
    return switch (mode) {
      FeedMode.following => followingList.isNotEmpty 
          ? followingList.toSet() 
          : {AppConstants.classicVinesPubkey}, // Fallback
      FeedMode.curated => {AppConstants.classicVinesPubkey},
      FeedMode.profile => {ref.read(feedContextProvider) ?? ''},
      _ => {},
    };
  }
  
  void _scheduleBatchProfileFetch(List<VideoEvent> videos) {
    final profilesProvider = ref.read(userProfilesProvider.notifier);
    final newPubkeys = videos
        .map((v) => v.pubkey)
        .where((pubkey) => !profilesProvider.hasProfile(pubkey))
        .toSet()
        .toList();
    
    if (newPubkeys.isNotEmpty) {
      // Profile provider handles deduplication internally
      profilesProvider.fetchMultipleProfiles(newPubkeys);
    }
  }
  
  // User actions
  Future<void> loadMore() async {
    state = const AsyncLoading();
    try {
      await ref.read(videoEventsProvider.notifier).loadMoreEvents();
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
  
  Future<void> refresh() async {
    ref.invalidate(videoEventsProvider);
    ref.invalidateSelf();
  }
}
```

#### 4. Video Manager Integration Provider
```dart
@riverpod
class VideoManagerIntegration extends _$VideoManagerIntegration {
  Timer? _preloadTimer;
  
  @override
  VideoManagerState build() {
    final videoManager = ref.watch(videoManagerServiceProvider);
    
    // Auto-sync videos from feed to manager
    ref.listen(videoFeedProvider, (previous, next) {
      next.whenData((feedState) {
        _syncVideosToManager(feedState.videos, videoManager);
      });
    });
    
    // Handle memory pressure
    ref.listen(memoryPressureProvider, (_, hasPresure) {
      if (hasPresure) {
        videoManager.handleMemoryPressure();
      }
    });
    
    return VideoManagerState(
      isReady: true,
      videoCount: videoManager.videos.length,
      readyCount: videoManager.readyVideos.length,
      memoryUsageMB: videoManager.getDebugInfo()['estimatedMemoryMB'] ?? 0,
    );
  }
  
  void _syncVideosToManager(List<VideoEvent> videos, IVideoManager manager) async {
    final existingIds = manager.videos.map((v) => v.id).toSet();
    final newVideos = videos.where((v) => !existingIds.contains(v.id));
    
    for (final video in newVideos) {
      await manager.addVideoEvent(video);
    }
    
    // Preload first videos immediately
    if (manager.videos.isNotEmpty && existingIds.isEmpty) {
      _preloadTimer?.cancel();
      _preloadTimer = Timer(Duration.zero, () {
        manager.preloadAroundIndex(0);
      });
    }
  }
  
  void preloadAroundIndex(int index) {
    final videoManager = ref.read(videoManagerServiceProvider);
    videoManager.preloadAroundIndex(index);
  }
}
```

#### 5. Curation Provider (Replaces CurationService integration)
```dart
@riverpod
class Curation extends _$Curation {
  @override
  Future<CurationState> build() async {
    final curationService = ref.watch(curationServiceProvider);
    
    // Auto-refresh when video events change
    ref.listen(videoEventsProvider, (_, __) {
      curationService.refreshIfNeeded();
    });
    
    return CurationState(
      editorsPicks: curationService.getVideosForSetType(CurationSetType.editorsPicks),
      trending: curationService.getVideosForSetType(CurationSetType.trending),
      featured: curationService.getVideosForSetType(CurationSetType.featured),
      isLoading: curationService.isLoading,
    );
  }
  
  Future<void> refreshTrending() async {
    final curationService = ref.read(curationServiceProvider);
    await curationService.refreshTrendingFromAnalytics();
    ref.invalidateSelf();
  }
}
```

### State Models

```dart
// lib/state/video_feed_state.dart
@freezed
class VideoFeedState with _$VideoFeedState {
  const factory VideoFeedState({
    required List<VideoEvent> videos,
    required FeedMode feedMode,
    required bool isFollowingFeed,
    required bool hasMoreContent,
    required int primaryVideoCount,
    @Default(false) bool isLoadingMore,
    String? error,
  }) = _VideoFeedState;
}

// lib/state/video_manager_state.dart
@freezed
class VideoManagerState with _$VideoManagerState {
  const factory VideoManagerState({
    required bool isReady,
    required int videoCount,
    required int readyCount,
    required int memoryUsageMB,
    @Default(false) bool isPreloading,
    String? lastError,
  }) = _VideoManagerState;
}

// lib/state/curation_state.dart
@freezed
class CurationState with _$CurationState {
  const factory CurationState({
    required List<VideoEvent> editorsPicks,
    required List<VideoEvent> trending,
    required List<VideoEvent> featured,
    required bool isLoading,
    String? error,
  }) = _CurationState;
}
```

## 🔄 Migration Strategy

### Phase 1: Parallel Implementation (Week 3-4)
1. Create all new providers alongside VideoEventBridge
2. Add feature flag for switching between old/new
3. Mirror VideoEventBridge functionality in providers
4. Add comprehensive logging for comparison

### Phase 2: A/B Testing (Week 5)
1. Enable new providers for 10% of users
2. Monitor performance metrics
3. Compare behavior between old and new
4. Fix any discrepancies

### Phase 3: Gradual Rollout (Week 6)
1. Increase to 50% of users
2. Monitor for edge cases
3. Performance optimization
4. Full rollout when stable

## ✅ Benefits of New Architecture

### 1. Automatic Reactive Updates
- Following list changes instantly update feed
- No manual coordination needed
- Profile updates propagate automatically

### 2. Simplified Logic
- No manual timers for discovery feed
- No race condition handling
- Declarative state management

### 3. Better Testing
- Each provider testable in isolation
- Easy to mock dependencies
- Clear data flow

### 4. Performance
- Automatic disposal of unused resources
- Granular rebuilds with select()
- Built-in caching

### 5. Developer Experience
- Clear dependency graph
- Self-documenting code
- Less boilerplate

## 🧪 Testing Plan

### Unit Tests
- Each provider tested independently
- Mock all dependencies
- Test state transitions
- Test error scenarios

### Integration Tests
- Test provider interactions
- Verify auto-updates work
- Test performance characteristics
- Memory usage validation

### Example Test
```dart
test('video feed updates when following list changes', () async {
  final container = ProviderContainer();
  
  // Initial state with no follows
  var feedState = await container.read(videoFeedProvider.future);
  expect(feedState.videos, isEmpty);
  
  // Add a follow
  container.read(socialDataProvider.notifier).toggleFollow('user123');
  
  // Feed should auto-update
  feedState = await container.read(videoFeedProvider.future);
  expect(feedState.videos.where((v) => v.pubkey == 'user123'), isNotEmpty);
});
```

## 📋 Implementation Checklist

- [ ] Create state models with freezed
- [ ] Implement VideoEvents provider
- [ ] Implement FeedMode provider
- [ ] Implement VideoFeed provider
- [ ] Implement VideoManagerIntegration provider
- [ ] Implement Curation provider
- [ ] Create feature flag system
- [ ] Add comparison logging
- [ ] Write comprehensive tests
- [ ] Create migration adapter
- [ ] Document provider dependencies
- [ ] Performance benchmarks