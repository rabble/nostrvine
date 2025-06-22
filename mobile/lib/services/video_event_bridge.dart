// ABOUTME: Simple bridge service to connect VideoEventService to VideoManager
// ABOUTME: Replaces the complex VideoFeedProvider with minimal bridging logic

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import 'video_event_service.dart';
import 'video_manager_interface.dart';
import 'user_profile_service.dart';

/// Minimal bridge to feed Nostr video events into VideoManager
/// 
/// This replaces the complex VideoFeedProvider with a simple service
/// that just connects VideoEventService (Nostr events) to VideoManager (UI state).
class VideoEventBridge {
  final VideoEventService _videoEventService;
  final IVideoManager _videoManager;
  final UserProfileService _userProfileService;
  int _initRetryCount = 0;
  
  StreamSubscription? _eventSubscription;
  final Set<String> _processedEventIds = {};
  
  VideoEventBridge({
    required VideoEventService videoEventService,
    required IVideoManager videoManager,
    required UserProfileService userProfileService,
  }) : _videoEventService = videoEventService,
       _videoManager = videoManager,
       _userProfileService = userProfileService;
  
  /// Initialize the bridge and start syncing events
  Future<void> initialize() async {
    debugPrint('🌉 Initializing VideoEventBridge...');
    
    try {
      // Subscribe to video events first
      await _videoEventService.subscribeToVideoFeed();
      
      // Add initial events to VideoManager
      if (_videoEventService.hasEvents) {
        await _addEventsToVideoManager(_videoEventService.videoEvents);
      }
      
      // Listen for new events
      _videoEventService.addListener(_onVideoEventServiceChanged);
      
      debugPrint('✅ VideoEventBridge initialized');
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
      _videoManager.preloadAroundIndex(0);
    }
  }
  
  /// Add events to VideoManager (async version for updates)
  void _addEventsToVideoManagerAsync(List<VideoEvent> events) {
    Future.microtask(() async {
      await _addEventsToVideoManager(events);
    });
  }
  
  /// Load more historical events
  Future<void> loadMoreEvents() async {
    await _videoEventService.loadMoreEvents();
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