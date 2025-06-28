// ABOUTME: Simple bridge service to connect VideoEventService to VideoManager
// ABOUTME: Replaces the complex VideoFeedProvider with minimal bridging logic

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import 'video_event_service.dart';
import 'video_manager_interface.dart';
import 'user_profile_service.dart';
import 'social_service.dart';

/// Minimal bridge to feed Nostr video events into VideoManager
/// 
/// This replaces the complex VideoFeedProvider with a simple service
/// that just connects VideoEventService (Nostr events) to VideoManager (UI state).
class VideoEventBridge {
  final VideoEventService _videoEventService;
  final IVideoManager _videoManager;
  final UserProfileService _userProfileService;
  final SocialService? _socialService;
  int _initRetryCount = 0;
  
  StreamSubscription? _eventSubscription;
  final Set<String> _processedEventIds = {};
  
  VideoEventBridge({
    required VideoEventService videoEventService,
    required IVideoManager videoManager,
    required UserProfileService userProfileService,
    SocialService? socialService,
  }) : _videoEventService = videoEventService,
       _videoManager = videoManager,
       _userProfileService = userProfileService,
       _socialService = socialService;
  
  /// Initialize the bridge and start syncing events
  Future<void> initialize() async {
    debugPrint('🌉 Initializing VideoEventBridge...');
    
    try {
      // FIRST PRIORITY: Load classic vines from the special account
      const classicVinesPubkey = '25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856';
      debugPrint('🎬 Loading 95 classic vines FIRST from: $classicVinesPubkey');
      await _videoEventService.subscribeToVideoFeed(
        authors: [classicVinesPubkey],
        limit: 100, // Get all 95 classic vines
        replace: true, // Start fresh with classic vines
      );
      
      // Wait a moment to ensure classic vines are loaded first
      await Future.delayed(const Duration(milliseconds: 500));
      
      // THEN load the open feed - show ALL videos from the relay
      debugPrint('🌍 Loading open feed (ALL videos from relay) AFTER classic vines');
      await _videoEventService.subscribeToVideoFeed(
        limit: 300, // Get additional videos for discovery
        replace: false, // Keep classic vines AND add open feed
      );
      
      // Check if user is following anyone for additional personalized content
      final hasFollows = _socialService != null && _socialService!.followingPubkeys.isNotEmpty;
      
      if (hasFollows) {
        // User has follows - ADD their personalized content to the mix
        debugPrint('👥 User is following ${_socialService!.followingPubkeys.length} people - adding personalized content');
        await _videoEventService.subscribeToVideoFeed(
          authors: _socialService!.followingPubkeys,
          limit: 100, // Additional content from follows
          replace: false, // Keep everything AND add personalized content
        );
      }
      
      // Also add editor's picks to the mix (but don't let it dominate)
      const editorPubkey = '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082';
      debugPrint('🎯 Adding Editor\'s Picks to the mix from: $editorPubkey');
      await _videoEventService.subscribeToVideoFeed(
        authors: [editorPubkey],
        limit: 50, // Smaller amount so it doesn't dominate
        replace: false, // Keep everything else AND add editor's picks
      );
      
      // Add initial events to VideoManager IMMEDIATELY
      if (_videoEventService.hasEvents) {
        await _addEventsToVideoManager(_videoEventService.videoEvents);
        debugPrint('🚀 Initial videos loaded immediately');
      } else {
        // Don't wait! Start listening immediately and add videos as they arrive
        debugPrint('📡 No cached videos - will add videos as they stream in from relay');
        
        // Give just a tiny window for very fast responses
        int waitAttempts = 0;
        while (!_videoEventService.hasEvents && waitAttempts < 3) { // Reduced from 10 to 3
          await Future.delayed(const Duration(milliseconds: 50)); // Reduced from 100ms
          waitAttempts++;
        }
        
        // Add any videos that arrived quickly
        if (_videoEventService.hasEvents) {
          await _addEventsToVideoManager(_videoEventService.videoEvents);
          debugPrint('⚡ Fast initial videos loaded in ${waitAttempts * 50}ms');
        } else {
          debugPrint('🌊 Videos will stream in as they arrive from relay');
        }
      }
      
      // Listen for new events
      _videoEventService.addListener(_onVideoEventServiceChanged);
      
      debugPrint('✅ VideoEventBridge initialized with ${_videoManager.videos.length} videos');
    } catch (e) {
      if (e.toString().contains('Nostr service not initialized') && _initRetryCount < 3) {
        _initRetryCount++;
        debugPrint('⏳ Nostr service not ready yet, waiting before retry ($_initRetryCount/3)...');
        // Retry after a short delay to allow Nostr service to initialize
        await Future.delayed(const Duration(milliseconds: 500));
        return initialize(); // Recursive retry with limit
      } else {
        debugPrint('❌ VideoEventBridge initialization failed: $e');
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
        debugPrint('🚀 FIRST VIDEO ARRIVING - immediate sync for fastest display!');
        _addEventsToVideoManager(_videoEventService.videoEvents);
      } else {
        // Subsequent videos - async to not block UI
        debugPrint('📢 Additional videos - async sync');
        _addEventsToVideoManagerAsync(_videoEventService.videoEvents);
      }
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
      debugPrint('📋 No new events to add (${events.length} events already processed)');
      return;
    }
    
    debugPrint('📋 Adding ${newEvents.length} new events to VideoManager (${events.length} total provided, ${events.length - newEvents.length} already processed)');
    
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
        debugPrint('⚠️ Failed to add video ${event.id}: $e');
      }
    }
    
    // Batch fetch profiles for unique pubkeys only
    if (newPubkeys.isNotEmpty) {
      debugPrint('👤 Fetching profiles for ${newPubkeys.length} unique users');
      
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
      debugPrint('🚀 FIRST VIDEOS LOADED - immediate preload for fastest display!');
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
      
      debugPrint('📊 Regular load more: $newEventsLoaded new events loaded');
      
      // If we got very few new events (less than 10), try unlimited loading
      // This suggests we might be hitting the end of chronological content
      if (newEventsLoaded < 10) {
        debugPrint('🌊 Few new events found, trying unlimited content loading...');
        await _videoEventService.loadMoreContentUnlimited();
        
        final finalEventCount = _videoEventService.eventCount;
        final totalNewEvents = finalEventCount - eventCountBefore;
        debugPrint('📊 Total events loaded: $totalNewEvents');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to load more events: $e');
      // If regular loading fails, try unlimited as fallback
      debugPrint('🔄 Falling back to unlimited content loading...');
      await _videoEventService.loadMoreContentUnlimited();
    }
  }
  
  /// Refresh the feed
  Future<void> refreshFeed() async {
    await _videoEventService.refreshVideoFeed();
  }
  
  /// Dispose resources
  void dispose() {
    _videoEventService.removeListener(_onVideoEventServiceChanged);
    _eventSubscription?.cancel();
  }
}