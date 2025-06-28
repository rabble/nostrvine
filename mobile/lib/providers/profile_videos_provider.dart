// ABOUTME: Provider for managing user-specific video fetching and grid display
// ABOUTME: Fetches Kind 34550 video events by author with pagination and caching

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/filter.dart';
import '../models/video_event.dart';
import '../services/nostr_service_interface.dart';
import '../services/subscription_manager.dart';
import '../services/video_event_service.dart';

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
  SubscriptionManager? _subscriptionManager;
  VideoEventService? _videoEventService;

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
  String? _currentSubscriptionId;

  ProfileVideosProvider(this._nostrService);

  /// Set the subscription manager for proper subscription handling
  void setSubscriptionManager(SubscriptionManager subscriptionManager) {
    _subscriptionManager = subscriptionManager;
  }
  
  /// Set the video event service for accessing cached videos
  void setVideoEventService(VideoEventService videoEventService) {
    _videoEventService = videoEventService;
  }

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
      
      // First check if we have videos in the VideoEventService cache
      if (_videoEventService != null) {
        final cachedVideos = _videoEventService!.getVideosByAuthor(pubkey);
        if (cachedVideos.isNotEmpty) {
          debugPrint('✅ Found ${cachedVideos.length} videos in cache for ${pubkey.substring(0, 8)}');
          _videos = cachedVideos;
          _hasMore = false; // We have all videos from cache
          _setLoadingState(ProfileVideosLoadingState.loaded);
          _cacheVideos(pubkey, _videos, _hasMore);
          notifyListeners();
          
          // TODO: Background refresh if cache is stale
          // This would check ProfileCacheService.shouldRefreshProfile()
          // and create a background subscription if needed
          
          return; // Exit early - no subscription needed
        } else {
          debugPrint('⚠️ No videos found in cache for ${pubkey.substring(0, 8)}, fetching from relays...');
        }
      }

      // Cancel existing subscription if any
      if (_currentSubscriptionId != null && _subscriptionManager != null) {
        _subscriptionManager!.cancelSubscription(_currentSubscriptionId!);
        _currentSubscriptionId = null;
      }

      // Check if we have subscription manager
      if (_subscriptionManager == null) {
        throw Exception('SubscriptionManager not available - cannot load profile videos');
      }

      // Create filter for user's Kind 22 video events
      final filter = Filter(
        authors: [pubkey],
        kinds: [22], // NIP-71 short video events
        limit: _pageSize,
      );

      debugPrint('🔍 Creating filter for profile videos:');
      debugPrint('  - Author: $pubkey');
      debugPrint('  - Kinds: [22]');
      debugPrint('  - Limit: $_pageSize');

      final completer = Completer<void>();
      final receivedVideos = <VideoEvent>[];

      // Subscribe to video events using SubscriptionManager
      _currentSubscriptionId = await _subscriptionManager!.createSubscription(
        name: 'profile_videos_${_currentPubkey!.substring(0, 8)}',
        filters: [filter],
        onEvent: (event) {
          debugPrint('📨 Received event in profile videos: ${event.id.substring(0, 8)}, kind: ${event.kind}, author: ${event.pubkey.substring(0, 8)}');
          try {
            if (event.kind == 22) {
              final videoEvent = VideoEvent.fromNostrEvent(event);
              
              // Avoid duplicates
              if (!receivedVideos.any((v) => v.id == videoEvent.id)) {
                receivedVideos.add(videoEvent);
                debugPrint('📹 Received video: ${videoEvent.id.substring(0, 8)} (${videoEvent.title ?? 'No title'})');
              }
            } else {
              debugPrint('⚠️ Received non-video event, kind: ${event.kind}');
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
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        priority: 2, // High priority for profile videos (user-facing)
      );

      // Set timeout to avoid hanging indefinitely
      Timer(const Duration(seconds: 8), () {
        if (!completer.isCompleted) {
          debugPrint('⏰ Video loading timeout reached for ${pubkey.substring(0, 8)}');
          completer.complete();
        }
      });

      await completer.future;

      debugPrint('📊 Profile video subscription completed:');
      debugPrint('  - Received ${receivedVideos.length} videos for author $pubkey');
      if (receivedVideos.isNotEmpty) {
        debugPrint('  - First video: ${receivedVideos.first.id.substring(0, 8)} (${receivedVideos.first.title ?? 'No title'})');
      }

      // Close the subscription after data fetch
      if (_currentSubscriptionId != null && _subscriptionManager != null) {
        _subscriptionManager!.cancelSubscription(_currentSubscriptionId!);
        _currentSubscriptionId = null;
      }

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
      debugPrint('✅ Loaded ${_videos.length} videos for user ${pubkey.substring(0, 8)}...');
      
      // Force notification even if empty to ensure UI updates
      notifyListeners();

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

      // Check if we have subscription manager
      if (_subscriptionManager == null) {
        throw Exception('SubscriptionManager not available - cannot load more profile videos');
      }

      // Cancel existing subscription if any
      if (_currentSubscriptionId != null) {
        _subscriptionManager!.cancelSubscription(_currentSubscriptionId!);
        _currentSubscriptionId = null;
      }

      // Create filter for next page
      final filter = Filter(
        authors: [_currentPubkey!],
        kinds: [22], // NIP-71 short video events
        until: _lastTimestamp, // Get videos older than the last one we have
        limit: _pageSize,
      );

      final completer = Completer<void>();
      final receivedVideos = <VideoEvent>[];

      // Subscribe to more video events using SubscriptionManager
      _currentSubscriptionId = await _subscriptionManager!.createSubscription(
        name: 'profile_videos_more_${_currentPubkey!.substring(0, 8)}',
        filters: [filter],
        onEvent: (event) {
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
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        priority: 5, // Medium priority for load more videos
      );

      // Set timeout
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future;

      // Cancel the subscription after data fetch to prevent resource leak  
      if (_currentSubscriptionId != null && _subscriptionManager != null) {
        _subscriptionManager!.cancelSubscription(_currentSubscriptionId!);
        _currentSubscriptionId = null;
      }

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
    
    // Close subscription using SubscriptionManager if available
    if (_currentSubscriptionId != null && _subscriptionManager != null) {
      _subscriptionManager!.cancelSubscription(_currentSubscriptionId!);
      _currentSubscriptionId = null;
    }
    
    super.dispose();
  }
}