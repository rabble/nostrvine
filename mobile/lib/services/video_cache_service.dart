// ABOUTME: Service for preloading and caching video content for smooth playback
// ABOUTME: Manages video player controllers and preloads upcoming videos in the feed

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';

/// Service for managing video cache and preloading
class VideoCacheService extends ChangeNotifier {
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _initializationStatus = {};
  final Set<String> _preloadQueue = {};
  final List<VideoEvent> _readyToPlayQueue = []; // Queue of videos ready for immediate playback
  final Set<String> _addedToQueue = {}; // Track which videos are already in ready queue
  
  static const int _maxCachedVideos = 10; // Maximum number of videos to keep in cache
  static const int _preloadCount = 3; // Number of videos to preload ahead
  static const int _maxReadyQueue = 20; // Maximum videos in ready-to-play queue
  
  /// Get a cached video controller for the given video event
  VideoPlayerController? getController(VideoEvent videoEvent) {
    if (videoEvent.videoUrl == null || videoEvent.isGif) return null;
    return _controllers[videoEvent.id];
  }
  
  /// Check if a video is initialized and ready to play
  bool isInitialized(VideoEvent videoEvent) {
    if (videoEvent.videoUrl == null || videoEvent.isGif) return true; // GIFs don't need initialization
    return _initializationStatus[videoEvent.id] == true;
  }
  
  /// Get the ready-to-play video queue (only videos that are downloaded and ready)
  List<VideoEvent> get readyToPlayQueue => List.unmodifiable(_readyToPlayQueue);
  
  /// Add video to ready queue when it's successfully loaded
  void _addToReadyQueue(VideoEvent videoEvent) {
    if (!_addedToQueue.contains(videoEvent.id) && _readyToPlayQueue.length < _maxReadyQueue) {
      _readyToPlayQueue.add(videoEvent);
      _addedToQueue.add(videoEvent.id);
      debugPrint('✅ Added to ready queue: ${videoEvent.id.substring(0, 8)}... (${videoEvent.isGif ? "GIF" : "VIDEO"}) - queue size: ${_readyToPlayQueue.length}');
      notifyListeners();
    } else {
      debugPrint('⚠️ Could not add to ready queue: ${videoEvent.id.substring(0, 8)}... - already added: ${_addedToQueue.contains(videoEvent.id)}, queue full: ${_readyToPlayQueue.length >= _maxReadyQueue}');
    }
  }
  
  /// Process new video events and test video compatibility before adding to ready queue
  void processNewVideoEvents(List<VideoEvent> videoEvents) {
    if (videoEvents.isEmpty) return;
    
    debugPrint('📋 Processing ${videoEvents.length} video events for compatibility testing...');
    
    // Process GIFs immediately (they always work)
    for (final videoEvent in videoEvents) {
      if (videoEvent.isGif && !_addedToQueue.contains(videoEvent.id)) {
        _addToReadyQueue(videoEvent);
        debugPrint('✅ Added GIF to ready queue: ${videoEvent.id.substring(0, 8)}...');
      }
    }
    
    // Test video compatibility for non-GIF videos in background
    _testVideoCompatibilityInBackground(videoEvents);
    
    debugPrint('📊 Ready queue status: ${_readyToPlayQueue.length} videos ready');
  }
  
  /// Test video compatibility in background without blocking UI
  void _testVideoCompatibilityInBackground(List<VideoEvent> videoEvents) {
    debugPrint('🧪 Starting video compatibility testing...');
    
    int tested = 0;
    for (final videoEvent in videoEvents) {
      if (!videoEvent.isGif && tested < 5) {
        debugPrint('🔍 Testing video compatibility: ${videoEvent.id.substring(0, 8)}...');
        _testVideoCompatibility(videoEvent);
        tested++;
      }
    }
    
    debugPrint('📊 Compatibility test summary: $tested videos being tested');
  }
  
  /// Preload videos around the current index for smooth swiping
  Future<void> preloadVideos(List<VideoEvent> videos, int currentIndex) async {
    if (videos.isEmpty) return;
    
    debugPrint('🎥 Preloading videos around index $currentIndex');
    
    // Calculate range of videos to preload
    final startIndex = (currentIndex - 1).clamp(0, videos.length - 1);
    final endIndex = (currentIndex + _preloadCount).clamp(0, videos.length - 1);
    
    // Preload videos in range
    for (int i = startIndex; i <= endIndex; i++) {
      final videoEvent = videos[i];
      if (videoEvent.videoUrl != null && !videoEvent.isGif) {
        await _preloadVideo(videoEvent);
      }
    }
    
    // Clean up old cached videos that are far from current position
    _cleanupDistantVideos(videos, currentIndex);
  }
  
  /// Test if a video can be loaded without adding it to the ready queue if it fails
  Future<void> _testVideoCompatibility(VideoEvent videoEvent) async {
    if (_controllers.containsKey(videoEvent.id) || _preloadQueue.contains(videoEvent.id)) {
      return; // Already tested or testing
    }
    
    if (_controllers.length >= _maxCachedVideos) {
      debugPrint('⚠️ Cache full, skipping compatibility test: ${videoEvent.id.substring(0, 8)}...');
      return; // Cache is full
    }
    
    try {
      _preloadQueue.add(videoEvent.id);
      
      debugPrint('🧪 Testing video compatibility: ${videoEvent.id.substring(0, 8)}...');
      debugPrint('📹 Video URL: ${videoEvent.videoUrl}');
      
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoEvent.videoUrl!),
      );
      
      _controllers[videoEvent.id] = controller;
      _initializationStatus[videoEvent.id] = false;
      
      // Test initialization with timeout - more aggressive timeout for compatibility test
      await Future.any([
        controller.initialize(),
        Future.delayed(const Duration(seconds: 5)).then((_) {
          throw TimeoutException('Video compatibility test timeout after 5 seconds', const Duration(seconds: 5));
        }),
      ]);
      
      // Test basic playback capability
      controller.setLooping(true);
      await controller.play();
      await Future.delayed(const Duration(milliseconds: 100)); // Brief test play
      await controller.pause();
      
      _initializationStatus[videoEvent.id] = true;
      debugPrint('✅ Video passed compatibility test: ${videoEvent.id.substring(0, 8)}...');
      
      // Only add to ready queue if video passes all compatibility tests
      _addToReadyQueue(videoEvent);
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Video failed compatibility test: ${videoEvent.id.substring(0, 8)} - $e');
      debugPrint('🚫 Excluding video from feed due to incompatibility');
      
      // Clean up failed controller
      final controller = _controllers.remove(videoEvent.id);
      controller?.dispose();
      _initializationStatus.remove(videoEvent.id);
      
      // DO NOT add to ready queue - exclude incompatible videos completely
    } finally {
      _preloadQueue.remove(videoEvent.id);
    }
  }
  
  /// Preload a specific video (for videos that have already passed compatibility test)
  Future<void> _preloadVideo(VideoEvent videoEvent) async {
    if (_controllers.containsKey(videoEvent.id)) {
      debugPrint('⏩ Video already cached: ${videoEvent.id.substring(0, 8)}...');
      return; // Already cached
    }
    
    if (_preloadQueue.contains(videoEvent.id)) {
      debugPrint('⏩ Video already in preload queue: ${videoEvent.id.substring(0, 8)}...');
      return; // Already in preload queue
    }
    
    if (_controllers.length >= _maxCachedVideos) {
      debugPrint('⚠️ Cache full, skipping preload: ${videoEvent.id.substring(0, 8)}... (${_controllers.length}/$_maxCachedVideos)');
      return; // Cache is full, skip preloading
    }
    
    try {
      _preloadQueue.add(videoEvent.id);
      
      debugPrint('🎥 Preloading video: ${videoEvent.id.substring(0, 8)}...');
      
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoEvent.videoUrl!),
      );
      
      _controllers[videoEvent.id] = controller;
      _initializationStatus[videoEvent.id] = false;
      
      // Initialize the controller with timeout
      await Future.any([
        controller.initialize(),
        Future.delayed(const Duration(seconds: 8)).then((_) {
          throw TimeoutException('Video initialization timeout after 8 seconds', const Duration(seconds: 8));
        }),
      ]);
      
      controller.setLooping(true);
      _initializationStatus[videoEvent.id] = true;
      debugPrint('✅ Video preloaded successfully: ${videoEvent.id.substring(0, 8)}...');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to preload video ${videoEvent.id.substring(0, 8)}: $e');
      _controllers.remove(videoEvent.id);
      _initializationStatus.remove(videoEvent.id);
    } finally {
      _preloadQueue.remove(videoEvent.id);
    }
  }
  
  /// Clean up videos that are far from the current position
  void _cleanupDistantVideos(List<VideoEvent> videos, int currentIndex) {
    final keepRange = _preloadCount + 2; // Keep a bit more than preload range
    final videosToKeep = <String>{};
    
    // Calculate which videos to keep
    final startKeep = (currentIndex - keepRange).clamp(0, videos.length - 1);
    final endKeep = (currentIndex + keepRange).clamp(0, videos.length - 1);
    
    for (int i = startKeep; i <= endKeep; i++) {
      videosToKeep.add(videos[i].id);
    }
    
    // Remove controllers for videos outside keep range
    final controllersToRemove = <String>[];
    for (final videoId in _controllers.keys) {
      if (!videosToKeep.contains(videoId)) {
        controllersToRemove.add(videoId);
      }
    }
    
    for (final videoId in controllersToRemove) {
      _controllers[videoId]?.dispose();
      _controllers.remove(videoId);
      _initializationStatus.remove(videoId);
      
      // Also remove from ready queue and tracking set
      _readyToPlayQueue.removeWhere((video) => video.id == videoId);
      _addedToQueue.remove(videoId);
      
      debugPrint('🗑️ Cleaned up cached video: ${videoId.substring(0, 8)}...');
    }
  }
  
  /// Get initialization status for a video
  bool isVideoReady(String videoId) {
    return _initializationStatus[videoId] == true;
  }
  
  /// Manually add a controller (for videos that are actively being viewed)
  void addController(VideoEvent videoEvent, VideoPlayerController controller) {
    if (videoEvent.videoUrl == null || videoEvent.isGif) return;
    
    _controllers[videoEvent.id] = controller;
    _initializationStatus[videoEvent.id] = controller.value.isInitialized;
    
    // Add to ready queue if initialized
    if (controller.value.isInitialized) {
      _addToReadyQueue(videoEvent);
    }
    
    // Listen for initialization changes
    controller.addListener(() {
      final wasInitialized = _initializationStatus[videoEvent.id] ?? false;
      final isNowInitialized = controller.value.isInitialized;
      
      if (isNowInitialized != wasInitialized) {
        _initializationStatus[videoEvent.id] = isNowInitialized;
        
        // Add to ready queue when it becomes initialized
        if (isNowInitialized && !wasInitialized) {
          _addToReadyQueue(videoEvent);
        }
        
        notifyListeners();
      }
    });
  }
  
  /// Remove a controller from cache
  void removeController(dynamic videoEventOrId) {
    final String videoId = videoEventOrId is VideoEvent ? videoEventOrId.id : videoEventOrId as String;
    
    final controller = _controllers.remove(videoId);
    controller?.dispose();
    _initializationStatus.remove(videoId);
    
    // Also remove from ready queue
    _readyToPlayQueue.removeWhere((video) => video.id == videoId);
    _addedToQueue.remove(videoId);
  }
  
  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_videos': _controllers.length,
      'initialized_videos': _initializationStatus.values.where((initialized) => initialized).length,
      'preload_queue_size': _preloadQueue.length,
      'ready_to_play_queue': _readyToPlayQueue.length,
      'max_cache_size': _maxCachedVideos,
      'max_ready_queue': _maxReadyQueue,
    };
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializationStatus.clear();
    _preloadQueue.clear();
    _readyToPlayQueue.clear();
    _addedToQueue.clear();
    super.dispose();
  }
}