# Video System Refactoring Implementation Roadmap

## 🎯 IMMEDIATE ACTION PLAN (Next 2 Weeks)

Based on the comprehensive analysis in `VIDEO_SYSTEM_ANALYSIS.md` and the strategic plan in `VIDEO_REFACTORING_PLAN.md`, here's a concrete implementation roadmap that addresses the critical issues.

---

## 🚨 QUICK WINS (Days 1-3) - Immediate Stability

These changes can be implemented immediately to reduce crashes and improve reliability without major architectural changes.

### Quick Win 1: Fix Controller Disposal Race Condition
**Problem**: 500ms delayed disposal causes use-after-dispose crashes  
**Solution**: Immediate disposal with proper null checks

```dart
// In VideoCacheService
void disposeVideo(String videoId) {
  final controller = _controllers.remove(videoId);
  _initializationStatus.remove(videoId);
  
  // IMMEDIATE disposal instead of 500ms delay
  if (controller != null) {
    try {
      controller.dispose();
      debugPrint('🗑️ Immediately disposed controller: ${videoId.substring(0, 8)}');
    } catch (e) {
      debugPrint('⚠️ Error disposing controller: $e');
    }
  }
}
```

### Quick Win 2: Add Index Bounds Checking
**Problem**: Index mismatches cause null pointer exceptions  
**Solution**: Defensive programming with bounds checking

```dart
// In FeedScreen and VideoFeedItem
Widget _buildVideoAtIndex(int index) {
  final videos = provider.videoEvents;
  
  // DEFENSIVE: Always check bounds
  if (index < 0 || index >= videos.length) {
    debugPrint('⚠️ Invalid video index: $index/${videos.length}');
    return _buildErrorWidget('Video not available');
  }
  
  final video = videos[index];
  if (video == null) {
    debugPrint('⚠️ Null video at valid index: $index');
    return _buildErrorWidget('Video not loaded');
  }
  
  return VideoFeedItem(videoEvent: video, ...);
}
```

### Quick Win 3: Implement Circuit Breaker for Failed Videos
**Problem**: Videos that fail to load keep trying forever  
**Solution**: Mark videos as permanently failed after N attempts

```dart
// In VideoCacheService
final Map<String, int> _failureCount = {};
final Set<String> _permanentlyFailed = {};
static const int _maxRetries = 3;

Future<void> _preloadAndValidateSingleVideo(VideoEvent videoEvent) async {
  // Check if permanently failed
  if (_permanentlyFailed.contains(videoEvent.id)) {
    debugPrint('⛔ Skipping permanently failed video: ${videoEvent.id.substring(0, 8)}');
    return;
  }
  
  try {
    // Existing preload logic...
    
  } catch (e) {
    final failCount = (_failureCount[videoEvent.id] ?? 0) + 1;
    _failureCount[videoEvent.id] = failCount;
    
    if (failCount >= _maxRetries) {
      _permanentlyFailed.add(videoEvent.id);
      debugPrint('💀 Marking video as permanently failed: ${videoEvent.id.substring(0, 8)} (${failCount} failures)');
    }
    
    // Clean up and continue...
  }
}
```

### Quick Win 4: Add Memory Pressure Monitoring
**Problem**: App crashes due to excessive memory usage  
**Solution**: Monitor and react to memory pressure

```dart
// In VideoCacheService
static const int _memoryWarningThreshold = 20; // 20 controllers = ~600MB

void _checkMemoryPressure() {
  if (_controllers.length >= _memoryWarningThreshold) {
    debugPrint('🚨 MEMORY WARNING: ${_controllers.length} controllers active (${_controllers.length * 30}MB estimated)');
    
    // Aggressive cleanup
    _cleanupDistantVideos([], 0, keepRange: 5); // Keep only 5 videos
  }
}
```

---

## 🏗️ FOUNDATION PHASE (Days 4-10) - New Architecture

### Day 4-5: Create New Video State Model

Create the unified video state that will replace the dual list system:

```dart
// lib/models/video_state.dart
enum VideoLoadingState {
  notLoaded,     // Just created, no controller yet
  loading,       // Controller being created/initialized  
  ready,         // Ready to play
  failed,        // Failed to load (temporary)
  permanentlyFailed, // Failed multiple times (don't retry)
  disposed,      // Cleaned up
}

class VideoState {
  final VideoEvent event;
  final VideoPlayerController? controller;
  final VideoLoadingState loadingState;
  final String? errorMessage;
  final DateTime lastUpdated;
  final int failureCount;
  
  const VideoState({
    required this.event,
    this.controller,
    required this.loadingState,
    this.errorMessage,
    required this.lastUpdated,
    this.failureCount = 0,
  });
  
  // Convenience getters
  bool get isReady => loadingState == VideoLoadingState.ready && 
                     controller?.value.isInitialized == true;
  bool get isLoading => loadingState == VideoLoadingState.loading;
  bool get hasFailed => loadingState == VideoLoadingState.failed || 
                       loadingState == VideoLoadingState.permanentlyFailed;
  bool get canRetry => loadingState == VideoLoadingState.failed && failureCount < 3;
  
  VideoState copyWith({
    VideoPlayerController? controller,
    VideoLoadingState? loadingState,
    String? errorMessage,
    int? failureCount,
  }) {
    return VideoState(
      event: event,
      controller: controller ?? this.controller,
      loadingState: loadingState ?? this.loadingState,
      errorMessage: errorMessage ?? this.errorMessage,
      lastUpdated: DateTime.now(),
      failureCount: failureCount ?? this.failureCount,
    );
  }
}
```

### Day 6-7: Create Unified Video Manager

This service will replace both VideoEventService and VideoCacheService:

```dart
// lib/services/video_manager_service.dart
class VideoManagerService extends ChangeNotifier {
  // Single source of truth - replaces dual lists
  final Map<String, VideoState> _videos = {};
  final List<String> _orderedVideoIds = []; // Display order (newest first)
  
  // Preloading control
  final Set<String> _currentlyPreloading = {};
  final int _maxVideos = 100;
  final int _preloadAhead = 3;
  
  // Memory management
  Timer? _memoryCheckTimer;
  
  VideoManagerService() {
    // Start periodic memory monitoring
    _memoryCheckTimer = Timer.periodic(Duration(minutes: 1), (_) => _checkMemoryUsage());
  }
  
  /// Single source of truth for video list (replaces dual lists)
  List<VideoEvent> get videos => _orderedVideoIds
      .map((id) => _videos[id])
      .where((state) => state != null && !state.hasFailed)
      .map((state) => state!.event)
      .toList();
  
  /// Get ready videos that can be played immediately
  List<VideoEvent> get readyVideos => _videos.values
      .where((state) => state.isReady)
      .map((state) => state.event)
      .toList();
  
  /// Get video state for debugging
  VideoState? getVideoState(String videoId) => _videos[videoId];
  
  /// Get controller for playback
  VideoPlayerController? getController(String videoId) {
    final state = _videos[videoId];
    return state?.isReady == true ? state!.controller : null;
  }
  
  /// Add new video event from Nostr (replaces both services' event handling)
  void addVideoEvent(VideoEvent event) {
    if (_videos.containsKey(event.id)) {
      debugPrint('⏩ Duplicate video event: ${event.id.substring(0, 8)}');
      return;
    }
    
    final videoState = VideoState(
      event: event,
      loadingState: VideoLoadingState.notLoaded,
      lastUpdated: DateTime.now(),
    );
    
    _videos[event.id] = videoState;
    _orderedVideoIds.insert(0, event.id); // Newest first
    
    debugPrint('➕ Added video: ${event.id.substring(0, 8)} (total: ${_videos.length})');
    
    // Handle GIFs immediately (they don't need preloading)
    if (event.isGif) {
      _markAsReady(event.id);
    }
    
    // Cleanup old videos
    _cleanupOldVideos();
    
    notifyListeners();
  }
  
  /// Preload video for smooth playback
  Future<void> preloadVideo(String videoId) async {
    final videoState = _videos[videoId];
    if (videoState == null) {
      debugPrint('⚠️ Cannot preload unknown video: ${videoId.substring(0, 8)}');
      return;
    }
    
    // Skip if already loading/ready/failed
    if (videoState.isLoading || videoState.isReady || videoState.hasFailed) {
      return;
    }
    
    // Skip if currently preloading
    if (_currentlyPreloading.contains(videoId)) {
      return;
    }
    
    _currentlyPreloading.add(videoId);
    
    try {
      debugPrint('🚀 Preloading video: ${videoId.substring(0, 8)}');
      
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
      
      debugPrint('✅ Video ready: ${videoId.substring(0, 8)}');
      
    } catch (e) {
      debugPrint('❌ Preload failed: ${videoId.substring(0, 8)} - $e');
      
      // Update failure count and state
      final newFailureCount = videoState.failureCount + 1;
      final newLoadingState = newFailureCount >= 3 
          ? VideoLoadingState.permanentlyFailed 
          : VideoLoadingState.failed;
      
      _videos[videoId] = videoState.copyWith(
        loadingState: newLoadingState,
        errorMessage: e.toString(),
        failureCount: newFailureCount,
      );
    } finally {
      _currentlyPreloading.remove(videoId);
      notifyListeners();
    }
  }
  
  /// Preload videos around current position (smart preloading)
  void preloadAroundIndex(int currentIndex) {
    if (currentIndex < 0 || currentIndex >= _orderedVideoIds.length) {
      debugPrint('⚠️ Invalid preload index: $currentIndex/${_orderedVideoIds.length}');
      return;
    }
    
    // Preload current + next N videos
    for (int i = currentIndex; i <= currentIndex + _preloadAhead && i < _orderedVideoIds.length; i++) {
      final videoId = _orderedVideoIds[i];
      preloadVideo(videoId);
    }
    
    // Cleanup videos far from current position
    _cleanupDistantVideos(currentIndex);
  }
  
  /// Mark GIF as ready (no preloading needed)
  void _markAsReady(String videoId) {
    final videoState = _videos[videoId];
    if (videoState != null) {
      _videos[videoId] = videoState.copyWith(
        loadingState: VideoLoadingState.ready,
      );
    }
  }
  
  /// Cleanup old videos to manage memory
  void _cleanupOldVideos() {
    if (_videos.length <= _maxVideos) return;
    
    final videosToRemove = _orderedVideoIds.skip(_maxVideos).toList();
    
    debugPrint('🧹 Cleaning up ${videosToRemove.length} old videos');
    
    for (final videoId in videosToRemove) {
      final videoState = _videos.remove(videoId);
      videoState?.controller?.dispose();
      _orderedVideoIds.remove(videoId);
    }
  }
  
  /// Cleanup videos far from current position  
  void _cleanupDistantVideos(int currentIndex) {
    final keepRange = _preloadAhead + 5; // Keep some extra buffer
    final videosToKeep = <String>{};
    
    // Calculate range to keep
    final startKeep = (currentIndex - keepRange).clamp(0, _orderedVideoIds.length - 1);
    final endKeep = (currentIndex + keepRange).clamp(0, _orderedVideoIds.length - 1);
    
    for (int i = startKeep; i <= endKeep; i++) {
      videosToKeep.add(_orderedVideoIds[i]);
    }
    
    // Dispose controllers outside keep range
    final controllersToDispose = <String>[];
    for (final videoId in _videos.keys) {
      if (!videosToKeep.contains(videoId)) {
        final videoState = _videos[videoId];
        if (videoState?.controller != null) {
          controllersToDispose.add(videoId);
        }
      }
    }
    
    if (controllersToDispose.isNotEmpty) {
      debugPrint('🧹 Disposing ${controllersToDispose.length} distant video controllers');
      
      for (final videoId in controllersToDispose) {
        final videoState = _videos[videoId];
        videoState?.controller?.dispose();
        
        // Update state to disposed
        _videos[videoId] = videoState!.copyWith(
          controller: null,
          loadingState: VideoLoadingState.disposed,
        );
      }
    }
  }
  
  /// Check memory usage and react to pressure
  void _checkMemoryUsage() {
    final controllersCount = _videos.values.where((state) => state.controller != null).length;
    final estimatedMemoryMB = controllersCount * 30; // Rough estimate
    
    if (estimatedMemoryMB > 500) { // 500MB threshold
      debugPrint('🚨 HIGH MEMORY USAGE: ${controllersCount} controllers (~${estimatedMemoryMB}MB)');
      
      // Aggressive cleanup - keep only ready videos near current position
      // This would need current position context, so for now just cleanup old videos
      _cleanupOldVideos();
    }
  }
  
  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    final controllerCount = _videos.values.where((state) => state.controller != null).length;
    final readyCount = _videos.values.where((state) => state.isReady).length;
    final loadingCount = _videos.values.where((state) => state.isLoading).length;
    final failedCount = _videos.values.where((state) => state.hasFailed).length;
    
    return {
      'totalVideos': _videos.length,
      'readyVideos': readyCount,
      'loadingVideos': loadingCount,
      'failedVideos': failedCount,
      'controllers': controllerCount,
      'estimatedMemoryMB': controllerCount * 30,
      'currentlyPreloading': _currentlyPreloading.length,
    };
  }
  
  @override
  void dispose() {
    _memoryCheckTimer?.cancel();
    
    // Dispose all controllers
    for (final state in _videos.values) {
      state.controller?.dispose();
    }
    
    _videos.clear();
    _orderedVideoIds.clear();
    _currentlyPreloading.clear();
    
    super.dispose();
  }
}
```

### Day 8-10: Integration Testing

Test the new system in parallel with the old system to ensure compatibility:

```dart
// lib/services/video_manager_test_service.dart
class VideoManagerTestService {
  final VideoManagerService _newManager = VideoManagerService();
  final VideoCacheService _oldCache;
  final VideoEventService _oldEvents;
  
  VideoManagerTestService(this._oldCache, this._oldEvents);
  
  void testConsistency() {
    // Compare outputs from old vs new system
    final oldVideos = _oldCache.readyToPlayQueue;
    final newVideos = _newManager.videos;
    
    if (oldVideos.length != newVideos.length) {
      debugPrint('⚠️ VIDEO COUNT MISMATCH: old=${oldVideos.length}, new=${newVideos.length}');
    }
    
    // Compare video IDs
    for (int i = 0; i < math.min(oldVideos.length, newVideos.length); i++) {
      if (oldVideos[i].id != newVideos[i].id) {
        debugPrint('⚠️ VIDEO ORDER MISMATCH at index $i: old=${oldVideos[i].id.substring(0,8)}, new=${newVideos[i].id.substring(0,8)}');
      }
    }
  }
}
```

---

## 🔄 MIGRATION PHASE (Days 11-17) - Switch to New System

### Day 11-12: Update VideoFeedProvider

Simplify the provider to use the new unified service:

```dart
// lib/providers/video_feed_provider.dart (SIMPLIFIED VERSION)
class VideoFeedProvider extends ChangeNotifier {
  final VideoManagerService _videoManager;
  final VideoEventService _videoEventService; // Keep for Nostr events
  final UserProfileService _userProfileService;
  
  VideoFeedProvider({
    required VideoManagerService videoManager,
    required VideoEventService videoEventService,
    required UserProfileService userProfileService,
  }) : _videoManager = videoManager,
       _videoEventService = videoEventService,
       _userProfileService = userProfileService {
    
    // Listen to Nostr events and forward to unified manager
    _videoEventService.addListener(_onNewVideoEvents);
    _videoManager.addListener(_scheduleNotification);
  }
  
  // SIMPLIFIED: Single video list (no more dual lists!)
  List<VideoEvent> get videos => _videoManager.videos;
  VideoManagerService get videoManager => _videoManager;
  
  // Keep existing getters for compatibility
  bool get isInitialized => _videoEventService.isInitialized;
  bool get isRefreshing => _videoEventService.isLoading;
  bool get canLoadMore => _videoEventService.hasEvents && !isLoadingMore;
  
  void _onNewVideoEvents() {
    // Forward all new events to unified manager
    for (final event in _videoEventService.videoEvents) {
      _videoManager.addVideoEvent(event);
    }
    
    // Fetch profiles for authors
    _fetchProfilesForVideos(_videoEventService.videoEvents);
  }
  
  void preloadVideosAroundIndex(int index) {
    _videoManager.preloadAroundIndex(index);
  }
  
  Future<void> loadMoreEvents() async {
    await _videoEventService.loadMoreEvents();
  }
}
```

### Day 13-14: Update VideoFeedItem

Simplify widget to use unified video state:

```dart
// lib/widgets/video_feed_item.dart (SIMPLIFIED VERSION)  
class VideoFeedItem extends StatelessWidget {
  final VideoEvent videoEvent;
  final bool isActive;
  
  @override
  Widget build(BuildContext context) {
    return Consumer<VideoFeedProvider>(
      builder: (context, provider, child) {
        final videoState = provider.videoManager.getVideoState(videoEvent.id);
        
        // Request preload if video becomes active
        if (isActive && videoState?.loadingState == VideoLoadingState.notLoaded) {
          provider.videoManager.preloadVideo(videoEvent.id);
        }
        
        return _buildVideoWidget(videoState);
      },
    );
  }
  
  Widget _buildVideoWidget(VideoState? videoState) {
    if (videoState?.isReady == true) {
      return _VideoPlayer(
        controller: videoState!.controller!,
        videoEvent: videoEvent,
        isActive: isActive,
      );
    } else if (videoState?.isLoading == true) {
      return _LoadingWidget();
    } else if (videoState?.hasFailed == true) {
      return _ErrorWidget(
        message: videoState!.errorMessage ?? 'Failed to load video',
        canRetry: videoState.canRetry,
        onRetry: videoState.canRetry 
            ? () => context.read<VideoFeedProvider>().videoManager.preloadVideo(videoEvent.id)
            : null,
      );
    } else {
      return _LoadingWidget(); // Will trigger preload above
    }
  }
}
```

### Day 15-17: Remove Legacy Code

Once the new system is working:

1. **Remove VideoCacheService** - All functionality moved to VideoManagerService
2. **Remove VideoEventService** - Event handling moved to VideoManagerService  
3. **Remove notification batching timers** - Direct notifications with simplified system
4. **Update all imports** - Remove references to deleted services
5. **Clean up tests** - Update to test new architecture

---

## 🧪 TESTING STRATEGY

### Automated Tests

```dart
// test/video_manager_test.dart
testWidgets('VideoManager handles video lifecycle correctly', (tester) async {
  final manager = VideoManagerService();
  
  // Test adding video
  final event = VideoEvent(id: 'test', videoUrl: 'http://test.mp4');
  manager.addVideoEvent(event);
  
  expect(manager.videos.length, 1);
  expect(manager.getVideoState('test')?.loadingState, VideoLoadingState.notLoaded);
  
  // Test preloading
  await manager.preloadVideo('test');
  
  expect(manager.getVideoState('test')?.isReady, true);
  expect(manager.getController('test'), isNotNull);
  
  // Test cleanup
  manager.dispose();
  // Controller should be disposed
});

testWidgets('VideoManager prevents memory leaks', (tester) async {
  final manager = VideoManagerService();
  
  // Add 200 videos (more than max)
  for (int i = 0; i < 200; i++) {
    final event = VideoEvent(id: 'test$i', videoUrl: 'http://test$i.mp4');
    manager.addVideoEvent(event);
  }
  
  // Should have cleaned up to max
  expect(manager.videos.length, lessThanOrEqualTo(100));
});
```

### Manual Testing Scenarios

1. **Memory Stress Test**: Scroll through 100+ videos, monitor memory usage
2. **Network Failure Test**: Disconnect network during video loading
3. **Rapid Scrolling Test**: Scroll very fast through videos
4. **Background/Foreground Test**: Background app during video loading

---

## 📊 SUCCESS METRICS

### Before vs After Comparison

| Metric | Current | Target | 
|--------|---------|--------|
| Memory Usage | Up to 3GB | Under 500MB |
| Video Load Success Rate | ~80% | >95% |
| UI Rebuild Frequency | 60+ per event | <10 per event |
| Code Complexity | High (dual lists) | Low (single source) |
| Race Conditions | 5 major | 0 detected |
| Index Mismatch Bugs | Frequent | 0 detected |

### Monitoring Dashboard

```dart
// Debug screen to monitor video system health
class VideoSystemDebugScreen extends StatelessWidget {
  Widget build(context) {
    return Consumer<VideoFeedProvider>(
      builder: (context, provider, child) {
        final debugInfo = provider.videoManager.getDebugInfo();
        
        return Scaffold(
          appBar: AppBar(title: Text('Video System Debug')),
          body: ListView(
            children: [
              _DebugCard('Memory Usage', '${debugInfo['estimatedMemoryMB']}MB'),
              _DebugCard('Total Videos', '${debugInfo['totalVideos']}'),
              _DebugCard('Ready Videos', '${debugInfo['readyVideos']}'),
              _DebugCard('Loading Videos', '${debugInfo['loadingVideos']}'),
              _DebugCard('Failed Videos', '${debugInfo['failedVideos']}'),
              _DebugCard('Controllers', '${debugInfo['controllers']}'),
            ],
          ),
        );
      },
    );
  }
}
```

---

This roadmap provides a concrete, step-by-step approach to fixing the video system's fundamental issues while maintaining app stability throughout the transition.