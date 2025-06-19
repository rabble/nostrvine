# Video Architecture Technical Notes

## Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           VIDEO SYSTEM FLOW                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    WebSocket    ┌─────────────────┐                      │
│  │ Nostr Relays │◀──────────────▶ │  NostrService   │                      │
│  │   (5 relays) │                 │ (WebSocket mgmt)│                      │
│  └──────────────┘                 └─────────────────┘                      │
│                                            │                               │
│                                            │ Stream<Event>                 │
│                                            ▼                               │
│                                   ┌─────────────────┐                      │
│                                   │VideoEventService│                      │
│                                   │ (Event filtering│                      │
│                                   │  & processing)  │                      │
│                                   └─────────────────┘                      │
│                                            │                               │
│                                            │ notifyListeners()             │
│                                            ▼                               │
│  ┌─────────────────┐              ┌─────────────────┐                      │
│  │VideoCacheService│◀────────────▶│VideoFeedProvider│                      │
│  │(Video preloading│              │(State coordination│                    │
│  │ & queue mgmt)   │              │  & UI binding)   │                    │
│  └─────────────────┘              └─────────────────┘                      │
│           │                               │                               │
│           │ VideoPlayerController         │ Provider<VideoFeedProvider>    │
│           │ management                    │                               │
│           ▼                               ▼                               │
│  ┌─────────────────┐              ┌─────────────────┐                      │
│  │  Controller     │              │   FeedScreen    │                      │
│  │   Storage       │              │ (PageView UI)   │                      │
│  │ (Map<String,    │              │                 │                      │
│  │ Controller>)    │              └─────────────────┘                      │
│  └─────────────────┘                       │                               │
│                                            │ PageView.builder()            │
│                                            ▼                               │
│                                   ┌─────────────────┐                      │
│                                   │ VideoFeedItem   │                      │
│                                   │(Individual video│                      │
│                                   │    widgets)     │                      │
│                                   └─────────────────┘                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Critical Data Flows

### 1. Video Event Processing Flow
```
Nostr EVENT → NostrService._handleEventMessage() 
├── Deduplicate (_seenEventIds)
├── Forward to VideoEventService
└── VideoEventService._handleNewVideoEvent()
    ├── Filter (kind==22, not seen, valid URL)
    ├── Create VideoEvent object  
    ├── Insert at _videoEvents[0] (newest first)
    └── notifyListeners() 
        └── VideoFeedProvider._onVideoEventServiceChanged()
            └── VideoCacheService.processNewVideoEvents()
                ├── GIF: Direct to ready queue
                └── Video: Batch preload (500ms timer)
                    └── Create VideoPlayerController
                        └── Add to ready queue
                            └── UI rebuild
```

### 2. User Scroll Processing Flow
```
User scrolls PageView → onPageChanged(index)
├── Near end check → loadMoreEvents() (historical query)
├── Preload trigger → preloadVideosAroundIndex()
│   └── VideoCacheService.preloadVideos()
│       ├── Network-aware strategy (WiFi=5, Cell=2, Web=1)
│       ├── Priority: current+1, current+2, current-1...
│       └── _preloadVideo() for each
└── VideoFeedItem activation
    ├── Active video → play() + markAsSeen()
    └── Inactive video → pause()
```

## State Management Issues

### The Dual List Problem
```dart
// PROBLEM: Two different video lists with different content/ordering
VideoEventService._videoEvents        // All events from Nostr (500+)
VideoCacheService._readyToPlayQueue   // Successfully preloaded videos (30-100)

// UI uses ready queue:
Widget build() {
  final videos = provider.videoEvents; // ← _readyToPlayQueue
  return PageView.builder(itemCount: videos.length, ...);
}

// But preloading uses all events:  
void preloadVideosAroundIndex(int index) {
  final allVideos = provider.allVideoEvents; // ← _videoEvents
  // INDEX MISMATCH: videos[5] != allVideos[5]
}
```

### Race Condition Timeline
```
T=0ms:   New Nostr event arrives
T=1ms:   Added to VideoEventService._videoEvents[0]
T=2ms:   UI rebuild shows loading spinner for new video  
T=500ms: Batch preload timer fires
T=800ms: VideoPlayerController.initialize() starts
T=1200ms: Controller ready → added to _readyToPlayQueue
T=1201ms: UI rebuild again with actual video

PROBLEM: 1200ms delay where UI shows video but can't play it
```

## Memory Management Concerns

### Controller Lifecycle
```dart
// CREATION (multiple sources):
1. VideoCacheService._preloadAndValidateSingleVideo() → shared controllers
2. VideoFeedItem._createLocalController() → private controllers  

// DISPOSAL (async cleanup):
Future.delayed(const Duration(milliseconds: 500), () {
  controller.dispose(); // Happens 500ms later!
});

// USAGE OVERLAP:
- Widget A using shared controller from cache
- Widget B creates local controller for same video  
- Cache cleanup disposes shared controller  
- Widget A crashes (use-after-dispose)
- Widget B leaks local controller
```

### Memory Growth Pattern
```
Time: 0min  → 50 videos   → 50 controllers  → ~1.5GB
Time: 5min  → 200 videos  → 100 controllers → ~3GB  
Time: 10min → 500 videos  → 100 controllers → ~3GB (plateau)

ISSUE: Growth plateau only works if cleanup timing is perfect.
If controllers leak, memory grows unbounded.
```

## Performance Bottlenecks

### Network Request Patterns
```
Initial app load:
├── 5 WebSocket connections (relay subscriptions)
├── 1-2 HTTP requests per video (URL + thumbnail)  
└── Preloading: 5 concurrent video streams

User scrolling:
├── New video preload requests (up to 5 concurrent)
├── Historical event queries (more WebSocket requests)
└── Profile image requests (if not cached)

PEAK: ~10-15 concurrent network requests during fast scrolling
```

### UI Rebuild Frequency
```
New video event:
├── VideoEventService.notifyListeners() → 30+ widgets rebuild
├── 500ms later: VideoCacheService.notifyListeners() → 30+ widgets rebuild  
├── Each VideoFeedItem.build() → checks cache for controller
└── Total: 60+ widget rebuilds per video event

OPTIMIZATION: Batching notifications to reduce rebuild frequency
```

## Known Bug Categories

### 1. Null Pointer Exceptions
- Accessing controller that was disposed
- Index out of bounds when lists get out of sync
- Null video URL after filtering

### 2. Memory Crashes  
- iOS app termination due to excessive memory usage
- Android ANR from blocking UI thread during preload
- WebSocket connection exhaustion

### 3. Playback Issues
- Black screen (controller exists but not initialized)
- Infinite loading spinner (initialization failed silently)
- Audio continues playing after video paused (Chewie bug)

### 4. Scroll Position Bugs
- Jump to wrong video after new events arrive
- Preloading wrong videos due to index mismatch
- PageView animation glitches during list updates

## Debugging Tools

### Logging Patterns
```dart
// Video lifecycle logging:
debugPrint('🎥 Video ${videoId.substring(0,8)} → ${status}');
debugPrint('📦 Cache: ${controllers.length}/${maxCached} controllers');
debugPrint('📱 Ready queue: ${readyQueue.length} videos');

// Performance logging:
final stopwatch = Stopwatch()..start();
// ... operation ...
debugPrint('⏱️ ${operation} took ${stopwatch.elapsedMilliseconds}ms');
```

### State Inspection
```dart
// In debug builds, expose state inspection:
Map<String, dynamic> getDebugInfo() {
  return {
    'videoEventsCount': _videoEvents.length,
    'readyQueueCount': _readyToPlayQueue.length,  
    'controllersCount': _controllers.length,
    'pendingPreloads': _pendingVideoIds.length,
    'memoryEstimate': '${_controllers.length * 30}MB',
  };
}
```

## Testing Strategies

### Unit Test Scenarios
```dart
testWidgets('video controller lifecycle', (tester) async {
  // 1. Create video event
  // 2. Verify controller creation  
  // 3. Simulate disposal
  // 4. Verify no memory leaks
});

testWidgets('dual list synchronization', (tester) async {
  // 1. Add events to VideoEventService
  // 2. Wait for preloading completion
  // 3. Verify ready queue matches expected order
  // 4. Test scroll position consistency
});
```

### Integration Test Scenarios  
```dart
testWidgets('memory growth under load', (tester) async {
  // 1. Simulate 100+ video events
  // 2. Fast scroll through all videos
  // 3. Monitor memory usage
  // 4. Verify cleanup happens properly
});

testWidgets('network failure handling', (tester) async {
  // 1. Mock network failures during preload
  // 2. Verify UI shows error states
  // 3. Test retry mechanisms
  // 4. Ensure no infinite loading states
});
```

---

This technical documentation should help anyone working on the video system understand the complex interactions and common failure modes.