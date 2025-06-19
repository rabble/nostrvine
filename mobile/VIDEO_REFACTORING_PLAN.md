# NostrVine Video System Refactoring Plan

## 🎯 EXECUTIVE SUMMARY

The current video system has **5 critical race conditions** and **fundamental architectural flaws** that make it "very complicated and confusing and buggy." This plan provides a systematic approach to refactor the system into a simpler, more reliable architecture.

**Primary Goal**: Eliminate the dual video list problem and create a single source of truth for video state.

---

## 📊 CURRENT STATE ANALYSIS

### Critical Issues Identified
1. **🚨 Dual Video Lists**: Two separate lists that get out of sync
2. **⚡ Race Conditions**: 5 major areas causing crashes and bugs  
3. **🧠 Memory Leaks**: 3 sources causing unbounded growth (up to 3GB)
4. **🔄 Complex Notification Chains**: Multiple rebuild cycles per event
5. **📱 Poor Error Handling**: Silent failures causing black screens

### Performance Impact
- **Memory**: Up to 3GB possible (100 controllers × 30MB each)
- **Network**: 10-15 concurrent requests during scrolling
- **CPU**: 60+ widget rebuilds per video event
- **User Experience**: Videos fail to play, infinite loading, crashes

---

## 🏗️ NEW ARCHITECTURE DESIGN

### Phase 1: Single Source of Truth (CRITICAL)

**Goal**: Replace dual video lists with unified video state management.

#### 1.1 Create Unified Video State Model
```dart
// NEW: Single video state that combines everything
class VideoState {
  final VideoEvent event;
  final VideoPlayerController? controller;
  final VideoLoadingState loadingState;
  final String? errorMessage;
  final DateTime lastUpdated;
  
  // States: notLoaded, loading, ready, error, disposed
  bool get isReady => loadingState == VideoLoadingState.ready && controller?.value.isInitialized == true;
  bool get isLoading => loadingState == VideoLoadingState.loading;
  bool get hasError => loadingState == VideoLoadingState.error;
}

enum VideoLoadingState {
  notLoaded,    // Initial state
  loading,      // Controller being created/initialized
  ready,        // Ready to play
  error,        // Failed to load
  disposed,     // Cleaned up
}
```

#### 1.2 Create Unified Video Manager Service
```dart
// NEW: Single service that owns ALL video state
class VideoManagerService extends ChangeNotifier {
  final Map<String, VideoState> _videos = {}; // Single source of truth
  final List<String> _orderedVideoIds = [];    // Display order
  
  // REPLACES: VideoEventService._videoEvents + VideoCacheService._readyToPlayQueue
  List<VideoEvent> get displayVideos => _orderedVideoIds
      .map((id) => _videos[id])
      .where((state) => state != null && !state!.hasError)
      .map((state) => state!.event)
      .toList();
  
  List<VideoState> get readyVideos => _videos.values
      .where((state) => state.isReady)
      .toList();
}
```

### Phase 2: Simplify Event Processing

#### 2.1 Direct Event Flow
```
NostrService → VideoManagerService → UI
```
**ELIMINATES**: VideoEventService + VideoCacheService + VideoFeedProvider complexity

#### 2.2 Simplified Event Processing
```dart
class VideoManagerService {
  // Single method to handle new events from Nostr
  void processNostrEvent(Event event) {
    if (event.kind != 22) return;
    if (_videos.containsKey(event.id)) return; // Duplicate check
    
    final videoEvent = VideoEvent.fromNostrEvent(event);
    final videoState = VideoState(
      event: videoEvent,
      controller: null,
      loadingState: VideoLoadingState.notLoaded,
      errorMessage: null,
      lastUpdated: DateTime.now(),
    );
    
    _videos[event.id] = videoState;
    _orderedVideoIds.insert(0, event.id); // Newest first
    
    // Start preloading if needed
    _schedulePreload(event.id);
    
    notifyListeners(); // Single notification
  }
}
```

### Phase 3: Controller Lifecycle Management

#### 3.1 Single Controller Ownership
```dart
class VideoManagerService {
  // ONLY this service creates/owns/disposes controllers
  Future<void> preloadVideo(String videoId) async {
    final videoState = _videos[videoId];
    if (videoState?.isLoading == true || videoState?.isReady == true) return;
    
    // Update state to loading
    _updateVideoState(videoId, 
      loadingState: VideoLoadingState.loading,
    );
    
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoState!.event.videoUrl!)
      );
      
      await controller.initialize();
      controller.setLooping(true);
      
      // Update state to ready
      _updateVideoState(videoId,
        controller: controller,
        loadingState: VideoLoadingState.ready,
      );
      
    } catch (e) {
      // Update state to error
      _updateVideoState(videoId,
        loadingState: VideoLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }
  
  void disposeVideo(String videoId) {
    final videoState = _videos[videoId];
    videoState?.controller?.dispose(); // Immediate disposal
    
    _updateVideoState(videoId,
      controller: null,
      loadingState: VideoLoadingState.disposed,
    );
  }
}
```

#### 3.2 Widget-Service Interface
```dart
class VideoFeedItem extends StatefulWidget {
  // Widgets NEVER create controllers - only request them
  Widget build(context) {
    return Consumer<VideoManagerService>(
      builder: (context, videoManager, child) {
        final videoState = videoManager.getVideoState(widget.videoEvent.id);
        
        if (videoState?.isReady == true) {
          return _buildVideoPlayer(videoState!.controller!);
        } else if (videoState?.isLoading == true) {
          return _buildLoadingSpinner();
        } else if (videoState?.hasError == true) {
          return _buildErrorWidget(videoState!.errorMessage);
        } else {
          // Request preload
          videoManager.requestPreload(widget.videoEvent.id);
          return _buildLoadingSpinner();
        }
      },
    );
  }
}
```

---

## 📅 IMPLEMENTATION PHASES

### 🚀 Phase 1: Foundation (Week 1)
**Goal**: Establish new architecture without breaking existing functionality

#### Day 1-2: Create New Services
- [ ] Create `VideoState` model
- [ ] Create `VideoManagerService` skeleton
- [ ] Add comprehensive logging for debugging
- [ ] Unit tests for new models

#### Day 3-4: Parallel Implementation
- [ ] Implement `VideoManagerService.processNostrEvent()`
- [ ] Implement `VideoManagerService.preloadVideo()`
- [ ] Keep existing services running in parallel
- [ ] Add comparison logging (old vs new)

#### Day 5-7: Integration Testing
- [ ] Wire NostrService to feed both old and new systems
- [ ] Compare outputs for consistency
- [ ] Performance testing with new system
- [ ] Fix any discrepancies

### 🔄 Phase 2: Migration (Week 2)
**Goal**: Switch UI to use new system

#### Day 1-3: Update VideoFeedProvider
- [ ] Replace dual list getters with single list
- [ ] Update all references to use VideoManagerService
- [ ] Remove VideoEventService dependencies
- [ ] Remove VideoCacheService dependencies

#### Day 4-5: Update UI Components
- [ ] Update FeedScreen to use new provider
- [ ] Update VideoFeedItem to use new controller access
- [ ] Remove local controller creation fallbacks
- [ ] Add proper error handling UI

#### Day 6-7: Testing & Refinement
- [ ] Integration testing on multiple devices
- [ ] Memory leak testing
- [ ] Performance validation
- [ ] Bug fixes and optimizations

### 🧹 Phase 3: Cleanup (Week 3)
**Goal**: Remove old system and optimize

#### Day 1-3: Remove Legacy Code
- [ ] Delete `VideoEventService`
- [ ] Delete `VideoCacheService` 
- [ ] Simplify `VideoFeedProvider`
- [ ] Remove notification batching timers
- [ ] Clean up dead imports

#### Day 4-5: Optimization
- [ ] Implement smart preloading based on scroll direction
- [ ] Add memory pressure monitoring
- [ ] Optimize notification patterns
- [ ] Add comprehensive error recovery

#### Day 6-7: Final Testing
- [ ] Full regression testing
- [ ] Performance benchmarking
- [ ] Memory usage validation
- [ ] User acceptance testing

### 🎯 Phase 4: Advanced Features (Week 4)
**Goal**: Add reliability and performance improvements

#### Day 1-3: Smart Preloading
- [ ] Implement scroll direction detection
- [ ] Adaptive preloading based on network speed
- [ ] Intelligent memory management
- [ ] Background/foreground optimization

#### Day 4-5: Error Recovery
- [ ] Automatic retry for failed videos
- [ ] Network change handling
- [ ] Graceful degradation for poor connections
- [ ] User feedback for persistent errors

#### Day 6-7: Monitoring & Analytics
- [ ] Add performance metrics
- [ ] Memory usage tracking
- [ ] Error rate monitoring
- [ ] User experience analytics

---

## 🎛️ SPECIFIC REFACTORING STEPS

### Step 1: Create VideoState Model
```dart
// lib/models/video_state.dart
enum VideoLoadingState {
  notLoaded,
  loading, 
  ready,
  error,
  disposed,
}

class VideoState {
  final VideoEvent event;
  final VideoPlayerController? controller;
  final VideoLoadingState loadingState;
  final String? errorMessage;
  final DateTime lastUpdated;
  
  const VideoState({
    required this.event,
    this.controller,
    required this.loadingState,
    this.errorMessage,
    required this.lastUpdated,
  });
  
  VideoState copyWith({
    VideoPlayerController? controller,
    VideoLoadingState? loadingState,
    String? errorMessage,
  }) {
    return VideoState(
      event: event,
      controller: controller ?? this.controller,
      loadingState: loadingState ?? this.loadingState,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdated: DateTime.now(),
    );
  }
  
  bool get isReady => loadingState == VideoLoadingState.ready && 
                     controller?.value.isInitialized == true;
  bool get isLoading => loadingState == VideoLoadingState.loading;
  bool get hasError => loadingState == VideoLoadingState.error;
  bool get isDisposed => loadingState == VideoLoadingState.disposed;
}
```

### Step 2: Create VideoManagerService
```dart
// lib/services/video_manager_service.dart
class VideoManagerService extends ChangeNotifier {
  final Map<String, VideoState> _videos = {};
  final List<String> _orderedVideoIds = [];
  final Set<String> _preloadQueue = {};
  
  // Configuration
  final int _maxCachedVideos = 50; // Reduced from 100
  final int _preloadAhead = 3;     // Simplified from network-aware
  
  // Single source of truth for video list
  List<VideoEvent> get videos => _orderedVideoIds
      .map((id) => _videos[id])
      .where((state) => state != null && !state.hasError)
      .map((state) => state!.event)
      .toList();
  
  VideoState? getVideoState(String videoId) => _videos[videoId];
  
  VideoPlayerController? getController(String videoId) {
    final state = _videos[videoId];
    return state?.isReady == true ? state!.controller : null;
  }
  
  // Process new event from Nostr
  void addVideoEvent(VideoEvent event) {
    if (_videos.containsKey(event.id)) return;
    
    final videoState = VideoState(
      event: event,
      loadingState: VideoLoadingState.notLoaded,
      lastUpdated: DateTime.now(),
    );
    
    _videos[event.id] = videoState;
    _orderedVideoIds.insert(0, event.id);
    
    // Cleanup old videos if we have too many
    _cleanupOldVideos();
    
    notifyListeners();
  }
  
  // Preload video for smooth playback
  Future<void> preloadVideo(String videoId) async {
    if (_preloadQueue.contains(videoId)) return;
    
    final videoState = _videos[videoId];
    if (videoState == null || videoState.isLoading || videoState.isReady) return;
    
    _preloadQueue.add(videoId);
    
    try {
      // Update to loading state
      _videos[videoId] = videoState.copyWith(
        loadingState: VideoLoadingState.loading,
      );
      notifyListeners();
      
      // Create and initialize controller
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoState.event.videoUrl!),
      );
      
      await controller.initialize();
      controller.setLooping(true);
      
      // Update to ready state
      _videos[videoId] = videoState.copyWith(
        controller: controller,
        loadingState: VideoLoadingState.ready,
      );
      
    } catch (e) {
      // Update to error state
      _videos[videoId] = videoState.copyWith(
        loadingState: VideoLoadingState.error,
        errorMessage: e.toString(),
      );
    } finally {
      _preloadQueue.remove(videoId);
      notifyListeners();
    }
  }
  
  // Preload videos around current position
  void preloadAroundIndex(int currentIndex) {
    for (int i = currentIndex; i <= currentIndex + _preloadAhead; i++) {
      if (i < _orderedVideoIds.length) {
        preloadVideo(_orderedVideoIds[i]);
      }
    }
  }
  
  // Cleanup old videos to manage memory
  void _cleanupOldVideos() {
    if (_videos.length <= _maxCachedVideos) return;
    
    final videosToRemove = _orderedVideoIds.skip(_maxCachedVideos).toList();
    for (final videoId in videosToRemove) {
      final videoState = _videos.remove(videoId);
      videoState?.controller?.dispose();
      _orderedVideoIds.remove(videoId);
    }
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    for (final state in _videos.values) {
      state.controller?.dispose();
    }
    _videos.clear();
    _orderedVideoIds.clear();
    _preloadQueue.clear();
    super.dispose();
  }
}
```

### Step 3: Update VideoFeedProvider
```dart
// lib/providers/video_feed_provider.dart (SIMPLIFIED)
class VideoFeedProvider extends ChangeNotifier {
  final VideoManagerService _videoManager;
  final VideoEventService _videoEventService; // Still needed for Nostr events
  
  VideoFeedProvider({
    required VideoManagerService videoManager,
    required VideoEventService videoEventService,
  }) : _videoManager = videoManager,
       _videoEventService = videoEventService {
    
    // Listen to Nostr events and forward to video manager
    _videoEventService.addListener(_onNewVideoEvents);
  }
  
  // SIMPLIFIED: Single video list
  List<VideoEvent> get videos => _videoManager.videos;
  
  void _onNewVideoEvents() {
    // Forward new events to video manager
    for (final event in _videoEventService.videoEvents) {
      _videoManager.addVideoEvent(event);
    }
  }
  
  void preloadVideosAroundIndex(int index) {
    _videoManager.preloadAroundIndex(index);
  }
}
```

### Step 4: Update VideoFeedItem
```dart
// lib/widgets/video_feed_item.dart (SIMPLIFIED)
class VideoFeedItem extends StatelessWidget {
  final VideoEvent videoEvent;
  final bool isActive;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<VideoManagerService>(
      builder: (context, videoManager, child) {
        final videoState = videoManager.getVideoState(videoEvent.id);
        
        if (videoState?.isReady == true) {
          return _VideoPlayer(
            controller: videoState!.controller!,
            isActive: isActive,
          );
        } else if (videoState?.isLoading == true) {
          return _LoadingWidget();
        } else if (videoState?.hasError == true) {
          return _ErrorWidget(error: videoState!.errorMessage);
        } else {
          // Request preload and show loading
          if (isActive) {
            videoManager.preloadVideo(videoEvent.id);
          }
          return _LoadingWidget();
        }
      },
    );
  }
}
```

---

## 🧪 TESTING STRATEGY

### Unit Tests
```dart
testWidgets('VideoManagerService manages single source of truth', (tester) async {
  final service = VideoManagerService();
  
  // Add video event
  final event = VideoEvent(id: 'test', videoUrl: 'http://test.mp4');
  service.addVideoEvent(event);
  
  expect(service.videos.length, 1);
  expect(service.getVideoState('test')?.loadingState, VideoLoadingState.notLoaded);
  
  // Preload video
  await service.preloadVideo('test');
  
  expect(service.getVideoState('test')?.isReady, true);
  expect(service.getController('test'), isNotNull);
});
```

### Integration Tests
```dart
testWidgets('video system handles rapid scrolling', (tester) async {
  // Simulate user rapidly scrolling through videos
  // Verify no memory leaks or crashes
  // Verify controllers are properly managed
});

testWidgets('video system recovers from network errors', (tester) async {
  // Mock network failures during video loading
  // Verify proper error states and recovery
});
```

### Memory Tests
```dart
testWidgets('video system manages memory usage', (tester) async {
  // Load 100+ videos
  // Verify memory usage stays under limit
  // Verify old videos are properly cleaned up
});
```

---

## 📈 SUCCESS METRICS

### Performance Targets
- **Memory Usage**: Stay under 500MB (down from 3GB)
- **Video Load Time**: <2 seconds average (current: varies widely)
- **UI Responsiveness**: <16ms frame time (60fps)
- **Crash Rate**: <0.1% (current: unknown but high)

### Reliability Targets
- **Video Play Success Rate**: >95% (current: ~80-90%)
- **Index Mismatch Bugs**: 0 (current: frequent)
- **Memory Leaks**: 0 detected in 1-hour usage
- **Race Conditions**: 0 detected in stress testing

### Code Quality Targets
- **Cyclomatic Complexity**: <10 per method (current: 15-20)
- **Lines of Code**: Reduce by 30% (eliminate duplicate functionality)
- **Test Coverage**: >90% for video system
- **Documentation**: Complete inline docs for all public methods

---

## 🚀 MIGRATION STRATEGY

### Risk Mitigation
1. **Feature Flags**: Use flags to switch between old/new systems
2. **Parallel Running**: Run both systems simultaneously during transition
3. **Rollback Plan**: Keep old system for 1 week after migration
4. **Monitoring**: Add extensive logging during migration
5. **User Testing**: Test with subset of users before full rollout

### Deployment Plan
1. **Development**: Complete implementation in feature branch
2. **Testing**: Extensive QA testing on staging environment
3. **Canary**: Deploy to 10% of users with monitoring
4. **Gradual Rollout**: Increase to 50%, then 100% over 1 week
5. **Cleanup**: Remove old system after 1 week of stable operation

---

## 💡 LONG-TERM BENEFITS

### Developer Experience
- **Easier Debugging**: Single source of truth eliminates confusion
- **Faster Development**: Less complex architecture = faster feature development
- **Better Testing**: Simpler system = easier to write comprehensive tests
- **Reduced Bugs**: Fewer race conditions = more reliable app

### User Experience
- **Faster Video Loading**: Optimized preloading without redundancy
- **Smoother Scrolling**: No index mismatches or UI glitches
- **Better Memory Usage**: Longer app usage without crashes
- **More Reliable Playback**: Proper error handling and recovery

### Business Impact
- **Higher User Retention**: More reliable app = happier users
- **Lower Support Costs**: Fewer crash reports and bug reports
- **Faster Feature Delivery**: Simpler architecture = faster development
- **Better App Store Ratings**: More stable app = better reviews

---

This refactoring plan addresses the root causes of the video system complexity while providing a clear path to a more maintainable and reliable architecture.