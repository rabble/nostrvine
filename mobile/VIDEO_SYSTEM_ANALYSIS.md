# NostrVine Video Request & Queue Management System Analysis

## 🚨 CRITICAL ISSUES IDENTIFIED

This document analyzes the video management system that has been causing significant bugs and complexity in the NostrVine app. The system involves 5 interconnected components with multiple race conditions and performance issues.

---

## System Architecture Overview

The video system consists of 5 main components that work together in a complex chain:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  NostrService   │───▶│ VideoEventService │───▶│VideoFeedProvider│
│(Relay Events)   │    │ (Event Filtering) │    │  (State Coord)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │VideoCacheService│───▶│   FeedScreen    │
                       │ (Video Preload) │    │ (UI + PageView) │
                       └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │VideoControllers │    │ VideoFeedItem   │
                       │   (Playback)    │    │ (Individual UI) │
                       └─────────────────┘    └─────────────────┘
```

---

## Complete Video Flow Documentation

### 1. Initial App Load Flow

```
User opens app
└── FeedScreen._initializeFeed()
    └── VideoFeedProvider.initialize()
        ├── NostrService.initialize()
        │   ├── Connect to 5 default relays
        │   ├── Set up WebSocket connections
        │   └── Start event message processing
        ├── UserProfileService.initialize()
        └── VideoEventService.subscribeToVideoFeed()
            ├── Create Filter(kinds: [22], limit: 500, since: 30daysAgo)
            ├── NostrService.subscribeToEvents()
            │   └── Send REQ message to all connected relays
            └── Return Stream<Event> → _handleNewVideoEvent()
```

### 2. Event Processing Chain (THE COMPLEX PART)

```
Nostr Relay sends EVENT message
└── NostrService._handleEventMessage()
    ├── Parse raw WebSocket message
    ├── Deduplication check (_seenEventIds Set)
    ├── Forward to all _eventControllers
    └── VideoEventService._handleNewVideoEvent()
        ├── Filter checks:
        │   ├── Must be kind 22 (NIP-71 video events)
        │   ├── Must not be duplicate (by event.id)
        │   ├── Must not be "seen" before (SeenVideosService)
        │   └── Must have valid video URL
        ├── Create VideoEvent.fromNostrEvent()
        ├── Insert at index 0 of _videoEvents list
        └── notifyListeners() → Triggers cascade:
            └── VideoFeedProvider._onVideoEventServiceChanged()
                └── VideoCacheService.processNewVideoEvents()
                    ├── Check if video is GIF:
                    │   └── GIF: Add directly to _readyToPlayQueue
                    └── Real video: Add to _pendingVideoIds
                        └── Schedule batch processing Timer(500ms)
                            └── _preloadVideosInBatch()
                                └── For each pending video:
                                    └── _preloadAndValidateSingleVideo()
                                        ├── Create VideoPlayerController.networkUrl()
                                        ├── await controller.initialize()
                                        ├── controller.setLooping(true)
                                        ├── Validate video actually loads
                                        └── _addToReadyQueue()
                                            └── notifyListeners()
                                                └── VideoFeedProvider._onVideoCacheServiceChanged()
                                                    └── FeedScreen Consumer rebuilds with new videos
```

### 3. User Scrolling Flow

```
User scrolls PageView
└── PageView.onPageChanged(newIndex)
    ├── Check if near end: if newIndex >= readyVideoCount - 3
    │   └── VideoFeedProvider.loadMoreEvents()
    │       └── VideoEventService.loadMoreEvents()
    │           ├── Query historical events (until: oldestEvent.createdAt - 1)
    │           └── Same processing chain as above ↑
    ├── VideoFeedProvider.preloadVideosAroundIndex(newIndex)
    │   └── VideoCacheService.preloadVideos() → _preloadVideosAggressively()
    │       ├── Get network type (WiFi/Cellular/Web)
    │       ├── Calculate preload window:
    │       │   ├── WiFi: 5 videos ahead
    │       │   ├── Cellular: 2 videos ahead
    │       │   └── Web: 1 video ahead
    │       ├── Priority order: current+1, current+2, current-1, current+3...
    │       └── For each: _preloadVideo() (if not already cached)
    └── VideoFeedItem widgets update:
        └── didUpdateWidget() checks if video became active
            ├── If isActive: _handleVideoActivation()
            │   ├── Get controller from VideoCacheService
            │   ├── Create ChewieController wrapper
            │   └── _playVideo()
            │       ├── controller.play()
            │       └── SeenVideosService.markVideoAsSeen()
            └── If !isActive: _pauseVideo() → controller.pause()
```

---

## 🚨 CRITICAL RACE CONDITIONS & BUGS

### 1. **Dual Video Lists Problem**

**THE ISSUE**: The system maintains TWO different video lists that can get out of sync:

- `VideoEventService._videoEvents` (raw events from Nostr)
- `VideoCacheService._readyToPlayQueue` (processed, preloaded videos)

**RACE CONDITION**: 
```dart
// FeedScreen uses ready queue for display
videos: provider.videoEvents, // <- VideoCacheService._readyToPlayQueue

// But preloading uses raw events  
provider.preloadVideosAroundIndex(index); // <- Uses VideoEventService._videoEvents
```

**CONSEQUENCES**:
- Videos appear in UI before they're preloaded
- Preloading tries to load videos not in ready queue
- Scroll position jumps when lists get out of sync
- Null pointer exceptions when accessing mismatched indices

### 2. **Complex Notification Chain Cascade**

```
VideoEventService change
└── VideoFeedProvider listener (100ms batched)
    └── VideoCacheService.processNewVideoEvents()
        └── VideoFeedProvider listener (100ms batched)  
            └── FeedScreen Consumer rebuild
                └── 30+ VideoFeedItem widgets rebuild
                    └── Each checks VideoCacheService for controllers
```

**PROBLEMS**:
- Multiple UI rebuilds per video event (2-3x redundancy)
- 100ms notification batching masks deeper rebuild issues
- Memory pressure from frequent widget rebuilds
- UI lag during video loading

### 3. **VideoController Lifecycle Race Conditions**

**THE CRITICAL ISSUE**: VideoFeedItem has to handle controllers from multiple sources:

```dart
// Method 1: Get from cache (preferred)
final cachedController = context.read<VideoCacheService>().getController(widget.videoEvent);

// Method 2: Create locally (fallback)
if (cachedController == null) {
  _localController = VideoPlayerController.networkUrl(Uri.parse(widget.videoEvent.videoUrl!));
}
```

**RACE CONDITIONS**:
1. **Use-after-dispose**: Cache cleanup disposes controller while VideoFeedItem is using it
2. **Multiple ownership**: Several VideoFeedItems try to use same cached controller
3. **Initialization timing**: Controller fails to initialize but UI expects it to work
4. **Memory leaks**: Local controllers not properly disposed when cache controllers become available

### 4. **Multiple Overlapping Preload Systems**

The VideoCacheService runs 4 DIFFERENT preloading strategies simultaneously:

```dart
1. processNewVideoEvents() → Batch processing with 500ms timer
2. preloadVideos() → Aggressive preloading around current index
3. _preloadAndValidateSingleVideo() → Individual video preload  
4. Progressive cache scaling → 15→20→25→30→35 videos over time
```

**CONFLICTS**:
- Same video gets preloaded multiple times
- Race conditions between batch and individual loading
- Progressive scaling can trigger while user is scrolling
- Web vs mobile strategies conflict

### 5. **Memory Management Disasters**

```dart
// UNBOUNDED GROWTH:
_videoEvents.length        // Can grow to 500+ events
_seenEventIds.length      // Grows to 5000+ event IDs  
_controllers.length       // Limited to 100 but cleanup is async

// ASYNC DISPOSAL TIMING:
Future.delayed(const Duration(milliseconds: 500), () {
  controller.dispose(); // TOO LATE - already being used elsewhere
});
```

**MEMORY ISSUES**:
- VideoPlayerControllers use ~10-50MB each
- Event lists grow unbounded in memory
- 500ms disposal delay causes use-after-dispose bugs
- No cleanup on app backgrounding

---

## 🔍 Bug Reproduction Scenarios

### Scenario 1: "Video Won't Play"
```
1. User opens app → Events load into VideoEventService._videoEvents
2. VideoCacheService starts batch processing (500ms delay)
3. User immediately scrolls to video → UI shows video but no controller ready
4. VideoFeedItem tries to create local controller → NetworkUrl fails
5. Result: Black screen, no error handling
```

### Scenario 2: "Infinite Loading"
```
1. User scrolls fast → preloadVideosAroundIndex() triggered multiple times
2. Network is slow → controllers fail to initialize properly
3. Failed controllers remain in _controllers map but non-functional
4. UI keeps showing loading spinner forever
5. Progressive cache scaling makes it worse by preloading more
```

### Scenario 3: "Memory Crash"
```
1. User scrolls through 50+ videos quickly
2. All controllers remain in memory (100 video limit × 30MB = 3GB)
3. Cleanup happens 500ms later, but new videos already loading
4. iOS/Android kills app due to memory pressure
```

### Scenario 4: "Videos Out of Order"
```
1. New events arrive in VideoEventService → _videoEvents.insert(0, event)
2. Some videos fail preloading → not added to _readyToPlayQueue  
3. UI shows different order than expected
4. User scroll position becomes wrong (index 5 shows different video)
```

---

## 📊 Performance Impact Analysis

### Network Requests
```
Initial load: 5 relays × REQ message = 5 WebSocket requests
Per video: 1 HTTP video URL + optional thumbnail = 1-2 requests
Preloading: Up to 5 videos × 1-2 requests = 5-10 concurrent requests
```

### Memory Usage (Estimated)
```
VideoPlayerController: ~30MB each × 100 cached = 3GB potential
Event objects: ~1KB each × 500 events = 500KB
UI widgets: ~100KB per VideoFeedItem × 30 visible = 3MB
Total: Up to 3GB+ memory usage possible
```

### CPU Usage Hotspots
```
1. JSON parsing of Nostr events (VideoEvent.fromNostrEvent)
2. VideoPlayerController.initialize() - native video decoding setup
3. Widget rebuilds from notification cascades
4. Timer management (batch processing, cleanup delays)
```

---

## 🛠️ RECOMMENDED SOLUTIONS

### 1. **Unify Video Lists** (Critical Priority)
```dart
// BEFORE: Two separate lists
VideoEventService._videoEvents          // Raw events
VideoCacheService._readyToPlayQueue     // Processed videos

// AFTER: Single source of truth  
class VideoFeedService {
  List<ProcessedVideo> _videos;  // Only list that matters
  // ProcessedVideo contains: event + controller + loadingState
}
```

### 2. **Simplify Preloading Strategy**
```dart
// BEFORE: 4 different preloading systems
// AFTER: One simple rule
void preloadAroundIndex(int currentIndex) {
  final ahead = isWifi ? 3 : 1;
  for (int i = currentIndex; i <= currentIndex + ahead; i++) {
    if (!isLoaded(i)) startLoading(i);
  }
}
```

### 3. **Fix Controller Lifecycle**
```dart
// BEFORE: Mixed ownership between cache and widgets
// AFTER: Single controller manager
class VideoControllerManager {
  VideoPlayerController getController(String videoId) {
    return _controllers[videoId] ??= VideoPlayerController.networkUrl(...);
  }
  
  void disposeController(String videoId) {
    _controllers.remove(videoId)?.dispose(); // Immediate disposal
  }
}
```

### 4. **Remove Notification Batching**
```dart
// BEFORE: Timer(100ms) to batch notifications
// AFTER: Direct notifications with proper state management
// Fix the root cause of rapid rebuilds instead of masking it
```

### 5. **Implement Proper Error Handling**
```dart
class VideoLoadState {
  final bool isLoading;
  final bool isLoaded; 
  final bool hasFailed;
  final String? errorMessage;
  
  // Clear states instead of guessing what went wrong
}
```

---

## 📝 CONCLUSION

The current video system has **at least 5 major race conditions** and **3 different memory leak sources**. The complexity comes from:

1. **Too many responsibilities** split across services
2. **Overlapping async operations** without proper coordination  
3. **Dual state management** (raw events vs processed videos)
4. **Complex notification chains** with batching timers
5. **Inconsistent error handling** throughout the pipeline

**The core issue**: This system grew organically without a clear architectural plan, resulting in multiple components trying to solve the same problems in different ways.

**Priority Fix**: Unify the video lists into a single source of truth. This single change would eliminate most of the race conditions and make debugging much easier.

This analysis explains why video loading has been "very complicated and confusing and buggy" - the system has fundamental architectural issues that compound as users scroll through more videos.