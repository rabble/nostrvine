// ABOUTME: Simple bridge service to connect VideoEventService to VideoManager
// ABOUTME: Replaces the complex VideoFeedProvider with minimal bridging logic

import 'dart:async';
import '../models/video_event.dart';
import 'video_event_service.dart';
import 'video_manager_interface.dart';
import 'video_manager_service.dart';
import 'user_profile_service.dart';
import 'social_service.dart';
import 'curation_service.dart';
import '../utils/unified_logger.dart';
import '../constants/app_constants.dart';

/// Minimal bridge to feed Nostr video events into VideoManager
/// 
/// This replaces the complex VideoFeedProvider with a simple service
/// that just connects VideoEventService (Nostr events) to VideoManager (UI state).
class VideoEventBridge {
  final VideoEventService _videoEventService;
  final IVideoManager _videoManager;
  final UserProfileService _userProfileService;
  final SocialService? _socialService;
  // ignore: unused_field
  final CurationService? _curationService;
  int _initRetryCount = 0;
  
  StreamSubscription? _eventSubscription;
  final Set<String> _processedEventIds = {};
  
  // Following feed loading state
  bool _discoveryFeedLoaded = false;
  // ignore: unused_field
  bool _curationSynced = false;
  Set<String> _followingPubkeys = {};
  
  VideoEventBridge({
    required VideoEventService videoEventService,
    required IVideoManager videoManager,
    required UserProfileService userProfileService,
    SocialService? socialService,
    CurationService? curationService,
  }) : _videoEventService = videoEventService,
       _videoManager = videoManager,
       _userProfileService = userProfileService,
       _socialService = socialService,
       _curationService = curationService;
  
  /// Initialize the bridge and start syncing events
  Future<void> initialize() async {
    Log.debug('� Initializing VideoEventBridge...', name: 'VideoEventBridge', category: LogCategory.video);
    
    try {
      // Set up proper social feed priority in VideoManager
      final followingPubkeys = _socialService?.followingPubkeys ?? <String>{};
      
      // If user has following list, use that. Otherwise fall back to classic vines
      final Set<String> priorityPubkeys = followingPubkeys.isNotEmpty 
          ? followingPubkeys.toSet() 
          : {AppConstants.classicVinesPubkey};
      
      Log.debug('FOLLOWING_DEBUG: User following=${followingPubkeys.length}, Priority=${priorityPubkeys.length} (${followingPubkeys.isEmpty ? "classic vines fallback" : "user follows"})', name: 'VideoEventBridge', category: LogCategory.video);
      
      // Update VideoManager with following list for proper prioritization
      if (_videoManager is VideoManagerService) {
        (_videoManager as VideoManagerService).updateFollowingList(priorityPubkeys);
      } else {
        Log.debug('FOLLOWING_DEBUG: VideoManager is not VideoManagerService type!', name: 'VideoEventBridge', category: LogCategory.video);
      }
      
      // FIRST PRIORITY: Load content from priority accounts (either user follows or classic vines fallback)
      if (priorityPubkeys.isNotEmpty) {
        Log.debug('� Loading following feed FIRST from ${priorityPubkeys.length} accounts', name: 'VideoEventBridge', category: LogCategory.video);
        await _videoEventService.subscribeToVideoFeed(
          authors: priorityPubkeys.toList(),
          limit: 200, // Get plenty of following content
          replace: true, // Start fresh with following content
        );
        
        // Set up listener to trigger discovery feed once we get following content
        _setupFollowingListener(priorityPubkeys);
      } else {
        // No follows, just load discovery feed
        Log.debug('� No following list, loading discovery feed directly', name: 'VideoEventBridge', category: LogCategory.video);
        await _loadDiscoveryFeed();
      }
      
      // Add initial events to VideoManager IMMEDIATELY
      if (_videoEventService.hasEvents) {
        await _addEventsToVideoManager(_videoEventService.videoEvents);
        Log.debug('Initial videos loaded immediately', name: 'VideoEventBridge', category: LogCategory.video);
      } else {
        // Don't wait! Start listening immediately and add videos as they arrive
        Log.debug('No cached videos - will add videos as they stream in from relay', name: 'VideoEventBridge', category: LogCategory.video);
        
        // Give just a tiny window for very fast responses
        int waitAttempts = 0;
        while (!_videoEventService.hasEvents && waitAttempts < 3) { // Reduced from 10 to 3
          await Future.delayed(const Duration(milliseconds: 50)); // Reduced from 100ms
          waitAttempts++;
        }
        
        // Add any videos that arrived quickly
        if (_videoEventService.hasEvents) {
          await _addEventsToVideoManager(_videoEventService.videoEvents);
          Log.debug('⚡ Fast initial videos loaded in ${waitAttempts * 50}ms', name: 'VideoEventBridge', category: LogCategory.video);
        } else {
          Log.debug('� Videos will stream in as they arrive from relay', name: 'VideoEventBridge', category: LogCategory.video);
        }
      }
      
      // Listen for new events
      _videoEventService.addListener(_onVideoEventServiceChanged);
      
      Log.info('VideoEventBridge initialized with ${_videoManager.videos.length} videos', name: 'VideoEventBridge', category: LogCategory.video);
    } catch (e) {
      if (e.toString().contains('Nostr service not initialized') && _initRetryCount < 3) {
        _initRetryCount++;
        Log.warning('⏳ Nostr service not ready yet, waiting before retry ($_initRetryCount/3)...', name: 'VideoEventBridge', category: LogCategory.video);
        // Retry after a short delay to allow Nostr service to initialize
        await Future.delayed(const Duration(milliseconds: 500));
        return initialize(); // Recursive retry with limit
      } else {
        Log.error('VideoEventBridge initialization failed: $e', name: 'VideoEventBridge', category: LogCategory.video);
        rethrow;
      }
    }
  }
  
  /// Handle changes from video event service
  void _onVideoEventServiceChanged() {
    if (_videoEventService.hasEvents) {
      final currentVideoCount = _videoManager.videos.length;
      
      if (currentVideoCount == 0) {
        // FIRST VIDEO - highest priority, immediate sync
        Log.debug('FIRST VIDEO ARRIVING - immediate sync for fastest display!', name: 'VideoEventBridge', category: LogCategory.video);
        _addEventsToVideoManager(_videoEventService.videoEvents);
      } else {
        // Subsequent videos - async to not block UI
        Log.debug('Additional videos - async sync', name: 'VideoEventBridge', category: LogCategory.video);
        _addEventsToVideoManagerAsync(_videoEventService.videoEvents);
      }
      
      // Check if we should trigger discovery feed after following content arrives
      _checkAndLoadDiscoveryFeed();
    }
  }
  
  /// Add events to VideoManager (sync version for initialization)
  Future<void> _addEventsToVideoManager(List<VideoEvent> events) async {
    final existingIds = _videoManager.videos.map((v) => v.id).toSet();
    // Also check our own processed events to prevent double processing
    final newEvents = events.where((event) => 
      !existingIds.contains(event.id) && !_processedEventIds.contains(event.id)
    ).toList();
    
    if (newEvents.isEmpty) {
      Log.debug('No new events to add (${events.length} events already processed)', name: 'VideoEventBridge', category: LogCategory.video);
      return;
    }
    
    Log.debug('Adding ${newEvents.length} new events to VideoManager (${events.length} total provided, ${events.length - newEvents.length} already processed)', name: 'VideoEventBridge', category: LogCategory.video);
    
    // Track unique pubkeys for batch profile fetching
    final newPubkeys = <String>{};
    
    for (final event in newEvents) {
      try {
        await _videoManager.addVideoEvent(event);
        _processedEventIds.add(event.id);
        
        // Collect unique pubkeys for profile fetching
        if (!_userProfileService.hasProfile(event.pubkey)) {
          newPubkeys.add(event.pubkey);
        }
      } catch (e) {
        Log.error('Failed to add video ${event.id}: $e', name: 'VideoEventBridge', category: LogCategory.video);
      }
    }
    
    // Batch fetch profiles for unique pubkeys only
    if (newPubkeys.isNotEmpty) {
      Log.verbose('Fetching profiles for ${newPubkeys.length} unique users', name: 'VideoEventBridge', category: LogCategory.video);
      
      if (existingIds.isEmpty) {
        // First batch - fetch immediately for fast display
        for (final pubkey in newPubkeys.take(3)) {
          _userProfileService.fetchProfile(pubkey);
        }
        // Fetch remaining async
        for (final pubkey in newPubkeys.skip(3)) {
          Future.microtask(() => _userProfileService.fetchProfile(pubkey));
        }
      } else {
        // Subsequent batches - all async to not block UI
        for (final pubkey in newPubkeys) {
          Future.microtask(() => _userProfileService.fetchProfile(pubkey));
        }
      }
    }
    
    // Start preloading IMMEDIATELY if this was the first batch
    if (_videoManager.videos.isNotEmpty && existingIds.isEmpty) {
      Log.debug('FIRST VIDEOS LOADED - immediate preload for fastest display!', name: 'VideoEventBridge', category: LogCategory.video);
      // NO DELAY! Start preloading immediately for fastest first video display
      _videoManager.preloadAroundIndex(0);
      
      // Also immediately preload the next video for smooth scrolling
      if (_videoManager.videos.length > 1) {
        Future.microtask(() => _videoManager.preloadVideo(_videoManager.videos[1].id));
      }
    }
  }
  
  /// Add events to VideoManager (async version for updates)
  void _addEventsToVideoManagerAsync(List<VideoEvent> events) {
    Future.microtask(() async {
      await _addEventsToVideoManager(events);
    });
  }
  
  /// Load more historical events - tries regular historical loading first, then unlimited
  Future<void> loadMoreEvents() async {
    final eventCountBefore = _videoEventService.eventCount;
    
    try {
      // First try regular historical loading
      await _videoEventService.loadMoreEvents();
      
      final eventCountAfter = _videoEventService.eventCount;
      final newEventsLoaded = eventCountAfter - eventCountBefore;
      
      Log.debug('Regular load more: $newEventsLoaded new events loaded', name: 'VideoEventBridge', category: LogCategory.video);
      
      // If we got very few new events (less than 10), try unlimited loading
      // This suggests we might be hitting the end of chronological content
      if (newEventsLoaded < 10) {
        Log.info('� Few new events found, trying unlimited content loading...', name: 'VideoEventBridge', category: LogCategory.video);
        await _videoEventService.loadMoreContentUnlimited();
        
        final finalEventCount = _videoEventService.eventCount;
        final totalNewEvents = finalEventCount - eventCountBefore;
        Log.debug('Total events loaded: $totalNewEvents', name: 'VideoEventBridge', category: LogCategory.video);
      }
      
    } catch (e) {
      Log.error('Failed to load more events: $e', name: 'VideoEventBridge', category: LogCategory.video);
      // If regular loading fails, try unlimited as fallback
      Log.debug('Falling back to unlimited content loading...', name: 'VideoEventBridge', category: LogCategory.video);
      await _videoEventService.loadMoreContentUnlimited();
    }
  }
  
  /// Refresh the feed
  Future<void> refreshFeed() async {
    await _videoEventService.refreshVideoFeed();
  }
  
  /// Set up listener to trigger discovery feed once following content arrives
  void _setupFollowingListener(Set<String> followingPubkeys) {
    _followingPubkeys = followingPubkeys;
    // The existing _onVideoEventServiceChanged will handle this
  }
  
  /// Check if we should load discovery feed after following content arrives
  void _checkAndLoadDiscoveryFeed() {
    if (_discoveryFeedLoaded || _followingPubkeys.isEmpty) return;
    
    // Count videos from people you follow
    final followingVideosCount = _videoEventService.videoEvents
        .where((event) => _followingPubkeys.contains(event.pubkey))
        .length;
    
    // Trigger discovery feed once we have some following content (threshold: 5+)
    if (followingVideosCount >= 5) {
      _discoveryFeedLoaded = true;
      Log.debug('� Following content milestone reached: $followingVideosCount videos - loading discovery feed', name: 'VideoEventBridge', category: LogCategory.video);
      _loadDiscoveryFeed();
    }
  }
  
  /// Load the discovery feed after following content is established
  Future<void> _loadDiscoveryFeed() async {
    try {
      // Load discovery content from everyone else
      Log.debug('� Loading discovery feed (general content) AFTER following content', name: 'VideoEventBridge', category: LogCategory.video);
      await _videoEventService.subscribeToVideoFeed(
        limit: 300, // Get plenty of discovery content
        replace: false, // Keep following content AND add discovery
      );
      
      // Classic vines are already included in following list above, no need to add editor picks separately
    } catch (e) {
      Log.error('Failed to load discovery feed: $e', name: 'VideoEventBridge', category: LogCategory.video);
    }
  }

  /// Dispose resources
  void dispose() {
    _videoEventService.removeListener(_onVideoEventServiceChanged);
    _eventSubscription?.cancel();
  }
}