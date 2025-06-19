// ABOUTME: State management provider for NIP-71 video feed functionality  
// ABOUTME: Single source of truth using VideoManager for video state, preloading, and memory management

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../services/video_event_service.dart';
import '../services/nostr_service_interface.dart';
import '../services/video_cache_service.dart';
import '../services/user_profile_service.dart';
import '../services/video_manager_interface.dart';
import '../services/video_manager_service.dart';

/// Provider for managing video feed state and operations using VideoManager
/// 
/// This provider replaces the dual-list architecture (VideoEventService + VideoCacheService)
/// with a single VideoManager that serves as the source of truth for:
/// - Video ordering and state management
/// - Memory-efficient preloading (<500MB)
/// - Race condition prevention  
/// - Circuit breaker error handling
class VideoFeedProvider extends ChangeNotifier {
  final VideoEventService _videoEventService;
  final INostrService _nostrService;
  final VideoCacheService _videoCacheService; // Legacy - kept for backward compatibility
  final UserProfileService _userProfileService;
  final IVideoManager _videoManager;
  
  bool _isInitialized = false;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  String? _error;
  
  // Track events we've already processed for profile fetching to avoid loops
  final Set<String> _processedEventIds = <String>{};
  
  // Profile batching optimization
  final Set<String> _pendingProfileFetches = <String>{};
  Timer? _profileFetchDebounceTimer;
  
  // Video manager state subscription
  StreamSubscription<void>? _videoManagerSubscription;
  
  // Notification batching to prevent infinite rebuild loops
  Timer? _notificationTimer;
  bool _hasPendingNotification = false;
  
  VideoFeedProvider({
    required VideoEventService videoEventService,
    required INostrService nostrService,
    required VideoCacheService videoCacheService,
    required UserProfileService userProfileService,
    IVideoManager? videoManager,
  }) : _videoEventService = videoEventService,
       _nostrService = nostrService,
       _videoCacheService = videoCacheService,
       _userProfileService = userProfileService,
       _videoManager = videoManager ?? VideoManagerService(
         config: VideoManagerConfig.wifi(), // Default to WiFi optimized
       ) {
    
    // Listen to video event service changes (for new videos from Nostr)
    _videoEventService.addListener(_onVideoEventServiceChanged);
    
    // Listen to video manager state changes (replaces cache service listener)
    _videoManagerSubscription = _videoManager.stateChanges.listen((_) {
      notifyListeners();
    });
  }
  
  // Getters - VideoManager as single source of truth
  List<VideoEvent> get videoEvents => _videoManager.videos;
  List<VideoEvent> get readyVideos => _videoManager.readyVideos;
  List<VideoEvent> get allVideoEvents => _videoEventService.videoEvents; // Raw events from Nostr
  bool get isInitialized => _isInitialized;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasEvents => _videoManager.videos.isNotEmpty;
  bool get isLoading => _videoEventService.isLoading;
  String? get error => _error ?? _videoEventService.error;
  int get eventCount => _videoManager.videos.length;
  bool get isSubscribed => _videoEventService.isSubscribed;
  bool get canLoadMore => _videoEventService.hasEvents && !isLoadingMore;
  
  // Legacy compatibility - gradually replace these with videoManager equivalents
  VideoCacheService get videoCacheService => _videoCacheService;
  UserProfileService get userProfileService => _userProfileService;
  
  // New VideoManager interface methods
  IVideoManager get videoManager => _videoManager;
  VideoState? getVideoState(String videoId) => _videoManager.getVideoState(videoId);
  VideoPlayerController? getController(String videoId) => _videoManager.getController(videoId);
  Map<String, dynamic> getDebugInfo() => _videoManager.getDebugInfo();
  
  /// Initialize the video feed provider
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🎬 Starting VideoFeedProvider initialization...');
      _error = null;
      _scheduleNotification();
      
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
      
      // Initialize user profile service
      debugPrint('👤 Initializing user profile service...');
      await _userProfileService.initialize();
      debugPrint('👤 User profile service initialized');
      
      // Subscribe to video events
      debugPrint('🎥 Subscribing to video event feed...');
      await _videoEventService.subscribeToVideoFeed();
      debugPrint('🎥 Video event subscription completed');
      
      // Add initial events to VideoManager (replaces dual-list processing)
      if (_videoEventService.hasEvents) {
        debugPrint('📋 Adding ${_videoEventService.eventCount} initial video events to VideoManager...');
        await _addEventsToVideoManager(_videoEventService.videoEvents);
        
        // Start intelligent preloading around position 0
        debugPrint('⚡ Starting intelligent preloading...');
        _videoManager.preloadAroundIndex(0, preloadRange: 2);
      }
      
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
    
    _scheduleNotification();
  }
  
  /// Refresh the video feed
  Future<void> refreshFeed() async {
    if (_isRefreshing) return;
    
    _isRefreshing = true;
    _error = null;
    _scheduleNotification();
    
    try {
      await _videoEventService.refreshVideoFeed();
      debugPrint('✅ Video feed refreshed');
    } catch (e) {
      _error = 'Failed to refresh feed: $e';
      debugPrint('❌ Failed to refresh video feed: $e');
    } finally {
      _isRefreshing = false;
      _scheduleNotification();
    }
  }
  
  /// Load more historical events
  Future<void> loadMoreEvents() async {
    if (_isLoadingMore || !hasEvents) return;
    
    _isLoadingMore = true;
    _scheduleNotification();
    
    try {
      await _videoEventService.loadMoreEvents();
      debugPrint('✅ Loaded more video events');
    } catch (e) {
      _error = 'Failed to load more events: $e';
      debugPrint('❌ Failed to load more events: $e');
    } finally {
      _isLoadingMore = false;
      _scheduleNotification();
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
    
    _scheduleNotification();
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
    
    _scheduleNotification();
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
  
  /// Preload videos around current index for smooth playback
  Future<void> preloadVideosAroundIndex(int currentIndex) async {
    // Use VideoManager's intelligent preloading (replaces cache service)
    _videoManager.preloadAroundIndex(currentIndex);
    debugPrint('⚡ VideoManager preloading around index $currentIndex');
  }
  
  /// Clear error state
  void clearError() {
    _error = null;
    _scheduleNotification();
  }
  
  /// Retry initialization
  Future<void> retry() async {
    clearError();
    _isInitialized = false;
    await initialize();
  }
  
  /// Handle changes from video event service (new videos from Nostr)
  void _onVideoEventServiceChanged() {
    // Add new video events to VideoManager (replaces dual-list processing)
    if (_videoEventService.hasEvents) {
      debugPrint('📢 Video event service changed - adding ${_videoEventService.videoEvents.length} events to VideoManager...');
      _addEventsToVideoManager(_videoEventService.videoEvents);
      debugPrint('🎯 VideoManager now has ${_videoManager.videos.length} videos');
      
      // Fetch profiles for video authors
      _fetchProfilesForVideos(_videoEventService.videoEvents);
    }
    // Note: VideoManager state changes will trigger UI updates via stream subscription
  }
  
  /// Fetch user profiles for video authors (only for new events)
  void _fetchProfilesForVideos(List<VideoEvent> videoEvents) {
    // Filter to only new events we haven't processed for profile fetching
    final newEvents = videoEvents
        .where((event) => !_processedEventIds.contains(event.id))
        .toList();
    
    if (newEvents.isEmpty) {
      return; // No new events to process
    }
    
    // Collect authors that need profiles
    final authorsToFetch = newEvents
        .map((event) => event.pubkey)
        .where((pubkey) => !_userProfileService.hasProfile(pubkey))
        .toSet();
    
    if (authorsToFetch.isNotEmpty) {
      debugPrint('👥 Adding ${authorsToFetch.length} authors to batched profile fetch queue...');
      
      // Add to pending batch
      _pendingProfileFetches.addAll(authorsToFetch);
      
      // Cancel existing timer and start new debounce timer
      _profileFetchDebounceTimer?.cancel();
      _profileFetchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _executeBatchedProfileFetch();
      });
    }
    
    // Mark these events as processed
    for (final event in newEvents) {
      _processedEventIds.add(event.id);
    }
  }
  
  /// Execute batched profile fetch with collected authors
  void _executeBatchedProfileFetch() {
    if (_pendingProfileFetches.isEmpty) return;
    
    final authorsToFetch = _pendingProfileFetches.toList();
    _pendingProfileFetches.clear();
    
    debugPrint('👥 Executing batched profile fetch for ${authorsToFetch.length} authors (debounced)');
    _userProfileService.fetchMultipleProfiles(authorsToFetch);
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
  
  /// Add video events to VideoManager, filtering out duplicates
  Future<void> _addEventsToVideoManager(List<VideoEvent> events) async {
    final existingIds = _videoManager.videos.map((v) => v.id).toSet();
    final newEvents = events.where((event) => !existingIds.contains(event.id)).toList();
    
    debugPrint('📋 Adding ${newEvents.length} new events to VideoManager (filtered ${events.length - newEvents.length} duplicates)');
    
    for (final event in newEvents) {
      try {
        await _videoManager.addVideoEvent(event);
      } catch (e) {
        debugPrint('⚠️ Failed to add video ${event.id} to VideoManager: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _videoEventService.removeListener(_onVideoEventServiceChanged);
    _videoManagerSubscription?.cancel();
    _profileFetchDebounceTimer?.cancel();
    _notificationTimer?.cancel();
    _videoManager.dispose();
    // Legacy: Keep cache service for backward compatibility
    super.dispose();
  }
}