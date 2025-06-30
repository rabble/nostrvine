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
  Timer? _discoveryFallbackTimer;
  
  // Profile fetching deduplication
  final Set<String> _requestedProfiles = {};
  
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
      
      // Debug: Log the actual pubkeys being used
      Log.debug('Following pubkeys from social service: ${followingPubkeys.toList()}', name: 'VideoEventBridge', category: LogCategory.video);
      Log.debug('Using ${priorityPubkeys.length} accounts for following feed${followingPubkeys.isEmpty ? " (classic vines fallback)" : ""}', name: 'VideoEventBridge', category: LogCategory.video);
      Log.debug('Priority pubkeys: ${priorityPubkeys.toList()}', name: 'VideoEventBridge', category: LogCategory.video);
      
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
          limit: 500, // Increased limit to ensure we get all classic vines content (125+ videos)
          replace: true, // Start fresh with following content
        );
        
        // Set up listener to trigger discovery feed once we get following content
        _setupFollowingListener(priorityPubkeys);
        
        // Set up fallback timer to load discovery if no content arrives within 3 seconds
        final isUsingClassicVinesFallback = priorityPubkeys.contains(AppConstants.classicVinesPubkey) && 
                                           priorityPubkeys.length == 1;
        if (isUsingClassicVinesFallback) {
          Log.debug('Setting up discovery fallback timer for classic vines account', name: 'VideoEventBridge', category: LogCategory.video);
          _discoveryFallbackTimer = Timer(const Duration(seconds: 1), () {
            if (!_discoveryFeedLoaded && _videoManager.videos.isEmpty) {
              Log.debug('� Fallback timer triggered - discovery feed disabled, staying with curated content only', name: 'VideoEventBridge', category: LogCategory.video);
              _discoveryFeedLoaded = true;
              // _loadDiscoveryFeed(); // Discovery disabled
            }
          });
        }
      } else {
        // No follows, just load discovery feed
        Log.debug('� No following list, loading discovery feed directly', name: 'VideoEventBridge', category: LogCategory.video);
        // await _loadDiscoveryFeed(); // Discovery disabled
      }
      
      // Additional safety net: if no videos after 2 seconds, force load discovery
      Timer(const Duration(seconds: 2), () {
        if (!_discoveryFeedLoaded && _videoManager.videos.isEmpty) {
          Log.debug('🚨 Emergency fallback - discovery feed disabled, staying with curated content only', name: 'VideoEventBridge', category: LogCategory.video);
          _discoveryFeedLoaded = true;
          // _loadDiscoveryFeed(); // Discovery disabled
        }
      });
      
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
      
      // Cancel fallback timer if we get any content
      if (_discoveryFallbackTimer?.isActive == true) {
        Log.debug('Canceling discovery fallback timer - got video content', name: 'VideoEventBridge', category: LogCategory.video);
        _discoveryFallbackTimer?.cancel();
        _discoveryFallbackTimer = null;
      }
      
      if (currentVideoCount == 0) {
        // FIRST VIDEO - highest priority, immediate sync
        Log.debug('FIRST VIDEO ARRIVING - immediate sync for fastest display!', name: 'VideoEventBridge', category: LogCategory.video);
        _addEventsToVideoManager(_videoEventService.videoEvents);
      } else {
        // Subsequent videos - async to not block UI
        Log.verbose('Additional videos - async sync', name: 'VideoEventBridge', category: LogCategory.video);
        _addEventsToVideoManagerAsync(_videoEventService.videoEvents);
      }
      
      // Discovery feed disabled - skip discovery loading
      // _checkAndLoadDiscoveryFeed(); // Discovery disabled
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
    
    Log.verbose('Adding ${newEvents.length} new events to VideoManager (${events.length} total provided, ${events.length - newEvents.length} already processed)', name: 'VideoEventBridge', category: LogCategory.video);
    
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
      // Additional deduplication to prevent race conditions
      final pubkeysToFetch = newPubkeys.where((pubkey) => 
        !_requestedProfiles.contains(pubkey)).toList();
      
      if (pubkeysToFetch.isNotEmpty) {
        Log.verbose('Fetching profiles for ${pubkeysToFetch.length} unique users (${newPubkeys.length - pubkeysToFetch.length} already requested)', name: 'VideoEventBridge', category: LogCategory.video);
        
        // Mark as requested to prevent race conditions
        _requestedProfiles.addAll(pubkeysToFetch);
        
        // Use batch fetching to reduce subscription overhead
        await _userProfileService.fetchMultipleProfiles(pubkeysToFetch);
        
        // Clean up requested set after a delay to allow retries for failed requests
        Future.delayed(const Duration(seconds: 30), () {
          _requestedProfiles.removeAll(pubkeysToFetch);
        });
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
    
    // Special case: if using classic vines fallback and got no content, load discovery immediately
    final isUsingClassicVinesFallback = _followingPubkeys.contains(AppConstants.classicVinesPubkey) && 
                                       _followingPubkeys.length == 1;
    
    if (isUsingClassicVinesFallback && followingVideosCount == 0) {
      _discoveryFeedLoaded = true;
      Log.debug('� Classic vines fallback has no content - loading discovery feed immediately', name: 'VideoEventBridge', category: LogCategory.video);
      _loadDiscoveryFeed();
      return;
    }
    
    // DON'T automatically load discovery content - wait for user to reach the end of primary videos
    Log.debug('Following content loaded: $followingVideosCount videos. Discovery feed will load when user reaches end of primary content.', name: 'VideoEventBridge', category: LogCategory.video);
  }
  
  /// Trigger discovery feed loading when user reaches end of primary videos
  /// DISABLED: Discovery feed removed - only show curated vines
  Future<void> triggerDiscoveryFeed() async {
    if (_discoveryFeedLoaded) return;
    
    _discoveryFeedLoaded = true;
    Log.debug('🚫 Discovery feed disabled - only showing curated content', name: 'VideoEventBridge', category: LogCategory.video);
    // Discovery feed loading intentionally disabled - only curated vines
    return;
  }

  /// Load the discovery feed after following content is established
  /// DISABLED: Discovery feed removed - only show curated vines
  Future<void> _loadDiscoveryFeed() async {
    try {
      // Load discovery content from everyone else
      Log.debug('� Loading discovery feed (general content) AFTER following content', name: 'VideoEventBridge', category: LogCategory.video);
      // Discovery feed loading intentionally disabled - only curated vines
      return;
      
      // Classic vines are already included in following list above, no need to add editor picks separately
    } catch (e) {
      Log.error('Failed to load discovery feed: $e', name: 'VideoEventBridge', category: LogCategory.video);
    }
  }

  /// Dispose resources
  void dispose() {
    _videoEventService.removeListener(_onVideoEventServiceChanged);
    _eventSubscription?.cancel();
    _discoveryFallbackTimer?.cancel();
  }
}