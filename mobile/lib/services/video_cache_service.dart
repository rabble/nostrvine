// ABOUTME: Service for preloading and caching video content for smooth playback
// ABOUTME: Manages video player controllers and preloads upcoming videos in the feed

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/video_event.dart';
import '../utils/logger.dart';

/// Service for managing video cache and preloading
class VideoCacheService extends ChangeNotifier {
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _initializationStatus = {};
  final Set<String> _preloadQueue = {};
  final List<VideoEvent> _readyToPlayQueue = []; // Queue of videos ready for immediate playback
  final Set<String> _addedToQueue = {}; // Track which videos are already in ready queue
  
  // Track which video is currently playing to avoid multiple videos playing simultaneously
  String? _currentlyPlayingVideoId;
  
  // Notification batching to prevent infinite rebuild loops
  Timer? _notificationTimer;
  bool _hasPendingNotification = false;
  
  static const int _maxCachedVideos = 100; // Maximum number of videos to keep in cache
  static const int _preloadCount = 3; // Number of videos to preload ahead  
  static const int _maxReadyQueue = 100; // Maximum videos in ready-to-play queue
  
  // Network-aware preloading constants for TikTok-like experience
  static const int _preloadBehind = 1;
  static const int _preloadAheadWifi = 5;
  static const int _preloadAheadCellular = 2; 
  static const int _preloadAheadDataSaver = 1;
  
  // Progressive caching: start with a reasonable size for the 34 available videos
  static const List<int> _cachingPrimes = [15, 20, 25, 30, 35]; // Start with 15 to process more videos initially
  static const List<int> _webCachingPrimes = [1, 2, 3]; // EXTREMELY conservative for web - only current video
  static const int _maxCacheTarget = 50; // Keep a reasonable limit
  static const int _webMaxCacheTarget = 3; // VERY small for web - just current + next
  int _currentCacheTarget = 15; // Start with 15 videos to process more of the available events
  
  // Web-specific optimization constants
  static const int _webMaxConcurrentPreloads = 2; // Limit concurrent video loads on web
  static const int _webBatchSize = 1; // Process videos one at a time on web
  static const int _webBatchDelay = 500; // Longer delay between batches on web
  int _primeIndex = 0;
  Timer? _batchProcessingTimer; // Batch process videos that arrive quickly
  final Set<String> _pendingVideoIds = {}; // Videos waiting to be processed

  /// Constructor with web-specific optimizations
  VideoCacheService() {
    if (kIsWeb) {
      // Start with MINIMAL cache target on web for instant loading
      _currentCacheTarget = _webCachingPrimes[0]; // Start with just 1 video!
      debugPrint('🌐 Web platform detected - using MINIMAL caching for instant loading (initial target: $_currentCacheTarget)');
    }
  }
  
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
  
  /// Play a specific video and pause any other currently playing video
  void playVideo(VideoEvent videoEvent) {
    if (videoEvent.videoUrl == null || videoEvent.isGif) return;
    
    final controller = _controllers[videoEvent.id];
    if (controller == null || !controller.value.isInitialized) {
      debugPrint('⚠️ Cannot play video ${videoEvent.id.substring(0, 8)}... - controller not ready');
      return;
    }
    
    // Pause currently playing video if it's different
    if (_currentlyPlayingVideoId != null && _currentlyPlayingVideoId != videoEvent.id) {
      final currentController = _controllers[_currentlyPlayingVideoId!];
      if (currentController != null && currentController.value.isInitialized) {
        debugPrint('⏸️ Auto-pausing previous video ${_currentlyPlayingVideoId!.substring(0, 8)}...');
        currentController.pause();
      }
    }
    
    // Play the new video with additional race condition protection
    debugPrint('▶️ Playing video ${videoEvent.id.substring(0, 8)}... via cache service');
    
    try {
      // Final safety check right before play() to prevent race conditions
      if (!controller.value.isInitialized) {
        debugPrint('⚠️ CRITICAL: Controller became uninitialized just before play() - ${videoEvent.id.substring(0, 8)}');
        return;
      }
      
      controller.play();
      _currentlyPlayingVideoId = videoEvent.id;
      debugPrint('🎯 Marked video as currently playing: ${videoEvent.id.substring(0, 8)}');
    } catch (e) {
      debugPrint('❌ Error playing video ${videoEvent.id.substring(0, 8)}: $e');
      // Don't crash - just log the error and continue
    }
  }
  
  /// Mark a video as currently active (called by video widgets when they become active)
  void markVideoAsActive(String videoId) {
    _currentlyPlayingVideoId = videoId;
    debugPrint('🎯 Video marked as active by widget: ${videoId.substring(0, 8)}');
  }
  
  /// Pause a specific video
  void pauseVideo(VideoEvent videoEvent) {
    if (videoEvent.videoUrl == null || videoEvent.isGif) return;
    
    final controller = _controllers[videoEvent.id];
    if (controller == null || !controller.value.isInitialized) return;
    
    debugPrint('⏸️ Pausing video ${videoEvent.id.substring(0, 8)}... via cache service');
    controller.pause();
    
    // Clear currently playing if this was the playing video
    if (_currentlyPlayingVideoId == videoEvent.id) {
      _currentlyPlayingVideoId = null;
    }
  }
  
  /// Pause all videos
  void pauseAllVideos() {
    debugPrint('⏸️ Pausing all videos via cache service');
    for (final controller in _controllers.values) {
      if (controller.value.isInitialized) {
        controller.pause();
      }
    }
    _currentlyPlayingVideoId = null;
  }
  
  /// Get the ready-to-play video queue (only videos that are downloaded and ready)
  List<VideoEvent> get readyToPlayQueue => List.unmodifiable(_readyToPlayQueue);
  
  /// Remove a video from the ready queue if it fails to load
  void removeVideoFromReadyQueue(String videoId) {
    _readyToPlayQueue.removeWhere((event) => event.id == videoId);
    _addedToQueue.remove(videoId);
    debugPrint('🗑️ Removed failed video from ready queue: ${videoId.substring(0, 8)}...');
    _scheduleNotification();
  }
  
  /// Schedule a batched notification to prevent infinite rebuild loops
  void _scheduleNotification() {
    if (_hasPendingNotification) {
      return; // Already have a pending notification
    }
    
    _hasPendingNotification = true;
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(milliseconds: 100), () {
      _hasPendingNotification = false;
      notifyListeners();
    });
  }
  
  /// Add video to ready queue when it's successfully loaded
  void _addToReadyQueue(VideoEvent videoEvent) {
    if (!_addedToQueue.contains(videoEvent.id) && _readyToPlayQueue.length < _maxReadyQueue) {
      _readyToPlayQueue.add(videoEvent);
      _addedToQueue.add(videoEvent.id);
      
      appLog(
        LogCategory.LIFECYCLE, '✅', 'Added to ready queue',
        videoId: videoEvent.id,
        details: {
          'type': videoEvent.isGif ? 'GIF' : 'VIDEO',
          'queueSize': _readyToPlayQueue.length,
          'maxQueue': _maxReadyQueue,
        },
      );
      
      // Batch notifications to prevent infinite rebuild loops
      _scheduleNotification();
    } else {
      appLog(
        LogCategory.ERROR, '⚠️', 'Could not add to ready queue',
        videoId: videoEvent.id,
        details: {
          'alreadyAdded': _addedToQueue.contains(videoEvent.id),
          'queueFull': _readyToPlayQueue.length >= _maxReadyQueue,
          'currentSize': _readyToPlayQueue.length,
        },
      );
    }
  }
  
  /// Process new video events - add GIFs immediately, batch regular videos for efficient processing
  /// 
  /// ⚠️ CRITICAL RACE CONDITION POINT ⚠️
  /// This is where dual video lists can get out of sync:
  /// - VideoEventService._videoEvents gets updated immediately
  /// - VideoCacheService._readyToPlayQueue gets updated after preloading (500ms+ later)
  /// - UI uses ready queue but preloading uses all events → INDEX MISMATCH
  void processNewVideoEvents(List<VideoEvent> videoEvents) {
    if (videoEvents.isEmpty) return;
    
    // Add GIFs immediately to ready queue (no preloading needed - they just work)
    int gifsAdded = 0;
    for (final videoEvent in videoEvents) {
      if (videoEvent.isGif && !_addedToQueue.contains(videoEvent.id)) {
        _addToReadyQueue(videoEvent);
        gifsAdded++;
      } else if (!videoEvent.isGif) {
        // Add regular videos to pending batch
        _pendingVideoIds.add(videoEvent.id);
      }
    }
    
    if (gifsAdded > 0) {
      debugPrint('🎬 Added $gifsAdded GIFs to ready queue');
    }
    
    // Batch process regular videos to avoid processing each one individually
    // Use much longer delay on web to reduce aggressive preloading
    final batchDelay = kIsWeb ? Duration(milliseconds: 2000) : Duration(milliseconds: 500);
    _batchProcessingTimer?.cancel();
    _batchProcessingTimer = Timer(batchDelay, () {
      if (_pendingVideoIds.isNotEmpty) {
        final allPendingVideos = videoEvents
            .where((v) => _pendingVideoIds.contains(v.id))
            .toList();
        _pendingVideoIds.clear();
        
        // On web, only preload if user seems to be actively scrolling
        if (kIsWeb && allPendingVideos.length > 5) {
          debugPrint('🌐 Web: Deferring preload of ${allPendingVideos.length} videos to avoid browser overload');
          return; // Skip aggressive batch preloading on web
        }
        
        _preloadVideosInBatch(allPendingVideos);
      }
    });
  }
  
  /// Preload videos in a batch - much simpler approach without recursion prevention
  Future<void> _preloadVideosInBatch(List<VideoEvent> videoEvents) async {
    // On web, be extremely conservative about batch preloading
    final maxToPreload = kIsWeb ? 
        (_currentCacheTarget).clamp(1, 2) : // Web: max 2 videos at once
        _currentCacheTarget; // Mobile: use normal target
    
    // Get videos that need preloading (excludes GIFs, already cached, already queued)
    final videosToPreloadList = videoEvents
        .where((videoEvent) =>
            !videoEvent.isGif &&
            !_controllers.containsKey(videoEvent.id) &&
            !_addedToQueue.contains(videoEvent.id))
        .take(maxToPreload) // Preload up to conservative target
        .toList();

    if (videosToPreloadList.isEmpty) {
      return;
    }

    // Log batch start with performance details
    appLog(
      LogCategory.PERF, '🎥', 'Starting batch preload',
      details: {
        'videosToLoad': videosToPreloadList.length,
        'target': _currentCacheTarget,
        'readyCount': _readyToPlayQueue.length,
        'platform': kIsWeb ? 'web' : 'mobile',
      },
    );

    // Preload videos in small batches for better performance
    // Web platform gets smaller batches and longer delays for better performance
    final batchSize = kIsWeb ? _webBatchSize : 3;
    final batchDelay = kIsWeb ? _webBatchDelay : 200;
    
    for (int i = 0; i < videosToPreloadList.length; i += batchSize) {
      final batch = videosToPreloadList.skip(i).take(batchSize).toList();
      
      if (kIsWeb) {
        // Web: Process videos sequentially to avoid overwhelming browser
        for (final videoEvent in batch) {
          await _preloadAndValidateSingleVideo(videoEvent);
          // Small delay between individual videos on web
          if (batch.length > 1) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      } else {
        // Mobile: Process batch concurrently for speed
        final futures = batch.map((videoEvent) => _preloadAndValidateSingleVideo(videoEvent)).toList();
        await Future.wait(futures, eagerError: false);
      }
      
      // Delay between batches
      if (i + batchSize < videosToPreloadList.length) {
        await Future.delayed(Duration(milliseconds: batchDelay));
      }
    }

    logPerformance('Batch preload completed', 0, details: {
      'videosReady': _readyToPlayQueue.length,
      'platform': kIsWeb ? 'web' : 'mobile',
    });
  }
  
  /// Preload and validate a single video URL - creates VideoPlayerController and buffers content
  /// This ensures smooth TikTok-style playback and validates that the video URL actually works
  Future<void> _preloadAndValidateSingleVideo(VideoEvent videoEvent) async {
    if (videoEvent.videoUrl == null ||
        _controllers.containsKey(videoEvent.id)) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    
    try {
      // Add to preload queue to prevent duplicate tests
      _preloadQueue.add(videoEvent.id);

      appLog(LogCategory.LIFECYCLE, '🚀', 'Starting preload', videoId: videoEvent.id);

      // Create and initialize controller immediately for TikTok-style preloading
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoEvent.videoUrl!),
      );

      _controllers[videoEvent.id] = controller;

      // Preload the video by initializing it
      await controller.initialize();
      controller.setLooping(true);

      // Mark as preloaded and ready
      _initializationStatus[videoEvent.id] = true;
      stopwatch.stop();

      logVideoLifecycle(
        'Preloaded & Validated',
        videoEvent.id,
        durationMs: stopwatch.elapsedMilliseconds,
        extraDetails: {
          'platform': kIsWeb ? 'web' : 'mobile',
          'url': videoEvent.videoUrl!.substring(0, 50) + '...',
        },
      );
      
      _addToReadyQueue(videoEvent);
      _scheduleNotification();
    } catch (e) {
      stopwatch.stop();
      
      logVideoLifecycle(
        'Preload Failed',
        videoEvent.id,
        durationMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );

      // Clean up failed controller
      final controller = _controllers.remove(videoEvent.id);
      try {
        await controller?.dispose();
      } catch (disposeError) {
        appLog(LogCategory.ERROR, '⚠️', 'Error disposing failed controller', 
               videoId: videoEvent.id, details: {'error': disposeError.toString()});
      }
      _initializationStatus.remove(videoEvent.id);
    } finally {
      _preloadQueue.remove(videoEvent.id);
    }
  }
  
  /// Consider scaling up the cache target if we've met the current one
  void _considerScalingUp() {
    // Check if we can and should scale up
    if (_readyToPlayQueue.length >= _currentCacheTarget &&
        _primeIndex < _cachingPrimes.length - 1 &&
        _currentCacheTarget < _maxCacheTarget) {
      _primeIndex++;
      final oldTarget = _currentCacheTarget;
      _currentCacheTarget = _cachingPrimes[_primeIndex];

      debugPrint(
          '🚀 Scaling up cache target from $oldTarget to $_currentCacheTarget videos (prime #${_primeIndex + 1})');
    } else if (_currentCacheTarget >= _maxCacheTarget) {
      debugPrint(
          '🏆 Maximum cache target reached: $_currentCacheTarget videos (limit: $_maxCacheTarget)');
    } else if (_readyToPlayQueue.length >= _maxCachedVideos) {
      debugPrint(
          '🏆 Maximum cache capacity reached: ${_readyToPlayQueue.length} videos ready');
    } else {
      debugPrint(
          '📊 Scaling conditions not met: ready=${_readyToPlayQueue.length}, target=$_currentCacheTarget, primeIndex=$_primeIndex/${_cachingPrimes.length - 1}');
    }
  }
  
  /// Aggressively preload videos around the current index for TikTok-like seamless experience
  Future<void> preloadVideos(List<VideoEvent> videos, int currentIndex) async {
    if (videos.isEmpty) return;
    
    debugPrint('🚀 Aggressively preloading videos around index $currentIndex for seamless experience');
    await _preloadVideosAggressively(videos, currentIndex);
  }
  
  /// Network-aware aggressive preloading implementation 
  Future<void> _preloadVideosAggressively(List<VideoEvent> videos, int currentIndex) async {
    if (videos.isEmpty) return;
    
    // Get network status for intelligent preloading
    final connectivityResult = await Connectivity().checkConnectivity();
    final isWifi = connectivityResult.contains(ConnectivityResult.wifi);
    final isCellular = connectivityResult.contains(ConnectivityResult.mobile);
    
    // Determine preloading window based on connection type and platform
    int preloadAhead;
    if (kIsWeb) {
      // Web gets very conservative preloading regardless of connection
      preloadAhead = 1;
      debugPrint('🌐 Web platform - using minimal preloading (ahead: $preloadAhead)');
    } else if (isWifi) {
      preloadAhead = _preloadAheadWifi;
      debugPrint('📶 WiFi detected - using aggressive preloading (ahead: $preloadAhead)');
    } else if (isCellular) {
      preloadAhead = _preloadAheadCellular;
      debugPrint('📱 Cellular detected - using moderate preloading (ahead: $preloadAhead)');
    } else {
      preloadAhead = _preloadAheadDataSaver;
      debugPrint('🔌 Unknown/limited connection - using conservative preloading (ahead: $preloadAhead)');
    }
    
    // Calculate dynamic preloading window [currentIndex - D, currentIndex + F]
    final startIndex = (currentIndex - _preloadBehind).clamp(0, videos.length - 1);
    final endIndex = (currentIndex + preloadAhead).clamp(0, videos.length - 1);
    
    debugPrint('🎯 Preloading window: [$startIndex, $endIndex] (current: $currentIndex)');
    
    // Priority queue: current+1, current+2, current-1, current+3, etc.
    final List<int> priorityIndices = [];
    
    // Add forward indices (higher priority)
    for (int offset = 1; offset <= preloadAhead; offset++) {
      final index = currentIndex + offset;
      if (index < videos.length) {
        priorityIndices.add(index);
      }
    }
    
    // Add backward indices (lower priority)
    for (int offset = 1; offset <= _preloadBehind; offset++) {
      final index = currentIndex - offset;
      if (index >= 0) {
        priorityIndices.add(index);
      }
    }
    
    debugPrint('📋 Priority preloading order: $priorityIndices');
    
    // Preload videos in priority order
    for (final index in priorityIndices) {
      final videoEvent = videos[index];
      if (videoEvent.videoUrl != null && !videoEvent.isGif) {
        // Check if already cached/loading to avoid duplicates
        if (!_controllers.containsKey(videoEvent.id) && !_preloadQueue.contains(videoEvent.id)) {
          debugPrint('🎥 Priority preloading video at index $index: ${videoEvent.id.substring(0, 8)}...');
          // Don't await - start all preloads in parallel for speed
          _preloadVideo(videoEvent);
        } else {
          debugPrint('⏩ Video at index $index already cached/loading: ${videoEvent.id.substring(0, 8)}...');
        }
      }
    }
    
    // Clean up videos outside the extended window to manage memory
    // Use larger keep range on web to be more conservative
    final keepRange = kIsWeb ? (preloadAhead + 5) : (preloadAhead + 2);
    _cleanupDistantVideos(videos, currentIndex, keepRange: keepRange);
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
      
      // Use Completer and Timer to prevent event loop blocking on macOS
      final completer = Completer<void>();
      bool hasCompleted = false;
      
      // Start initialization in microtask to avoid blocking
      scheduleMicrotask(() async {
        try {
          await controller.initialize();
          if (!hasCompleted) {
            hasCompleted = true;
            completer.complete();
          }
        } catch (e) {
          if (!hasCompleted) {
            hasCompleted = true;
            completer.completeError(e);
          }
        }
      });
      
      // Set up timeout using Timer (longer on web due to browser limitations)
      final timeoutDuration = kIsWeb ? const Duration(seconds: 15) : const Duration(seconds: 8);
      Timer(timeoutDuration, () {
        if (!hasCompleted) {
          hasCompleted = true;
          completer.completeError(TimeoutException('Video initialization timeout after ${timeoutDuration.inSeconds} seconds', timeoutDuration));
        }
      });
      
      // Wait for either completion or timeout
      await completer.future;
      
      // Brief delay to ensure controller is ready
      await Future.delayed(const Duration(milliseconds: 50));
      
      // Verify controller is actually ready before marking as initialized
      if (!controller.value.isInitialized) {
        throw Exception('Controller not ready after initialization in preload for ${videoEvent.id.substring(0, 8)}');
      }
      
      controller.setLooping(true);
      _initializationStatus[videoEvent.id] = true;
      debugPrint('✅ Video preloaded successfully: ${videoEvent.id.substring(0, 8)}...');
      
      _scheduleNotification();
    } catch (e) {
      debugPrint('❌ Failed to preload video ${videoEvent.id.substring(0, 8)}: $e');
      _controllers.remove(videoEvent.id);
      _initializationStatus.remove(videoEvent.id);
    } finally {
      _preloadQueue.remove(videoEvent.id);
    }
  }
  
  /// Clean up oldest cached videos to make room for new ones
  void _cleanupOldestCachedVideos(int count) {
    if (_controllers.length <= count) return;
    
    // Get list of controller keys and remove the oldest ones
    final controllerKeys = _controllers.keys.toList();
    final keysToRemove = controllerKeys.take(count).toList();
    
    for (final videoId in keysToRemove) {
      final controller = _controllers.remove(videoId);
      
      // Instead of disposing immediately, mark controller as invalid
      // The UI should check for errors before using controllers
      if (controller != null) {
        try {
          // Try to pause and cleanup gracefully first
          if (controller.value.isInitialized && controller.value.isPlaying) {
            controller.pause();
          }
        } catch (e) {
          debugPrint('⚠️ Error pausing controller during cleanup: $e');
        }
        
        // Dispose after a delay to allow UI to react
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            controller.dispose();
          } catch (e) {
            debugPrint('⚠️ Error disposing controller during cleanup: $e');
          }
        });
      }
      
      _initializationStatus.remove(videoId);
      
      // Also remove from ready queue and tracking set
      _readyToPlayQueue.removeWhere((video) => video.id == videoId);
      _addedToQueue.remove(videoId);
      
      debugPrint('🧹 Cleaned up oldest cached video: ${videoId.substring(0, 8)}...');
    }
    
    debugPrint('🧹 Cache cleanup completed: ${_controllers.length}/$_maxCachedVideos controllers remaining');
  }
  
  /// Clean up video controllers for videos far from current viewing position
  /// 
  /// Removes video controllers for videos outside the keep range to free memory.
  /// This prevents excessive memory usage by disposing controllers for videos
  /// that are unlikely to be viewed soon.
  /// 
  /// [videos] - List of all videos in the feed
  /// [currentIndex] - Current video being viewed (0-based index)
  /// [keepRange] - Optional override for how many videos to keep around current position
  ///               (defaults to preloadCount + 2 for extra buffer)
  void _cleanupDistantVideos(List<VideoEvent> videos, int currentIndex, {int? keepRange}) {
    final actualKeepRange = keepRange ?? (_preloadCount + 2); // Keep a bit more than preload range
    final videosToKeep = <String>{};
    
    // Calculate which videos to keep
    final startKeep = (currentIndex - actualKeepRange).clamp(0, videos.length - 1);
    final endKeep = (currentIndex + actualKeepRange).clamp(0, videos.length - 1);
    
    for (int i = startKeep; i <= endKeep; i++) {
      videosToKeep.add(videos[i].id);
    }
    
    // CRITICAL: Always keep the currently playing video to prevent crashes
    if (_currentlyPlayingVideoId != null) {
      videosToKeep.add(_currentlyPlayingVideoId!);
      debugPrint('🔒 Protecting currently playing video from cleanup: ${_currentlyPlayingVideoId!.substring(0, 8)}');
    }
    
    // Remove controllers for videos outside keep range
    final controllersToRemove = <String>[];
    for (final videoId in _controllers.keys) {
      if (!videosToKeep.contains(videoId)) {
        controllersToRemove.add(videoId);
      }
    }
    
    if (controllersToRemove.isNotEmpty) {
      debugPrint('🧹 Cleaning up ${controllersToRemove.length} distant videos (keep range: $actualKeepRange)');
    }
    
    for (final videoId in controllersToRemove) {
      final controller = _controllers.remove(videoId);
      _initializationStatus.remove(videoId);
      
      // Also remove from ready queue and tracking set
      _readyToPlayQueue.removeWhere((video) => video.id == videoId);
      _addedToQueue.remove(videoId);
      
      debugPrint('🗑️ Cleaned up distant video: ${videoId.substring(0, 8)}...');
      
      // Critical: Dispose controllers with delay to prevent race conditions with UI
      if (controller != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            controller.dispose();
          } catch (e) {
            debugPrint('⚠️ Error disposing controller during cleanup: $e');
          }
        });
      }
    }
  }
  
  /// Get initialization status for a video
  bool isVideoReady(String videoId) {
    return _initializationStatus[videoId] == true;
  }
  
  /// Manually add a controller (for videos that are actively being viewed)
  void addController(VideoEvent videoEvent, VideoPlayerController controller) {
    if (videoEvent.videoUrl == null || videoEvent.isGif) return;
    
    // Check if we already have this controller to avoid duplicate listeners
    if (_controllers.containsKey(videoEvent.id)) {
      debugPrint('⚠️ Controller already exists for ${videoEvent.id.substring(0, 8)}, skipping duplicate add');
      return;
    }
    
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
        
        _scheduleNotification();
      }
    });
  }
  
  /// Initialize a video controller lazily when it's needed (non-blocking)
  Future<void> initializeControllerLazily(VideoEvent videoEvent) async {
    final controller = _controllers[videoEvent.id];
    if (controller == null) {
      debugPrint('⚠️ No controller found for lazy initialization: ${videoEvent.id.substring(0, 8)}');
      return;
    }
    
    if (_initializationStatus[videoEvent.id] == true) {
      debugPrint('⏩ Controller already initialized: ${videoEvent.id.substring(0, 8)}');
      return;
    }
    
    try {
      debugPrint('🔄 Lazy initializing controller: ${videoEvent.id.substring(0, 8)}...');
      
      // Use the same non-blocking approach
      final completer = Completer<void>();
      bool hasCompleted = false;
      
      // Start initialization in microtask to avoid blocking
      scheduleMicrotask(() async {
        try {
          await controller.initialize();
          if (!hasCompleted) {
            hasCompleted = true;
            completer.complete();
          }
        } catch (e) {
          if (!hasCompleted) {
            hasCompleted = true;
            completer.completeError(e);
          }
        }
      });
      
      // Set up timeout using Timer
      Timer(const Duration(seconds: 10), () {
        if (!hasCompleted) {
          hasCompleted = true;
          completer.completeError(TimeoutException('Lazy video initialization timeout after 10 seconds', const Duration(seconds: 10)));
        }
      });
      
      // Wait for either completion or timeout
      await completer.future;
      
      controller.setLooping(true);
      _initializationStatus[videoEvent.id] = true;
      debugPrint('✅ Lazy initialization completed: ${videoEvent.id.substring(0, 8)}');
      
      _scheduleNotification();
    } catch (e) {
      debugPrint('❌ Lazy initialization failed: ${videoEvent.id.substring(0, 8)} - $e');
      _initializationStatus[videoEvent.id] = false;
    }
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
      'current_cache_target': _currentCacheTarget,
      'prime_index': _primeIndex,
      'max_cache_size': _maxCachedVideos,
      'max_ready_queue': _maxReadyQueue,
    };
  }
  
  @override
  void dispose() {
    // Cancel timers
    _notificationTimer?.cancel();
    _batchProcessingTimer?.cancel();
    
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _initializationStatus.clear();
    _preloadQueue.clear();
    _readyToPlayQueue.clear();
    _addedToQueue.clear();
    _pendingVideoIds.clear();
    super.dispose();
  }
}