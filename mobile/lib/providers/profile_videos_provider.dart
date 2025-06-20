// ABOUTME: Provider for managing user-specific video fetching and grid display
// ABOUTME: Fetches Kind 22 video events by author with pagination and caching

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr/nostr.dart';
import '../models/video_event.dart';
import '../services/nostr_service_interface.dart';

/// Loading state for user videos
enum ProfileVideosLoadingState {
  idle,
  loading,
  loaded,
  loadingMore,
  error,
}

/// Provider for managing user-specific video fetching with pagination
class ProfileVideosProvider extends ChangeNotifier {
  final INostrService _nostrService;

  // State management
  ProfileVideosLoadingState _loadingState = ProfileVideosLoadingState.idle;
  List<VideoEvent> _videos = [];
  String? _error;
  String? _currentPubkey;
  bool _hasMore = true;
  int? _lastTimestamp;

  // Cache for different users' videos
  final Map<String, List<VideoEvent>> _videosCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, bool> _hasMoreCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 10);

  // Pagination settings
  static const int _pageSize = 20;

  // Subscription management
  StreamSubscription<Event>? _subscription;

  ProfileVideosProvider(this._nostrService);

  // Getters
  ProfileVideosLoadingState get loadingState => _loadingState;
  List<VideoEvent> get videos => List.unmodifiable(_videos);
  String? get error => _error;
  bool get isLoading => _loadingState == ProfileVideosLoadingState.loading;
  bool get isLoadingMore => _loadingState == ProfileVideosLoadingState.loadingMore;
  bool get hasError => _loadingState == ProfileVideosLoadingState.error;
  bool get hasVideos => _videos.isNotEmpty;
  bool get hasMore => _hasMore;
  int get videoCount => _videos.length;

  /// Load videos for a specific user
  Future<void> loadVideosForUser(String pubkey) async {
    if (_currentPubkey == pubkey && _videos.isNotEmpty) {
      // Already loaded for this user
      return;
    }

    // Check cache first
    final cached = _getCachedVideos(pubkey);
    if (cached != null) {
      _videos = cached;
      _currentPubkey = pubkey;
      _hasMore = _hasMoreCache[pubkey] ?? true;
      _loadingState = ProfileVideosLoadingState.loaded;
      _error = null;
      notifyListeners();
      return;
    }

    _setLoadingState(ProfileVideosLoadingState.loading);
    _currentPubkey = pubkey;
    _videos = [];
    _error = null;
    _hasMore = true;
    _lastTimestamp = null;

    try {
      debugPrint('📹 Loading videos for user: ${pubkey.substring(0, 8)}...');

      // Cancel existing subscription
      await _subscription?.cancel();

      // Create filter for user's Kind 22 video events
      final filter = Filter(
        authors: [pubkey],
        kinds: [22], // NIP-71 short video events
        limit: _pageSize,
      );

      final completer = Completer<void>();
      final receivedVideos = <VideoEvent>[];

      // Subscribe to video events
      _subscription = _nostrService.subscribeToEvents(filters: [filter]).listen(
        (event) {
          try {
            final videoEvent = VideoEvent.fromNostrEvent(event);
            
            // Avoid duplicates
            if (!receivedVideos.any((v) => v.id == videoEvent.id)) {
              receivedVideos.add(videoEvent);
              debugPrint('📹 Received video: ${videoEvent.id.substring(0, 8)} (${videoEvent.title ?? 'No title'})');
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing video event: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Error in video subscription: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Set timeout to avoid hanging indefinitely
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future;

      // Cancel the subscription after data fetch to prevent resource leak
      await _subscription?.cancel();
      _subscription = null;

      // Sort videos by creation time (newest first)
      receivedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _videos = receivedVideos;
      _hasMore = receivedVideos.length >= _pageSize;
      
      if (receivedVideos.isNotEmpty) {
        _lastTimestamp = receivedVideos.last.createdAt;
      }

      // Cache the results
      _cacheVideos(pubkey, _videos, _hasMore);

      _setLoadingState(ProfileVideosLoadingState.loaded);
      debugPrint('✅ Loaded ${_videos.length} videos for user');

    } catch (e) {
      _error = e.toString();
      _setLoadingState(ProfileVideosLoadingState.error);
      debugPrint('❌ Error loading videos: $e');
    }
  }

  /// Load more videos for pagination
  Future<void> loadMoreVideos() async {
    if (!_hasMore || _currentPubkey == null || isLoadingMore) {
      return;
    }

    _setLoadingState(ProfileVideosLoadingState.loadingMore);

    try {
      debugPrint('📹 Loading more videos for user: ${_currentPubkey!.substring(0, 8)}...');

      // Cancel existing subscription
      await _subscription?.cancel();

      // Create filter for next page
      final filter = Filter(
        authors: [_currentPubkey!],
        kinds: [22],
        until: _lastTimestamp, // Get videos older than the last one we have
        limit: _pageSize,
      );

      final completer = Completer<void>();
      final receivedVideos = <VideoEvent>[];

      // Subscribe to more video events
      _subscription = _nostrService.subscribeToEvents(filters: [filter]).listen(
        (event) {
          try {
            final videoEvent = VideoEvent.fromNostrEvent(event);
            
            // Avoid duplicates with existing videos
            if (!_videos.any((v) => v.id == videoEvent.id) && 
                !receivedVideos.any((v) => v.id == videoEvent.id)) {
              receivedVideos.add(videoEvent);
              debugPrint('📹 Received more video: ${videoEvent.id.substring(0, 8)}');
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing video event: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Error in load more subscription: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      // Set timeout
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future;

      // Cancel the subscription after data fetch to prevent resource leak  
      await _subscription?.cancel();
      _subscription = null;

      // Sort new videos by creation time
      receivedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Add new videos to existing list
      _videos.addAll(receivedVideos);
      _hasMore = receivedVideos.length >= _pageSize;
      
      if (receivedVideos.isNotEmpty) {
        _lastTimestamp = receivedVideos.last.createdAt;
      }

      // Update cache
      _cacheVideos(_currentPubkey!, _videos, _hasMore);

      _setLoadingState(ProfileVideosLoadingState.loaded);
      debugPrint('✅ Loaded ${receivedVideos.length} more videos (total: ${_videos.length})');

    } catch (e) {
      _error = e.toString();
      _setLoadingState(ProfileVideosLoadingState.error);
      debugPrint('❌ Error loading more videos: $e');
    }
  }

  /// Refresh videos for current user
  Future<void> refreshVideos() async {
    if (_currentPubkey != null) {
      _clearCache(_currentPubkey!);
      await loadVideosForUser(_currentPubkey!);
    }
  }

  /// Get cached videos if available and not expired
  List<VideoEvent>? _getCachedVideos(String pubkey) {
    final videos = _videosCache[pubkey];
    final timestamp = _cacheTimestamps[pubkey];

    if (videos != null && timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age < _cacheExpiry) {
        debugPrint('💾 Using cached videos for ${pubkey.substring(0, 8)} (age: ${age.inMinutes}min)');
        return videos;
      } else {
        debugPrint('⏰ Video cache expired for ${pubkey.substring(0, 8)} (age: ${age.inMinutes}min)');
        _clearCache(pubkey);
      }
    }

    return null;
  }

  /// Cache videos for a user
  void _cacheVideos(String pubkey, List<VideoEvent> videos, bool hasMore) {
    _videosCache[pubkey] = List.from(videos);
    _cacheTimestamps[pubkey] = DateTime.now();
    _hasMoreCache[pubkey] = hasMore;
    debugPrint('💾 Cached ${videos.length} videos for ${pubkey.substring(0, 8)}');
  }

  /// Clear cache for a specific user
  void _clearCache(String pubkey) {
    _videosCache.remove(pubkey);
    _cacheTimestamps.remove(pubkey);
    _hasMoreCache.remove(pubkey);
  }

  /// Clear all cached videos
  void clearAllCache() {
    _videosCache.clear();
    _cacheTimestamps.clear();
    _hasMoreCache.clear();
    debugPrint('🗑️ Cleared all video cache');
  }

  /// Set loading state and notify listeners
  void _setLoadingState(ProfileVideosLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing ProfileVideosProvider');
    _subscription?.cancel();
    super.dispose();
  }
}