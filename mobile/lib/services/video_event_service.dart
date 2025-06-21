// ABOUTME: Service for subscribing to and managing NIP-71 kind 22 video events
// ABOUTME: Handles real-time feed updates and local caching of video content

import 'dart:async';
import 'package:nostr/nostr.dart';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';
import 'seen_videos_service.dart';

/// Service for handling NIP-71 kind 22 video events
class VideoEventService extends ChangeNotifier {
  final INostrService _nostrService;
  final SeenVideosService? _seenVideosService;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  final List<VideoEvent> _videoEvents = [];
  final Map<String, StreamSubscription> _subscriptions = {};
  bool _isSubscribed = false;
  bool _isLoading = false;
  String? _error;
  Timer? _retryTimer;
  int _retryAttempts = 0;
  
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 10);
  
  VideoEventService(this._nostrService, {SeenVideosService? seenVideosService}) 
    : _seenVideosService = seenVideosService;
  
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
    int limit = 500, // Increased limit for more diverse content
    bool replace = true, // Whether to replace existing subscription
  }) async {
    // Prevent concurrent subscription attempts
    if (_isLoading) {
      debugPrint('🎥 Subscription request ignored, another is already in progress.');
      return;
    }
    
    // Prevent duplicate subscriptions if already subscribed and no parameters changed
    if (_isSubscribed && authors == null && hashtags == null && since == null && until == null) {
      debugPrint('🎥 Subscription request ignored, already subscribed with same parameters.');
      return;
    }
    
    // Set loading state immediately to prevent race conditions
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    debugPrint('🎥 Starting video event subscription...');
    debugPrint('📊 Current state: subscribed=$_isSubscribed, loading=$_isLoading, events=${_videoEvents.length}');
    
    if (!_nostrService.isInitialized) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Cannot subscribe - Nostr service not initialized');
      throw VideoEventServiceException('Nostr service not initialized');
    }
    
    // Check connection status
    if (!_connectionService.isOnline) {
      _isLoading = false;
      notifyListeners();
      debugPrint('⚠️ Device is offline, will retry when connection is restored');
      _scheduleRetryWhenOnline();
      throw VideoEventServiceException('Device is offline');
    }
    
    debugPrint('🔍 Nostr service status for video subscription:');
    debugPrint('  - Connected relays: ${_nostrService.connectedRelayCount}');
    debugPrint('  - Relay list: ${_nostrService.connectedRelays}');
    
    if (_nostrService.connectedRelayCount == 0) {
      debugPrint('⚠️ WARNING: No relays connected - subscription will likely fail');
    }
    
    // Always close existing subscriptions to prevent leaks
    if (_subscriptions.isNotEmpty) {
      debugPrint('🔄 Closing ${_subscriptions.length} existing subscriptions before creating new one...');
      await unsubscribeFromVideoFeed();
    }
    
    try {
      debugPrint('🔍 Creating filter for kind 22 video events...');
      debugPrint('  - Authors: ${authors?.length ?? 'all'}');
      debugPrint('  - Hashtags: ${hashtags?.join(', ') ?? 'none'}');
      debugPrint('  - Since: ${since != null ? DateTime.fromMillisecondsSinceEpoch(since * 1000) : 'none'}');
      debugPrint('  - Until: ${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}');
      debugPrint('  - Limit: $limit');
      debugPrint('  - Replace existing: $replace');
      
      // Create filter for kind 22 events
      // If no time bounds specified, get recent historical content
      int? effectiveSince = since;
      if (since == null && until == null && _videoEvents.isEmpty) {
        // For initial load, get events from the last 30 days to have good content variety
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        effectiveSince = thirtyDaysAgo.millisecondsSinceEpoch ~/ 1000;
        debugPrint('📅 Initial load: fetching events from last 30 days (since: $thirtyDaysAgo)');
      }
      
      final filter = Filter(
        kinds: [22], // NIP-71 short video events
        authors: authors,
        since: effectiveSince,
        until: until,
        limit: limit,
      );
      
      // Log the exact filter being sent to debug timestamp issues
      debugPrint('🔍 Filter details:');
      debugPrint('  - JSON: ${filter.toJson()}');
      debugPrint('  - Since timestamp: $effectiveSince (${effectiveSince != null ? DateTime.fromMillisecondsSinceEpoch(effectiveSince * 1000) : 'null'})');
      
      // Subscribe to events using Nostr service
      debugPrint('📡 Requesting event subscription from Nostr service...');
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      debugPrint('📡 Event stream created, setting up listeners...');
      
      // Use a unique subscription key to avoid conflicts
      final subscriptionKey = 'video_feed_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('🔑 Creating subscription with key: $subscriptionKey');
      
      final subscription = eventStream.listen(
        (event) => _handleNewVideoEvent(event),
        onError: (error) => _handleSubscriptionError(error),
        onDone: () => _handleSubscriptionComplete(),
      );
      
      _subscriptions[subscriptionKey] = subscription;
      _isSubscribed = true;
      
      debugPrint('📋 Active subscriptions after creation: ${_subscriptions.keys.toList()}');
      
      debugPrint('✅ Video event subscription established successfully!');
      debugPrint('📊 Subscription status: active=${_subscriptions.length} subscriptions');
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Failed to subscribe to video events: $e');
      
      // Check if it's a connection-related error
      if (_isConnectionError(e)) {
        debugPrint('🌐 Connection error detected, will retry when online');
        _scheduleRetryWhenOnline();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Handle new video event from subscription
  void _handleNewVideoEvent(Event event) {
    try {
      debugPrint('📥 Received event: kind=${event.kind}, id=${event.id.substring(0, 8)}..., created=${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}');
      
      if (event.kind != 22) {
        debugPrint('⏩ Skipping non-video event (kind ${event.kind})');
        return;
      }
      
      // Check if we already have this event
      if (_videoEvents.any((e) => e.id == event.id)) {
        debugPrint('⏩ Skipping duplicate event ${event.id.substring(0, 8)}...');
        return;
      }
      
      // Check if user has already seen this video
      if (_seenVideosService?.hasSeenVideo(event.id) == true) {
        debugPrint('👁️ Skipping seen video ${event.id.substring(0, 8)}...');
        return;
      }
      
      // TEMPORARILY DISABLED: CLIENT-SIDE FILTERING to debug feed issue
      // TODO: Re-enable after fixing the feed stopping issue
      // final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      // final eventTime = DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000);
      // 
      // if (eventTime.isBefore(sevenDaysAgo)) {
      //   debugPrint('⏰ FILTERING OUT OLD EVENT: ${event.id.substring(0, 8)} from $eventTime (older than 7 days)');
      //   return; // Return early without notifying listeners to prevent rebuild loops
      // }
      
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
    
    // Check if it's a connection error and schedule retry
    if (_isConnectionError(error)) {
      debugPrint('🌐 Subscription connection error, scheduling retry...');
      _scheduleRetryWhenOnline();
    }
    
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
  
  /// Refresh video feed by fetching recent events with expanded timeframe
  Future<void> refreshVideoFeed() async {
    debugPrint('🔄 Refresh requested - restarting subscription with expanded timeframe');
    
    // Close existing subscriptions and create new ones with expanded timeframe
    await unsubscribeFromVideoFeed();
    
    debugPrint('📡 Creating new subscription with expanded timeframe...');
    return subscribeToVideoFeed();
  }
  
  /// Load more historical events using one-shot query (not persistent subscription)
  Future<void> loadMoreEvents({int limit = 200}) async {
    if (_videoEvents.isEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint('📚 Loading more historical events...');
      // Get events older than the oldest event we have
      final oldestEvent = _videoEvents.last;
      final until = oldestEvent.createdAt - 1; // One second before oldest event
      
      debugPrint('📚 Requesting events older than ${DateTime.fromMillisecondsSinceEpoch(until * 1000)}');
      
      // Use one-shot historical query - this will complete when EOSE is received
      await _queryHistoricalEvents(until: until, limit: limit);
      
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Failed to load more events: $e');
      
      if (_isConnectionError(e)) {
        debugPrint('🌐 Load more failed due to connection error');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// One-shot query for historical events (completes when EOSE received)
  Future<void> _queryHistoricalEvents({int? until, int limit = 200}) async {
    if (!_nostrService.isInitialized) {
      throw VideoEventServiceException('Nostr service not initialized');
    }
    
    final completer = Completer<void>();
    final filter = Filter(
      kinds: [22],
      until: until,
      limit: limit,
    );
    
    debugPrint('🔍 One-shot historical query: until=${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}, limit=$limit');
    
    final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
    late StreamSubscription subscription;
    
    subscription = eventStream.listen(
      (event) {
        _handleNewVideoEvent(event);
      },
      onError: (error) {
        debugPrint('❌ Historical query error: $error');
        if (!completer.isCompleted) completer.completeError(error);
      },
      onDone: () {
        debugPrint('✅ Historical query completed (EOSE received)');
        subscription.cancel();
        if (!completer.isCompleted) completer.complete();
      },
    );
    
    // Set timeout for the query
    Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        debugPrint('⏰ Historical query timed out after 30 seconds');
        subscription.cancel();
        completer.complete();
      }
    });
    
    return completer.future;
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
      debugPrint('🔔 Unsubscribing from ${_subscriptions.length} video event subscriptions...');
      debugPrint('📋 Subscription keys being cancelled: ${_subscriptions.keys.toList()}');
      
      for (final entry in _subscriptions.entries) {
        debugPrint('🗑️ Cancelling subscription: ${entry.key}');
        await entry.value.cancel();
      }
      _subscriptions.clear();
      _isSubscribed = false;
      
      debugPrint('✅ Successfully unsubscribed from all video events');
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
  
  /// Check if an error is connection-related
  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection') ||
           errorString.contains('network') ||
           errorString.contains('socket') ||
           errorString.contains('timeout') ||
           errorString.contains('offline') ||
           errorString.contains('unreachable');
  }
  
  /// Schedule retry when device comes back online
  void _scheduleRetryWhenOnline() {
    _retryTimer?.cancel();
    
    _retryTimer = Timer.periodic(_retryDelay, (timer) {
      if (_connectionService.isOnline && _retryAttempts < _maxRetryAttempts) {
        _retryAttempts++;
        debugPrint('🔄 Attempting to resubscribe to video feed (attempt $_retryAttempts/$_maxRetryAttempts)');
        
        subscribeToVideoFeed().then((_) {
          // Success - cancel retry timer
          timer.cancel();
          _retryAttempts = 0;
          debugPrint('✅ Successfully resubscribed to video feed');
        }).catchError((e) {
          debugPrint('❌ Retry attempt $_retryAttempts failed: $e');
          
          if (_retryAttempts >= _maxRetryAttempts) {
            timer.cancel();
            debugPrint('⚠️ Max retry attempts reached for video feed subscription');
          }
        });
      } else if (!_connectionService.isOnline) {
        debugPrint('⏳ Still offline, waiting for connection...');
      } else {
        // Max retries reached
        timer.cancel();
      }
    });
  }
  
  /// Get connection status for debugging
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isSubscribed': _isSubscribed,
      'isLoading': _isLoading,
      'eventCount': _videoEvents.length,
      'retryAttempts': _retryAttempts,
      'hasError': _error != null,
      'lastError': _error,
      'connectionInfo': _connectionService.getConnectionInfo(),
    };
  }
  
  /// Force retry subscription
  Future<void> retrySubscription() async {
    debugPrint('🔄 Forcing retry of video feed subscription...');
    _retryAttempts = 0;
    _error = null;
    
    try {
      await subscribeToVideoFeed();
    } catch (e) {
      debugPrint('❌ Manual retry failed: $e');
      rethrow;
    }
  }
  
  @override
  void dispose() {
    _retryTimer?.cancel();
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