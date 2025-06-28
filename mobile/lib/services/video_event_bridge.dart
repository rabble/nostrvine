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
      // Check if user is following anyone
      final hasFollows = _socialService != null && _socialService!.followingPubkeys.isNotEmpty;
      
      if (hasFollows) {
        // User has follows - load their personalized feed
        debugPrint('👥 User is following ${_socialService!.followingPubkeys.length} people - loading following feed');
        await _videoEventService.subscribeToVideoFeed(
          authors: _socialService!.followingPubkeys,
          limit: 200,
        );
      } else {
        // User has no follows - load general discovery feed
        debugPrint('🌍 User has no follows - loading discovery feed with random sorting');
        await _videoEventService.subscribeToVideoFeed(
          limit: 300, // Get more videos for discovery
        );
        
        // Shuffle the videos for a random experience
        _videoEventService.shuffleForDiscovery();
      }
      
      // Also subscribe to editor's picks videos specifically
      const editorPubkey = '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082';
      debugPrint('🎯 Also subscribing to Editor\'s Picks videos from: $editorPubkey');
      
      // Create a separate subscription for the editor's videos
      await _videoEventService.subscribeToVideoFeed(
        authors: [editorPubkey],
        limit: 100, // Get more videos from the editor
        replace: false, // Don't replace the main subscription
      );
      
      // Add initial events to VideoManager
      if (_videoEventService.hasEvents) {
        await _addEventsToVideoManager(_videoEventService.videoEvents);
      } else {
        // For new users, wait a bit for default content to be added
        debugPrint('⏳ No initial videos found, waiting for default content...');
        
        // Give VideoEventService time to add default content
        int waitAttempts = 0;
        while (!_videoEventService.hasEvents && waitAttempts < 10) {
          await Future.delayed(const Duration(milliseconds: 100));
          waitAttempts++;
        }
        
        // Add any videos that arrived
        if (_videoEventService.hasEvents) {
          debugPrint('✅ Default content arrived after ${waitAttempts * 100}ms');
          await _addEventsToVideoManager(_videoEventService.videoEvents);
        } else {
          debugPrint('⚠️ No videos available after waiting 1 second');
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
      debugPrint('📢 VideoEventService changed - syncing to VideoManager...');
      _addEventsToVideoManagerAsync(_videoEventService.videoEvents);
    }
  }
  
  /// Add events to VideoManager (sync version for initialization)
  Future<void> _addEventsToVideoManager(List<VideoEvent> events) async {
    final existingIds = _videoManager.videos.map((v) => v.id).toSet();
    final newEvents = events.where((event) => !existingIds.contains(event.id)).toList();
    
    debugPrint('📋 Adding ${newEvents.length} new events to VideoManager');
    
    for (final event in newEvents) {
      try {
        await _videoManager.addVideoEvent(event);
        _processedEventIds.add(event.id);
        
        // Fetch profile if needed
        if (!_userProfileService.hasProfile(event.pubkey)) {
          _userProfileService.fetchProfile(event.pubkey);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to add video ${event.id}: $e');
      }
    }
    
    // Start preloading if this was the first batch
    if (_videoManager.videos.isNotEmpty && existingIds.isEmpty) {
      debugPrint('⚡ First videos loaded - starting preload');
      // Add a small delay to ensure video manager is fully ready
      await Future.delayed(const Duration(milliseconds: 100));
      _videoManager.preloadAroundIndex(0);
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