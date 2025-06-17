// ABOUTME: State management provider for NIP-71 video feed functionality
// ABOUTME: Manages video events, subscriptions, and UI state for the feed screen

import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import '../services/video_event_service.dart';
import '../services/nostr_service_interface.dart';

/// Provider for managing video feed state and operations
class VideoFeedProvider extends ChangeNotifier {
  final VideoEventService _videoEventService;
  final INostrService _nostrService;
  
  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _error;
  
  VideoFeedProvider({
    required VideoEventService videoEventService,
    required INostrService nostrService,
  }) : _videoEventService = videoEventService,
       _nostrService = nostrService {
    
    // Listen to video event service changes
    _videoEventService.addListener(_onVideoEventServiceChanged);
  }
  
  // Getters
  List<VideoEvent> get videoEvents => _videoEventService.videoEvents;
  bool get isInitialized => _isInitialized;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasEvents => _videoEventService.hasEvents;
  bool get isLoading => _videoEventService.isLoading;
  String? get error => _error ?? _videoEventService.error;
  int get eventCount => _videoEventService.eventCount;
  bool get isSubscribed => _videoEventService.isSubscribed;
  bool get canLoadMore => hasEvents && !isLoadingMore;
  
  /// Initialize the video feed provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🎬 Starting VideoFeedProvider initialization...');
      _error = null;
      notifyListeners();
      
      // Check if Nostr service is disposed
      if (_nostrService.isDisposed) {
        debugPrint('❌ NostrService is disposed - cannot initialize video feed');
        throw Exception('Failed to initialize video feed: A NostrService was used after being disposed. Once you have called dispose() on a NostrService, it can no longer be used.');
      }
      
      debugPrint('🔍 Checking Nostr service status...');
      debugPrint('  - Initialized: ${_nostrService.isInitialized}');
      debugPrint('  - Has keys: ${_nostrService.hasKeys}');
      debugPrint('  - Connected relays: ${_nostrService.connectedRelayCount}');
      
      // Ensure Nostr service is initialized
      if (!_nostrService.isInitialized) {
        debugPrint('📡 Nostr service not initialized, initializing now...');
        await _nostrService.initialize();
        debugPrint('📡 Nostr service initialization completed');
      } else {
        debugPrint('📡 Nostr service already initialized');
      }
      
      // Subscribe to video events
      debugPrint('🎥 Subscribing to video event feed...');
      await _videoEventService.subscribeToVideoFeed();
      debugPrint('🎥 Video event subscription completed');
      
      _isInitialized = true;
      _error = null;
      
      debugPrint('✅ VideoFeedProvider initialization completed successfully!');
      debugPrint('📊 Final feed status:');
      debugPrint('  - Events loaded: ${_videoEventService.eventCount}');
      debugPrint('  - Subscribed: ${_videoEventService.isSubscribed}');
    } catch (e) {
      _error = 'Failed to initialize video feed: $e';
      debugPrint('❌ VideoFeedProvider initialization failed: $e');
      debugPrint('📊 Error occurred during video feed setup');
    }
    
    notifyListeners();
  }
  
  /// Refresh the video feed
  Future<void> refreshFeed() async {
    if (_isRefreshing) return;
    
    _isRefreshing = true;
    _error = null;
    notifyListeners();
    
    try {
      await _videoEventService.refreshVideoFeed();
      debugPrint('✅ Video feed refreshed');
    } catch (e) {
      _error = 'Failed to refresh feed: $e';
      debugPrint('❌ Failed to refresh video feed: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
  
  /// Load more historical events
  Future<void> loadMoreEvents() async {
    if (_isLoadingMore || !hasEvents) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      await _videoEventService.loadMoreEvents();
      debugPrint('✅ Loaded more video events');
    } catch (e) {
      _error = 'Failed to load more events: $e';
      debugPrint('❌ Failed to load more events: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }
  
  /// Subscribe to specific user's videos
  Future<void> subscribeToUser(String pubkey) async {
    try {
      await _videoEventService.subscribeToUserVideos(pubkey);
      _error = null;
      debugPrint('✅ Subscribed to user videos: ${pubkey.substring(0, 8)}...');
    } catch (e) {
      _error = 'Failed to subscribe to user: $e';
      debugPrint('❌ Failed to subscribe to user videos: $e');
    }
    
    notifyListeners();
  }
  
  /// Subscribe to videos with hashtags
  Future<void> subscribeToHashtags(List<String> hashtags) async {
    try {
      await _videoEventService.subscribeToHashtagVideos(hashtags);
      _error = null;
      debugPrint('✅ Subscribed to hashtag videos: ${hashtags.join(', ')}');
    } catch (e) {
      _error = 'Failed to subscribe to hashtags: $e';
      debugPrint('❌ Failed to subscribe to hashtag videos: $e');
    }
    
    notifyListeners();
  }
  
  /// Get video event by ID
  VideoEvent? getVideoEvent(String eventId) {
    return _videoEventService.getVideoEventById(eventId);
  }
  
  /// Get videos by author
  List<VideoEvent> getVideosByAuthor(String pubkey) {
    return _videoEventService.getVideoEventsByAuthor(pubkey);
  }
  
  /// Get videos by hashtags
  List<VideoEvent> getVideosByHashtags(List<String> hashtags) {
    return _videoEventService.getVideoEventsByHashtags(hashtags);
  }
  
  /// Get videos sorted by engagement
  List<VideoEvent> getVideosByEngagement() {
    return _videoEventService.getVideoEventsByEngagement();
  }
  
  /// Get recent videos from last N hours
  List<VideoEvent> getRecentVideos({int hours = 24}) {
    return _videoEventService.getRecentVideoEvents(hours: hours);
  }
  
  /// Get unique authors
  Set<String> getUniqueAuthors() {
    return _videoEventService.getUniqueAuthors();
  }
  
  /// Get all hashtags
  Set<String> getAllHashtags() {
    return _videoEventService.getAllHashtags();
  }
  
  /// Get video count by author
  Map<String, int> getVideoCountByAuthor() {
    return _videoEventService.getVideoCountByAuthor();
  }
  
  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Retry initialization
  Future<void> retry() async {
    clearError();
    _isInitialized = false;
    await initialize();
  }
  
  /// Handle changes from video event service
  void _onVideoEventServiceChanged() {
    notifyListeners();
  }
  
  @override
  void dispose() {
    _videoEventService.removeListener(_onVideoEventServiceChanged);
    super.dispose();
  }
}