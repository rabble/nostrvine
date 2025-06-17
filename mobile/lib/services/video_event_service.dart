// ABOUTME: Service for subscribing to and managing NIP-71 kind 22 video events
// ABOUTME: Handles real-time feed updates and local caching of video content

import 'dart:async';
import 'package:nostr/nostr.dart';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import 'nostr_service_interface.dart';

/// Service for handling NIP-71 kind 22 video events
class VideoEventService extends ChangeNotifier {
  final INostrService _nostrService;
  final List<VideoEvent> _videoEvents = [];
  final Map<String, StreamSubscription> _subscriptions = {};
  bool _isSubscribed = false;
  bool _isLoading = false;
  String? _error;
  
  VideoEventService(this._nostrService);
  
  // Getters
  List<VideoEvent> get videoEvents => List.unmodifiable(_videoEvents);
  bool get isSubscribed => _isSubscribed;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasEvents => _videoEvents.isNotEmpty;
  int get eventCount => _videoEvents.length;
  
  /// Subscribe to kind 22 video events from all connected relays
  Future<void> subscribeToVideoFeed({
    List<String>? authors,
    List<String>? hashtags,
    int? since,
    int? until,
    int limit = 100,
  }) async {
    debugPrint('🎥 Starting video event subscription...');
    debugPrint('📊 Current state: subscribed=$_isSubscribed, loading=$_isLoading, events=${_videoEvents.length}');
    
    if (!_nostrService.isInitialized) {
      debugPrint('❌ Cannot subscribe - Nostr service not initialized');
      throw VideoEventServiceException('Nostr service not initialized');
    }
    
    debugPrint('🔍 Nostr service status for video subscription:');
    debugPrint('  - Connected relays: ${_nostrService.connectedRelayCount}');
    debugPrint('  - Relay list: ${_nostrService.connectedRelays}');
    
    if (_nostrService.connectedRelayCount == 0) {
      debugPrint('⚠️ WARNING: No relays connected - subscription will likely fail');
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      debugPrint('🔍 Creating filter for kind 22 video events...');
      debugPrint('  - Authors: ${authors?.length ?? 'all'}');
      debugPrint('  - Hashtags: ${hashtags?.join(', ') ?? 'none'}');
      debugPrint('  - Limit: $limit');
      // Create filter for kind 22 events
      final filter = Filter(
        kinds: [22], // NIP-71 short video events
        authors: authors,
        since: since,
        until: until,
        limit: limit,
      );
      
      // Subscribe to events using Nostr service
      debugPrint('📡 Requesting event subscription from Nostr service...');
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      debugPrint('📡 Event stream created, setting up listeners...');
      
      final subscription = eventStream.listen(
        (event) => _handleNewVideoEvent(event),
        onError: (error) => _handleSubscriptionError(error),
        onDone: () => _handleSubscriptionComplete(),
      );
      
      _subscriptions['video_feed'] = subscription;
      _isSubscribed = true;
      
      debugPrint('✅ Video event subscription established successfully!');
      debugPrint('📊 Subscription status: active=${_subscriptions.length} subscriptions');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Failed to subscribe to video events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Handle new video event from subscription
  void _handleNewVideoEvent(Event event) {
    try {
      debugPrint('📥 Received event: kind=${event.kind}, id=${event.id.substring(0, 8)}...');
      
      if (event.kind != 22) {
        debugPrint('⏩ Skipping non-video event (kind ${event.kind})');
        return;
      }
      
      // Check if we already have this event
      if (_videoEvents.any((e) => e.id == event.id)) {
        debugPrint('⏩ Skipping duplicate event ${event.id.substring(0, 8)}...');
        return;
      }
      
      debugPrint('🎬 Processing new video event ${event.id.substring(0, 8)}...');
      final videoEvent = VideoEvent.fromNostrEvent(event);
      
      // Only add events with video URLs
      if (videoEvent.hasVideo) {
        _videoEvents.insert(0, videoEvent); // Add to beginning for chronological order
        
        // Keep only the most recent events to prevent memory issues
        if (_videoEvents.length > 500) {
          _videoEvents.removeRange(500, _videoEvents.length);
        }
        
        debugPrint('✅ Added video event! Total: ${_videoEvents.length} events');
        notifyListeners();
      } else {
        debugPrint('⏩ Skipping video event without video URL');
      }
    } catch (e) {
      debugPrint('⚠️ Error processing video event: $e');
    }
  }
  
  /// Handle subscription error
  void _handleSubscriptionError(dynamic error) {
    _error = error.toString();
    debugPrint('❌ Video subscription error: $error');
    debugPrint('📊 Current state: events=${_videoEvents.length}, subscriptions=${_subscriptions.length}');
    notifyListeners();
  }
  
  /// Handle subscription completion
  void _handleSubscriptionComplete() {
    debugPrint('🏁 Video subscription completed');
    debugPrint('📊 Final state: events=${_videoEvents.length}, subscriptions=${_subscriptions.length}');
  }
  
  /// Subscribe to specific user's video events
  Future<void> subscribeToUserVideos(String pubkey, {int limit = 50}) async {
    return subscribeToVideoFeed(
      authors: [pubkey],
      limit: limit,
    );
  }
  
  /// Subscribe to videos with specific hashtags
  Future<void> subscribeToHashtagVideos(List<String> hashtags, {int limit = 100}) async {
    return subscribeToVideoFeed(
      hashtags: hashtags,
      limit: limit,
    );
  }
  
  /// Refresh video feed by fetching recent events
  Future<void> refreshVideoFeed() async {
    if (!_isSubscribed) {
      return subscribeToVideoFeed();
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Get events from the last hour
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final since = oneHourAgo.millisecondsSinceEpoch ~/ 1000;
      
      await subscribeToVideoFeed(
        since: since,
        limit: 50,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Failed to refresh video feed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Load more historical events
  Future<void> loadMoreEvents({int limit = 50}) async {
    if (_videoEvents.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Get events older than the oldest event we have
      final oldestEvent = _videoEvents.last;
      final until = oldestEvent.createdAt - 1; // One second before oldest event
      
      await subscribeToVideoFeed(
        until: until,
        limit: limit,
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Failed to load more events: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Get video event by ID
  VideoEvent? getVideoEventById(String eventId) {
    try {
      return _videoEvents.firstWhere((event) => event.id == eventId);
    } catch (e) {
      return null;
    }
  }
  
  /// Get video events by author
  List<VideoEvent> getVideoEventsByAuthor(String pubkey) {
    return _videoEvents.where((event) => event.pubkey == pubkey).toList();
  }
  
  /// Get video events with specific hashtags
  List<VideoEvent> getVideoEventsByHashtags(List<String> hashtags) {
    return _videoEvents.where((event) {
      return hashtags.any((tag) => event.hashtags.contains(tag));
    }).toList();
  }
  
  /// Clear all video events
  void clearVideoEvents() {
    _videoEvents.clear();
    notifyListeners();
  }
  
  /// Unsubscribe from all video event subscriptions
  Future<void> unsubscribeFromVideoFeed() async {
    try {
      for (final subscription in _subscriptions.values) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      _isSubscribed = false;
      
      debugPrint('🔔 Unsubscribed from video events');
    } catch (e) {
      debugPrint('⚠️ Error unsubscribing from video events: $e');
    }
    
    notifyListeners();
  }
  
  /// Get video events sorted by engagement (placeholder - would need reaction events)
  List<VideoEvent> getVideoEventsByEngagement() {
    // For now, just return chronologically sorted
    // In a full implementation, would sort by likes, comments, shares, etc.
    return List.from(_videoEvents)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
  
  /// Get video events from last N hours
  List<VideoEvent> getRecentVideoEvents({int hours = 24}) {
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    return _videoEvents.where((event) => event.timestamp.isAfter(cutoff)).toList();
  }
  
  /// Get unique authors from video events
  Set<String> getUniqueAuthors() {
    return _videoEvents.map((event) => event.pubkey).toSet();
  }
  
  /// Get all hashtags from video events
  Set<String> getAllHashtags() {
    final allTags = <String>{};
    for (final event in _videoEvents) {
      allTags.addAll(event.hashtags);
    }
    return allTags;
  }
  
  /// Get video events count by author
  Map<String, int> getVideoCountByAuthor() {
    final counts = <String, int>{};
    for (final event in _videoEvents) {
      counts[event.pubkey] = (counts[event.pubkey] ?? 0) + 1;
    }
    return counts;
  }
  
  @override
  void dispose() {
    unsubscribeFromVideoFeed();
    super.dispose();
  }
}

/// Exception thrown by video event service operations
class VideoEventServiceException implements Exception {
  final String message;
  
  const VideoEventServiceException(this.message);
  
  @override
  String toString() => 'VideoEventServiceException: $message';
}