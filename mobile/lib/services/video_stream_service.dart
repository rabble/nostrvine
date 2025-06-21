// ABOUTME: Mobile-optimized video streaming service for short-form video consumption
// ABOUTME: Handles smart caching, prefetching, quality adaptation, and device storage

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/video_event.dart';
import 'nip98_auth_service.dart';

/// Network speed categories for quality selection
enum NetworkSpeed { slow, medium, fast }

/// Progress tracking for video loading
class VideoLoadProgress {
  final String videoId;
  final double progress;
  final bool isComplete;
  final String? error;

  const VideoLoadProgress({
    required this.videoId,
    required this.progress,
    required this.isComplete,
    this.error,
  });
}

/// Video item with metadata and URLs
class VideoItem {
  final String id;
  final String title;
  final String? description;
  final String authorPubkey;
  final Map<String, String> urls; // quality -> url mapping
  final int? duration;
  final String? thumbnailUrl;
  final DateTime createdAt;

  VideoItem({
    required this.id,
    required this.title,
    this.description,
    required this.authorPubkey,
    required this.urls,
    this.duration,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      authorPubkey: json['author_pubkey'] as String,
      urls: Map<String, String>.from(json['urls'] as Map),
      duration: json['duration'] as int?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert from VideoEvent for compatibility
  factory VideoItem.fromVideoEvent(VideoEvent event) {
    return VideoItem(
      id: event.id,
      title: event.title ?? '',
      description: event.content,
      authorPubkey: event.pubkey,
      urls: {
        '720p': event.videoUrl ?? '',
        '480p': event.videoUrl ?? '', // Backend should provide multiple qualities
      },
      duration: event.duration,
      thumbnailUrl: event.thumbnailUrl,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );
  }
}

/// Service for mobile-optimized video streaming
class VideoStreamService extends ChangeNotifier {
  static String get _baseUrl => AppConfig.backendBaseUrl;
  static const Duration _defaultTimeout = Duration(seconds: 30);
  
  final http.Client _client;
  final SharedPreferences _prefs;
  final Nip98AuthService? _authService;
  final Connectivity _connectivity = Connectivity();
  
  // Controller management
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Uint8List> _memoryCache = {};
  final Set<String> _prefetchingVideos = {};
  
  // Progress tracking
  final StreamController<VideoLoadProgress> _progressController = StreamController<VideoLoadProgress>.broadcast();
  
  // Cache settings
  static const int _maxMemoryCacheItems = 10;
  static const int _maxDiskCacheItems = 50;
  static const String _cacheKeyPrefix = 'video_cache_';
  
  // Prefetch settings
  int _prefetchCount = 3;
  
  VideoStreamService({
    required SharedPreferences prefs,
    http.Client? client,
    Nip98AuthService? authService,
  }) : _prefs = prefs,
       _client = client ?? http.Client(),
       _authService = authService {
    _initializeService();
  }
  
  /// Initialize the service
  void _initializeService() {
    // Monitor network changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      debugPrint('📡 Network changed: $results');
      notifyListeners();
    });
    
    // Clean up old cache on startup
    _cleanupOldCache();
  }
  
  /// Get the current network speed
  Future<NetworkSpeed> _detectNetworkSpeed() async {
    final results = await _connectivity.checkConnectivity();
    
    // Handle multiple connectivity results
    if (results.contains(ConnectivityResult.ethernet) || 
        results.contains(ConnectivityResult.wifi)) {
      return NetworkSpeed.fast;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return NetworkSpeed.medium;
    }
    return NetworkSpeed.slow;
  }
  
  
  /// Get headers for API requests
  Future<Map<String, String>> _getHeaders({String? url, String method = 'GET'}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (_authService != null && url != null) {
      final authToken = await _authService!.createAuthToken(
        url: url,
        method: method == 'GET' ? HttpMethod.get : HttpMethod.post,
      );
      if (authToken != null) {
        headers['Authorization'] = 'Nostr ${authToken.token}';
      }
    }
    
    return headers;
  }
  
  /// Fetch video feed from backend
  Future<List<VideoItem>> getVideoFeed({String? cursor, int limit = 10}) async {
    debugPrint('🎬 Fetching video feed (cursor: $cursor, limit: $limit)');
    
    try {
      final networkSpeed = await _detectNetworkSpeed();
      await _prefs.setString('last_network_speed', networkSpeed.name);
      
      final uri = Uri.parse('$_baseUrl/api/videos/batch').replace(
        queryParameters: {
          if (cursor != null) 'cursor': cursor,
          'limit': limit.toString(),
          'network_hint': networkSpeed.name,
        },
      );
      
      final response = await _client.post(
        uri,
        headers: await _getHeaders(url: uri.toString(), method: 'POST'),
        body: jsonEncode({
          // In a real implementation, this would include video IDs from Nostr
          'video_ids': [], // Empty for feed discovery
        }),
      ).timeout(_defaultTimeout);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load video feed: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final videos = (data['videos'] as List)
          .map((json) => VideoItem.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Update prefetch count based on server recommendation
      _prefetchCount = data['prefetch_count'] as int? ?? 3;
      
      // Start prefetching
      if (videos.isNotEmpty) {
        _startPrefetching(videos);
      }
      
      debugPrint('✅ Loaded ${videos.length} videos from feed');
      return videos;
      
    } catch (e) {
      debugPrint('❌ Error loading video feed: $e');
      return [];
    }
  }
  
  /// Get optimal video URL based on network conditions
  Future<String?> getOptimalVideoUrl(String videoId, NetworkSpeed networkSpeed) async {
    debugPrint('🎯 Getting optimal URL for $videoId (network: $networkSpeed)');
    
    try {
      // Check memory cache first
      if (_memoryCache.containsKey(videoId)) {
        debugPrint('💾 Found in memory cache');
        return 'memory://$videoId';
      }
      
      // Check disk cache
      final cachedPath = await _getCachedVideoPath(videoId);
      if (cachedPath != null && await File(cachedPath).exists()) {
        debugPrint('💿 Found in disk cache');
        return cachedPath;
      }
      
      // Fetch from API
      final uri = Uri.parse('$_baseUrl/api/video/$videoId');
      final response = await _client.get(
        uri,
        headers: await _getHeaders(url: uri.toString()),
      ).timeout(_defaultTimeout);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to get video URL: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final urls = Map<String, String>.from(data['urls'] as Map);
      
      // Select quality based on network
      String quality;
      switch (networkSpeed) {
        case NetworkSpeed.fast:
          quality = '720p';
          break;
        case NetworkSpeed.medium:
          quality = '480p';
          break;
        case NetworkSpeed.slow:
          quality = '360p';
          break;
      }
      
      // Fallback to lower quality if preferred not available
      final url = urls[quality] ?? urls['480p'] ?? urls.values.first;
      
      debugPrint('✅ Selected $quality quality: $url');
      return url;
      
    } catch (e) {
      debugPrint('❌ Error getting video URL: $e');
      return null;
    }
  }
  
  /// Prefetch next videos
  void prefetchNextVideos(List<String> videoIds) {
    debugPrint('🔄 Prefetching ${videoIds.length} videos');
    
    for (final videoId in videoIds.take(_prefetchCount)) {
      if (!_prefetchingVideos.contains(videoId) && 
          !_controllers.containsKey(videoId) &&
          !_memoryCache.containsKey(videoId)) {
        _prefetchVideo(videoId);
      }
    }
  }
  
  /// Prefetch a single video
  Future<void> _prefetchVideo(String videoId) async {
    if (_prefetchingVideos.contains(videoId)) return;
    
    _prefetchingVideos.add(videoId);
    debugPrint('⬇️ Prefetching video: $videoId');
    
    try {
      final networkSpeed = await _detectNetworkSpeed();
      final url = await getOptimalVideoUrl(videoId, networkSpeed);
      
      if (url != null && !url.startsWith('memory://') && !url.startsWith('/')) {
        // Create controller for prefetch
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _controllers[videoId] = controller;
        
        // Initialize and buffer
        await controller.initialize();
        await controller.setVolume(0); // Mute for prefetch
        await controller.play();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.pause();
        
        debugPrint('✅ Prefetched video: $videoId');
        
        // Notify progress
        _progressController.add(VideoLoadProgress(
          videoId: videoId,
          progress: 1.0,
          isComplete: true,
        ));
      }
    } catch (e) {
      debugPrint('❌ Error prefetching video $videoId: $e');
      _progressController.add(VideoLoadProgress(
        videoId: videoId,
        progress: 0.0,
        isComplete: false,
        error: e.toString(),
      ));
    } finally {
      _prefetchingVideos.remove(videoId);
    }
  }
  
  /// Cache video data locally
  Future<void> cacheVideoLocally(String videoId, Uint8List videoData) async {
    debugPrint('💾 Caching video locally: $videoId (${videoData.length} bytes)');
    
    // Add to memory cache
    _memoryCache[videoId] = videoData;
    
    // Manage memory cache size
    if (_memoryCache.length > _maxMemoryCacheItems) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
      debugPrint('🗑️ Removed oldest from memory cache: $oldestKey');
    }
    
    // Save to disk
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/videos/$videoId.mp4');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(videoData);
      
      // Track in preferences
      final cachedVideos = _prefs.getStringList('${_cacheKeyPrefix}videos') ?? [];
      if (!cachedVideos.contains(videoId)) {
        cachedVideos.add(videoId);
        await _prefs.setStringList('${_cacheKeyPrefix}videos', cachedVideos);
      }
      
      // Manage disk cache size
      if (cachedVideos.length > _maxDiskCacheItems) {
        await _cleanupOldCache();
      }
      
      debugPrint('✅ Saved video to disk: $videoId');
    } catch (e) {
      debugPrint('❌ Error saving video to disk: $e');
    }
  }
  
  /// Get cached video path
  Future<String?> _getCachedVideoPath(String videoId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/videos/$videoId.mp4';
      return path;
    } catch (e) {
      debugPrint('❌ Error getting cached path: $e');
      return null;
    }
  }
  
  /// Start prefetching videos from feed
  void _startPrefetching(List<VideoItem> videos) {
    if (videos.isEmpty) return;
    
    // Prefetch next N videos
    final videoIds = videos.take(_prefetchCount).map((v) => v.id).toList();
    prefetchNextVideos(videoIds);
  }
  
  /// Clean up old cached videos
  Future<void> _cleanupOldCache() async {
    debugPrint('🧹 Cleaning up old cache');
    
    try {
      final cachedVideos = _prefs.getStringList('${_cacheKeyPrefix}videos') ?? [];
      if (cachedVideos.length <= _maxDiskCacheItems) return;
      
      final directory = await getApplicationDocumentsDirectory();
      final videosToRemove = cachedVideos.length - _maxDiskCacheItems;
      
      for (int i = 0; i < videosToRemove; i++) {
        final videoId = cachedVideos[i];
        final file = File('${directory.path}/videos/$videoId.mp4');
        
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Deleted cached video: $videoId');
        }
      }
      
      // Update preferences
      final remainingVideos = cachedVideos.skip(videosToRemove).toList();
      await _prefs.setStringList('${_cacheKeyPrefix}videos', remainingVideos);
      
    } catch (e) {
      debugPrint('❌ Error cleaning cache: $e');
    }
  }
  
  /// Get video controller for playback
  VideoPlayerController? getController(String videoId) {
    return _controllers[videoId];
  }
  
  /// Release video controller
  void releaseController(String videoId) {
    final controller = _controllers[videoId];
    if (controller != null) {
      controller.dispose();
      _controllers.remove(videoId);
      debugPrint('♻️ Released controller for: $videoId');
    }
  }
  
  /// Get load progress stream
  Stream<VideoLoadProgress> get loadProgress => _progressController.stream;
  
  /// Dispose of resources
  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    
    // Clear memory cache
    _memoryCache.clear();
    
    // Close stream
    _progressController.close();
    
    super.dispose();
  }
}