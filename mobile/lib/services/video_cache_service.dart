// ABOUTME: Service for preloading and caching video content for smooth playback
// ABOUTME: Manages video player controllers and preloads upcoming videos in the feed

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
      debugPrint('✅ Added to ready queue: ${videoEvent.id.substring(0, 8)}... (queue size: ${_readyToPlayQueue.length})');
      notifyListeners();
    }
  }
  
  /// Process new video events and add ready ones to the queue
  void processNewVideoEvents(List<VideoEvent> videoEvents) {
    for (final videoEvent in videoEvents) {
      // Add GIFs immediately as they don't need initialization
      if (videoEvent.isGif && !_addedToQueue.contains(videoEvent.id)) {
        _addToReadyQueue(videoEvent);
      }
      // Videos will be added to queue when they finish loading in _preloadVideo
    }
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
  
  /// Preload a specific video
  Future<void> _preloadVideo(VideoEvent videoEvent) async {
    if (_controllers.containsKey(videoEvent.id)) {
      return; // Already cached
    }
    
    if (_preloadQueue.contains(videoEvent.id)) {
      return; // Already in preload queue
    }
    
    if (_controllers.length >= _maxCachedVideos) {
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
      
      // Initialize the controller
      await controller.initialize();
      controller.setLooping(true);
      
      _initializationStatus[videoEvent.id] = true;
      debugPrint('✅ Video preloaded: ${videoEvent.id.substring(0, 8)}...');
      
      // Add to ready queue now that it's loaded
      _addToReadyQueue(videoEvent);
      
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
  void removeController(String videoId) {
    final controller = _controllers.remove(videoId);
    controller?.dispose();
    _initializationStatus.remove(videoId);
  }
  
  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_videos': _controllers.length,
      'initialized_videos': _initializationStatus.values.where((initialized) => initialized).length,
      'preload_queue_size': _preloadQueue.length,
      'max_cache_size': _maxCachedVideos,
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
    super.dispose();
  }
}