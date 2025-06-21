// ABOUTME: Provider that integrates VideoStreamService with the app's state management
// ABOUTME: Bridges the caching API with existing video feed functionality

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_event.dart';
import '../services/video_stream_service.dart';
import '../services/video_manager_interface.dart';
import '../services/nip98_auth_service.dart';

/// Provider that integrates VideoStreamService for enhanced video delivery
class VideoStreamProvider extends ChangeNotifier {
  final VideoStreamService _streamService;
  final IVideoManager _videoManager;
  
  // State
  List<VideoItem> _cachedVideos = [];
  bool _isLoading = false;
  String? _error;
  String? _nextCursor;
  
  // Stream subscriptions
  StreamSubscription<VideoLoadProgress>? _progressSubscription;
  
  VideoStreamProvider({
    required IVideoManager videoManager,
    required SharedPreferences prefs,
    Nip98AuthService? authService,
  }) : _videoManager = videoManager,
       _streamService = VideoStreamService(
         prefs: prefs,
         authService: authService,
       ) {
    _initializeSubscriptions();
  }
  
  // Getters
  List<VideoItem> get cachedVideos => List.unmodifiable(_cachedVideos);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _nextCursor != null;
  VideoStreamService get streamService => _streamService;
  
  void _initializeSubscriptions() {
    // Listen to video load progress
    _progressSubscription = _streamService.loadProgress.listen((progress) {
      if (progress.isComplete) {
        debugPrint('✅ Video ${progress.videoId} loaded successfully');
        notifyListeners();
      } else if (progress.error != null) {
        debugPrint('❌ Error loading video ${progress.videoId}: ${progress.error}');
      }
    });
  }
  
  /// Load initial video feed from caching API
  Future<void> loadInitialFeed() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final videos = await _streamService.getVideoFeed(limit: 20);
      _cachedVideos = videos;
      
      // Add videos to VideoManager as VideoEvents
      for (final video in videos) {
        final videoEvent = _convertToVideoEvent(video);
        await _videoManager.addVideoEvent(videoEvent);
      }
      
      // Start prefetching
      if (videos.isNotEmpty) {
        final videoIds = videos.map((v) => v.id).toList();
        _streamService.prefetchNextVideos(videoIds);
      }
      
      debugPrint('📱 Loaded ${videos.length} videos from stream service');
    } catch (e) {
      _error = 'Failed to load videos: $e';
      debugPrint('❌ Error loading feed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load more videos (pagination)
  Future<void> loadMoreVideos() async {
    if (_isLoading || _nextCursor == null) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final videos = await _streamService.getVideoFeed(
        cursor: _nextCursor,
        limit: 10,
      );
      
      _cachedVideos.addAll(videos);
      
      // Add to VideoManager
      for (final video in videos) {
        final videoEvent = _convertToVideoEvent(video);
        await _videoManager.addVideoEvent(videoEvent);
      }
      
      // Prefetch new videos
      if (videos.isNotEmpty) {
        final videoIds = videos.map((v) => v.id).toList();
        _streamService.prefetchNextVideos(videoIds);
      }
      
      debugPrint('📱 Loaded ${videos.length} more videos');
    } catch (e) {
      _error = 'Failed to load more videos: $e';
      debugPrint('❌ Error loading more: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Preload videos around current index
  void preloadAroundIndex(int currentIndex, {int preloadRange = 3}) {
    if (currentIndex < 0 || currentIndex >= _cachedVideos.length) return;
    
    // Get video IDs to prefetch
    final videoIds = <String>[];
    
    // Add videos before current
    for (int i = currentIndex - 1; i >= 0 && i >= currentIndex - preloadRange; i--) {
      videoIds.add(_cachedVideos[i].id);
    }
    
    // Add videos after current
    for (int i = currentIndex + 1; i < _cachedVideos.length && i <= currentIndex + preloadRange; i++) {
      videoIds.add(_cachedVideos[i].id);
    }
    
    // Prefetch videos
    _streamService.prefetchNextVideos(videoIds);
    
    // Also tell VideoManager to preload
    _videoManager.preloadAroundIndex(currentIndex, preloadRange: preloadRange);
  }
  
  /// Get optimal video URL for playback
  Future<String?> getVideoUrl(String videoId) async {
    // For now, assume medium speed - the service will detect internally
    final networkSpeed = NetworkSpeed.medium;
    return await _streamService.getOptimalVideoUrl(videoId, networkSpeed);
  }
  
  /// Cache video data locally
  Future<void> cacheVideo(String videoId, Uint8List data) async {
    await _streamService.cacheVideoLocally(videoId, data);
  }
  
  /// Convert VideoItem to VideoEvent for compatibility
  VideoEvent _convertToVideoEvent(VideoItem item) {
    return VideoEvent(
      id: item.id,
      pubkey: item.authorPubkey,
      createdAt: item.createdAt.millisecondsSinceEpoch ~/ 1000,
      content: '',
      timestamp: item.createdAt,
      title: item.title,
      videoUrl: item.urls['720p'] ?? item.urls['480p'] ?? item.urls.values.first,
      duration: item.duration,
      thumbnailUrl: item.thumbnailUrl,
      hashtags: [],
    );
  }
  
  /// Refresh the feed
  Future<void> refresh() async {
    _cachedVideos.clear();
    _nextCursor = null;
    await loadInitialFeed();
  }
  
  @override
  void dispose() {
    _progressSubscription?.cancel();
    _streamService.dispose();
    super.dispose();
  }
}