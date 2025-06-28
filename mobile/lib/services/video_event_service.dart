// ABOUTME: Service for subscribing to and managing NIP-71 kind 22 video events
// ABOUTME: Handles real-time feed updates and local caching of video content

import 'dart:async';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';
import 'seen_videos_service.dart';
import 'default_content_service.dart';
import 'content_blocklist_service.dart';
import 'subscription_manager.dart';

/// Service for handling NIP-71 kind 22 video events
class VideoEventService extends ChangeNotifier {
  final INostrService _nostrService;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  final List<VideoEvent> _videoEvents = [];
  final Map<String, StreamSubscription> _subscriptions = {}; // Direct subscriptions fallback
  final List<String> _activeSubscriptionIds = []; // Managed subscription IDs
  bool _isSubscribed = false;
  bool _isLoading = false;
  String? _error;
  Timer? _retryTimer;
  int _retryAttempts = 0;
  List<String>? _activeHashtagFilter;
  String? _activeGroupFilter;
  
  // Duplicate event aggregation for logging
  int _duplicateVideoEventCount = 0;
  DateTime? _lastDuplicateVideoLogTime;
  
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 10);
  
  // Optional services for enhanced functionality
  ContentBlocklistService? _blocklistService;
  SubscriptionManager? _subscriptionManager;
  
  // Track if current subscription is for following list or general feed
  bool _isFollowingFeed = false;
  
  VideoEventService(
    this._nostrService, {
    SeenVideosService? seenVideosService,
    SubscriptionManager? subscriptionManager,
  }) : _subscriptionManager = subscriptionManager;
  
  /// Set the blocklist service for content filtering
  void setBlocklistService(ContentBlocklistService blocklistService) {
    _blocklistService = blocklistService;
    debugPrint('🚫 Blocklist service attached to VideoEventService');
  }
  
  /// Set the subscription manager for centralized subscription management
  void setSubscriptionManager(SubscriptionManager subscriptionManager) {
    _subscriptionManager = subscriptionManager;
    debugPrint('📡 SubscriptionManager attached to VideoEventService');
  }
  
  // Getters
  List<VideoEvent> get videoEvents => List.unmodifiable(_videoEvents);
  bool get isSubscribed => _isSubscribed;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasEvents => _videoEvents.isNotEmpty;
  int get eventCount => _videoEvents.length;
  
  /// Get videos by a specific author from the existing cache
  List<VideoEvent> getVideosByAuthor(String pubkey) {
    return _videoEvents.where((video) => video.pubkey == pubkey).toList();
  }
  
  /// Subscribe to kind 22 video events from all connected relays
  Future<void> subscribeToVideoFeed({
    List<String>? authors,
    List<String>? hashtags,
    String? group, // Support filtering by group ('h' tag)
    int? since,
    int? until,
    int limit = 50, // Start with smaller limit for fast initial load
    bool replace = true, // Whether to replace existing subscription
    bool includeReposts = false, // Whether to include kind 6 reposts (disabled by default)
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
    
    if (_nostrService.connectedRelayCount == 0) {
      debugPrint('⚠️ WARNING: No relays connected - subscription will likely fail');
    }
    
    // Only close existing subscriptions if replace=true
    if (replace) {
      debugPrint('🔄 Cancelling existing subscriptions (replace=true)');
      await _cancelExistingSubscriptions();
    } else {
      debugPrint('➕ Keeping existing subscriptions (replace=false)');
    }
    
    try {
      debugPrint('🔍 Creating filter for kind 22 video events...');
      debugPrint('  - Authors: ${authors?.length ?? 'all'}');
      debugPrint('  - Hashtags: ${hashtags?.join(', ') ?? 'none'}');
      debugPrint('  - Group: ${group ?? 'none'}');
      debugPrint('  - Since: ${since != null ? DateTime.fromMillisecondsSinceEpoch(since * 1000) : 'none'}');
      debugPrint('  - Until: ${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}');
      debugPrint('  - Limit: $limit');
      debugPrint('  - Replace existing: $replace');
      
      // Track if this is a following feed (has specific authors)
      _isFollowingFeed = authors != null && authors.isNotEmpty;
      debugPrint('  - Is following feed: $_isFollowingFeed');
      
      // Create filter for kind 22 events
      // No artificial date constraints - let relays return their best content
      int? effectiveSince = since;
      int? effectiveUntil = until;
      
      if (since == null && until == null && _videoEvents.isEmpty) {
        debugPrint('📅 Initial load: requesting best video content (no date constraints)');
        // Let relays decide what content to return - they know their data best
      }
      
      // Create optimized filter for Kind 22 video events
      final videoFilter = Filter(
        kinds: [22], // NIP-71 short video events only
        authors: authors,
        since: effectiveSince,
        until: effectiveUntil,
        limit: limit, // Use full limit for video events
      );
      
      // Store group for client-side filtering
      _activeGroupFilter = group;
      
      List<Filter> filters = [videoFilter];
      
      // Optionally add repost filter if enabled
      if (includeReposts) {
        final repostFilter = Filter(
          kinds: [6], // NIP-18 reposts only
          authors: authors,
          since: effectiveSince,
          until: effectiveUntil,
          limit: (limit * 0.2).round(), // Only 20% for reposts when enabled
        );
        filters.add(repostFilter);
        debugPrint('🔍 Using primary video filter + optional repost filter:');
        debugPrint('  - Video filter ($limit limit): ${videoFilter.toJson()}');
        debugPrint('  - Repost filter (${(limit * 0.2).round()} limit): ${repostFilter.toJson()}');
      } else {
        debugPrint('🔍 Using video-only filter (reposts disabled):');
        debugPrint('  - Video filter ($limit limit): ${videoFilter.toJson()}');
      }
      
      // Store hashtag filter for event processing
      _activeHashtagFilter = hashtags;
      
      // Use managed subscription if available, otherwise fall back to direct subscription
      if (_subscriptionManager != null) {
        debugPrint('📡 Creating managed subscription via SubscriptionManager...');
        final subscriptionId = await _subscriptionManager!.createSubscription(
          name: 'video_feed',
          filters: filters,
          onEvent: (event) => _handleNewVideoEvent(event),
          onError: (error) => _handleSubscriptionError(error),
          onComplete: () => _handleSubscriptionComplete(),
          priority: _isFollowingFeed ? 1 : 3, // Higher priority for following feed
        );
        
        _activeSubscriptionIds.add(subscriptionId);
        debugPrint('✅ Managed subscription created with ID: $subscriptionId');
      } else {
        debugPrint('📡 Creating direct subscription via nostr_sdk...');
        debugPrint('🎯 iOS DEBUG: Subscription filters: ${filters.map((f) => f.toJson()).toList()}');
        debugPrint('🎯 iOS DEBUG: NostrService relay count: ${_nostrService.connectedRelayCount}');
        final eventStream = _nostrService.subscribeToEvents(filters: filters);
        
        final subscriptionKey = 'video_feed_${DateTime.now().millisecondsSinceEpoch}';
        final subscription = eventStream.listen(
          (event) {
            debugPrint('🎯 iOS DEBUG: Stream event received!');
            _handleNewVideoEvent(event);
          },
          onError: (error) {
            debugPrint('🎯 iOS DEBUG: Stream error: $error');
            _handleSubscriptionError(error);
          },
          onDone: () {
            debugPrint('🎯 iOS DEBUG: Stream done!');
            _handleSubscriptionComplete();
          },
        );
        
        _subscriptions[subscriptionKey] = subscription;
        debugPrint('✅ Direct subscription created with key: $subscriptionKey');
      }
      
      _isSubscribed = true;
      
      debugPrint('✅ Video event subscription established successfully!');
      
      // Add default video if feed is empty to ensure new users have content
      _ensureDefaultContent();
      
      // Progressive loading removed - let UI trigger loadMore as needed
      final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
      debugPrint('📊 Subscription status: active=$totalSubs subscriptions (${_activeSubscriptionIds.length} managed, ${_subscriptions.length} direct)');
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
  void _handleNewVideoEvent(dynamic eventData) {
    try {
      // First log the raw event data to understand what we're receiving
      debugPrint('🎯 iOS DEBUG: Event received! Type: ${eventData.runtimeType}');
      debugPrint('🎯 iOS DEBUG: Event string: ${eventData.toString()}');
      
      // The event should already be an Event object from NostrService
      if (eventData is! Event) {
        debugPrint('⚠️ Expected Event object but got ${eventData.runtimeType}');
        return;
      }
      
      Event event = eventData;
      debugPrint('📥 Received event: kind=${event.kind}, id=${event.id.substring(0, 8)}..., created=${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}');
      
      if (event.kind != 22 && event.kind != 6) {
        debugPrint('⏩ Skipping non-video/repost event (kind ${event.kind})');
        return;
      }
      
      // Skip repost events if reposts are disabled
      if (event.kind == 6) {
        debugPrint('⏩ Skipping repost event ${event.id.substring(0, 8)}... (reposts disabled by default)');
        return;
      }
      
      // Check if we already have this event
      if (_videoEvents.any((e) => e.id == event.id)) {
        _duplicateVideoEventCount++;
        _logDuplicateVideoEventsAggregated();
        return;
      }
      
      // Check if content is blocked
      if (_blocklistService?.shouldFilterFromFeeds(event.pubkey) == true) {
        debugPrint('🚫 Filtering blocked content from ${event.pubkey.substring(0, 8)}...');
        return;
      }
      
      // TEMPORARILY DISABLED: Check if user has already seen this video
      // TODO: Re-enable after testing the video feed
      // if (_seenVideosService?.hasSeenVideo(event.id) == true) {
      //   debugPrint('👁️ Skipping seen video ${event.id.substring(0, 8)}...');
      //   return;
      // }
      
      // TEMPORARILY DISABLED: CLIENT-SIDE FILTERING to debug feed issue
      // TODO: Re-enable after fixing the feed stopping issue
      // final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      // final eventTime = DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000);
      // 
      // if (eventTime.isBefore(sevenDaysAgo)) {
      //   debugPrint('⏰ FILTERING OUT OLD EVENT: ${event.id.substring(0, 8)} from $eventTime (older than 7 days)');
      //   return; // Return early without notifying listeners to prevent rebuild loops
      // }
      
      // Handle different event kinds
      if (event.kind == 22) {
        // Direct video event
        debugPrint('🎬 Processing new video event ${event.id.substring(0, 8)}...');
        debugPrint('🔍 Direct event tags: ${event.tags}');
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          debugPrint('🎥 Parsed direct video: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}');
          debugPrint('🖼️ Thumbnail URL: ${videoEvent.thumbnailUrl}');
          debugPrint('🖼️ Has thumbnail: ${videoEvent.thumbnailUrl != null && videoEvent.thumbnailUrl!.isNotEmpty}');
          debugPrint('👤 Video author pubkey: ${videoEvent.pubkey}');
          debugPrint('📝 Video title: ${videoEvent.title}');
          debugPrint('🏷️ Video hashtags: ${videoEvent.hashtags}');
          
          // Check hashtag filter if active
          if (_activeHashtagFilter != null && _activeHashtagFilter!.isNotEmpty) {
            // Check if video has any of the required hashtags
            final hasRequiredHashtag = _activeHashtagFilter!.any((tag) => 
              videoEvent.hashtags.contains(tag)
            );
            
            if (!hasRequiredHashtag) {
              debugPrint('⏩ Skipping video without required hashtags: $_activeHashtagFilter');
              return;
            }
          }
          
          // Check group filter if active
          if (_activeGroupFilter != null && videoEvent.group != _activeGroupFilter) {
            debugPrint('⏩ Skipping video from different group: ${videoEvent.group} (want: $_activeGroupFilter)');
            return;
          }
          
          // Only add events with video URLs
          if (videoEvent.hasVideo) {
            _addVideoWithPriority(videoEvent);
            
            // Keep only the most recent events to prevent memory issues
            if (_videoEvents.length > 500) {
              _videoEvents.removeRange(500, _videoEvents.length);
            }
            
            debugPrint('✅ Added video event! Total: ${_videoEvents.length} events');
            notifyListeners();
          } else {
            debugPrint('⏩ Skipping video event without video URL');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Failed to parse video event: $e');
          debugPrint('📍 Stack trace: $stackTrace');
          debugPrint('🔍 Event details:');
          debugPrint('  - ID: ${event.id}');
          debugPrint('  - Kind: ${event.kind}');
          debugPrint('  - Pubkey: ${event.pubkey}');
          debugPrint('  - Content: ${event.content}');
          debugPrint('  - Created at: ${event.createdAt}');
          debugPrint('  - Tags: ${event.tags}');
        }
      } else if (event.kind == 6) {
        // Repost event - only process if it likely references video content
        debugPrint('🔄 Processing repost event ${event.id.substring(0, 8)}...');
        
        String? originalEventId;
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
            originalEventId = tag[1];
            break;
          }
        }
        
        // Smart filtering: Only process reposts that are likely video-related
        if (!_isLikelyVideoRepost(event)) {
          debugPrint('⏩ Skipping non-video repost ${event.id.substring(0, 8)}... (no video indicators)');
          return;
        }
        
        if (originalEventId != null) {
          debugPrint('🔍 Repost references event: ${originalEventId.substring(0, 8)}...');
          
          // Check if we already have the original video in our cache
          final existingOriginal = _videoEvents.firstWhere(
            (v) => v.id == originalEventId,
            orElse: () => VideoEvent(
              id: '',
              pubkey: '',
              createdAt: 0,
              content: '',
              timestamp: DateTime.now(),
            ),
          );
          
          if (existingOriginal.id.isNotEmpty) {
            // Create repost version of existing video
            debugPrint('✅ Found cached original video, creating repost');
            final repostEvent = VideoEvent.createRepostEvent(
              originalEvent: existingOriginal,
              repostEventId: event.id,
              reposterPubkey: event.pubkey,
              repostedAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
            );
            
            // Check hashtag filter for reposts too
            if (_activeHashtagFilter != null && _activeHashtagFilter!.isNotEmpty) {
              final hasRequiredHashtag = _activeHashtagFilter!.any((tag) => 
                repostEvent.hashtags.contains(tag)
              );
              
              if (!hasRequiredHashtag) {
                debugPrint('⏩ Skipping repost without required hashtags: $_activeHashtagFilter');
                return;
              }
            }
            
            _addVideoWithPriority(repostEvent);
            debugPrint('✅ Added repost event! Total: ${_videoEvents.length} events');
            notifyListeners();
          } else {
            // Fetch original event from relays
            debugPrint('🔍 Fetching original video event from relays...');
            _fetchOriginalEventForRepost(originalEventId, event);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error processing video event: $e');
    }
  }
  
  /// Handle subscription error
  void _handleSubscriptionError(dynamic error) {
    _error = error.toString();
    debugPrint('❌ Video subscription error: $error');
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    debugPrint('📊 Current state: events=${_videoEvents.length}, subscriptions=$totalSubs');
    
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
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    debugPrint('📊 Final state: events=${_videoEvents.length}, subscriptions=$totalSubs');
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
  
  /// Subscribe to videos from a specific group (using 'h' tag)
  Future<void> subscribeToGroupVideos(String group, {
    List<String>? authors,
    int? since,
    int? until,
    int limit = 50,
  }) async {
    if (!_nostrService.isInitialized) {
      throw VideoEventServiceException('Nostr service not initialized');
    }
    
    debugPrint('🔍 Subscribing to videos from group: $group');
    
    // Note: Nostr SDK Filter doesn't support custom tags directly,
    // so we'll rely on client-side filtering for group 'h' tags
    debugPrint('🔍 Subscribing to group: $group (will filter client-side)');
    
    // Use existing subscription infrastructure with group parameter
    return subscribeToVideoFeed(
      authors: authors,
      group: group,
      since: since,
      until: until,
      limit: limit,
    );
  }
  
  /// Get video events by group from cache
  List<VideoEvent> getVideoEventsByGroup(String group) {
    return _videoEvents.where((event) => event.group == group).toList();
  }
  
  /// Refresh video feed by fetching recent events with expanded timeframe
  Future<void> refreshVideoFeed() async {
    debugPrint('🔄 Refresh requested - restarting subscription with expanded timeframe');
    
    // Close existing subscriptions and create new ones with expanded timeframe
    await unsubscribeFromVideoFeed();
    
    debugPrint('📡 Creating new subscription with expanded timeframe...');
    return subscribeToVideoFeed();
  }
  
  /// Progressive loading: load more videos after initial fast load
  Future<void> loadMoreVideos({int limit = 100}) async {
    debugPrint('📚 Loading more videos progressively...');
    
    // Use larger limit for progressive loading
    return subscribeToVideoFeed(
      limit: limit,
      replace: false, // Don't replace existing subscription
    );
  }

  /// Load more historical events using one-shot query (not persistent subscription)
  Future<void> loadMoreEvents({int limit = 200}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint('📚 Loading more historical events...');
      
      int? until;
      
      // If we have events, get older ones by finding the oldest timestamp
      if (_videoEvents.isNotEmpty) {
        // Sort events by timestamp to find the actual oldest
        final sortedEvents = List<VideoEvent>.from(_videoEvents)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        final oldestEvent = sortedEvents.first;
        until = oldestEvent.createdAt - 1; // One second before oldest event
        debugPrint('📚 Requesting events older than ${DateTime.fromMillisecondsSinceEpoch(until * 1000)}');
        debugPrint('📚 Current oldest event: ${oldestEvent.title ?? oldestEvent.id.substring(0, 8)} at ${DateTime.fromMillisecondsSinceEpoch(oldestEvent.createdAt * 1000)}');
      } else {
        // If no events yet, load without date constraints
        debugPrint('📚 No existing events, loading fresh content without date constraints');
      }
      
      // Use one-shot historical query - this will complete when EOSE is received
      await _queryHistoricalEvents(until: until, limit: limit);
      
      debugPrint('✅ Historical events loaded. Total events: ${_videoEvents.length}');
      
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
    
    // Create filter without restrictive date constraints
    final filter = Filter(
      kinds: [22], // Focus on video events primarily
      until: until, // Only use 'until' if we have existing events
      limit: limit,
      // No 'since' filter to allow loading of all historical content
    );
    
    debugPrint('🔍 One-shot historical query: until=${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}, limit=$limit');
    debugPrint('🔍 Filter: ${filter.toJson()}');
    
    // Use managed subscription if available
    if (_subscriptionManager != null) {
      final subscriptionId = await _subscriptionManager!.createSubscription(
        name: 'historical_query',
        filters: [filter],
        onEvent: (event) => _handleNewVideoEvent(event),
        onError: (error) {
          debugPrint('❌ Historical query error: $error');
          if (!completer.isCompleted) completer.completeError(error);
        },
        onComplete: () {
          debugPrint('✅ Historical query completed (EOSE received)');
          if (!completer.isCompleted) completer.complete();
        },
        timeout: const Duration(seconds: 30),
        priority: 5, // Medium priority for historical queries
      );
      
      // Clean up subscription when done
      completer.future.whenComplete(() {
        _subscriptionManager!.cancelSubscription(subscriptionId);
      });
    } else {
      // Fall back to direct subscription
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
    }
    
    return completer.future;
  }
  
  /// Load more content without date restrictions - for when users reach end of feed
  Future<void> loadMoreContentUnlimited({int limit = 300}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint('🌊 Loading unlimited content for end-of-feed...');
      
      // Create a broader query without date restrictions
      final filter = Filter(
        kinds: [22], // Video events
        limit: limit,
        // No date filters - let relays return their best content
      );
      
      debugPrint('🔍 Unlimited content query: limit=$limit');
      debugPrint('🔍 Filter: ${filter.toJson()}');
      
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      late StreamSubscription subscription;
      final completer = Completer<void>();
      
      subscription = eventStream.listen(
        (event) {
          _handleNewVideoEvent(event);
        },
        onError: (error) {
          debugPrint('❌ Unlimited content query error: $error');
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          debugPrint('✅ Unlimited content query completed (EOSE received)');
          subscription.cancel();
          if (!completer.isCompleted) completer.complete();
        },
      );
      
      // Set timeout for the query
      Timer(const Duration(seconds: 45), () {
        if (!completer.isCompleted) {
          debugPrint('⏰ Unlimited content query timed out after 45 seconds');
          subscription.cancel();
          completer.complete();
        }
      });
      
      await completer.future;
      
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Failed to load unlimited content: $e');
      
      if (_isConnectionError(e)) {
        debugPrint('🌐 Unlimited content load failed due to connection error');
      }
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
  
  /// Get video event by vine ID (using 'd' tag)
  VideoEvent? getVideoEventByVineId(String vineId) {
    try {
      return _videoEvents.firstWhere((event) => event.vineId == vineId);
    } catch (e) {
      return null;
    }
  }
  
  /// Query video events by vine ID from relays
  Future<VideoEvent?> queryVideoByVineId(String vineId) async {
    if (!_nostrService.isInitialized) {
      throw VideoEventServiceException('Nostr service not initialized');
    }
    
    debugPrint('🔍 Querying for video with vine ID: $vineId');
    
    final completer = Completer<VideoEvent?>();
    VideoEvent? foundEvent;
    
    // Note: Since Filter doesn't support custom tags, we'll fetch recent videos
    // and filter client-side for the specific vine ID
    final filter = Filter(
      kinds: [22],
      limit: 100, // Fetch more to increase chance of finding the video
    );
    
    debugPrint('🔍 Querying for videos, will filter for vine ID: $vineId');
    
    final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
    late StreamSubscription subscription;
    
    subscription = eventStream.listen(
      (event) {
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          // Check if this video has the vine ID we're looking for
          if (videoEvent.vineId == vineId) {
            debugPrint('📥 Found video event for vine ID $vineId: ${event.id.substring(0, 8)}...');
            foundEvent = videoEvent;
            if (!completer.isCompleted) {
              completer.complete(foundEvent);
            }
            subscription.cancel();
          }
        } catch (e) {
          debugPrint('❌ Error parsing video event: $e');
        }
      },
      onError: (error) {
        debugPrint('❌ Error querying video by vine ID: $error');
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        subscription.cancel();
      },
      onDone: () {
        debugPrint('🏁 Vine ID query completed');
        if (!completer.isCompleted) {
          completer.complete(foundEvent);
        }
      },
    );
    
    // Set timeout
    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        debugPrint('⏰ Vine ID query timed out');
        subscription.cancel();
        completer.complete(null);
      }
    });
    
    return completer.future;
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
  
  /// Cancel all existing subscriptions
  Future<void> _cancelExistingSubscriptions() async {
    // Cancel managed subscriptions
    if (_subscriptionManager != null && _activeSubscriptionIds.isNotEmpty) {
      debugPrint('🔄 Cancelling ${_activeSubscriptionIds.length} managed subscriptions...');
      for (final subscriptionId in _activeSubscriptionIds) {
        await _subscriptionManager!.cancelSubscription(subscriptionId);
      }
      _activeSubscriptionIds.clear();
    }
    
    // Cancel direct subscriptions
    if (_subscriptions.isNotEmpty) {
      debugPrint('🔄 Cancelling ${_subscriptions.length} direct subscriptions...');
      for (final entry in _subscriptions.entries) {
        await entry.value.cancel();
      }
      _subscriptions.clear();
    }
  }

  /// Unsubscribe from all video event subscriptions
  Future<void> unsubscribeFromVideoFeed() async {
    try {
      await _cancelExistingSubscriptions();
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
  
  /// Fetch original event for a repost from relays
  Future<void> _fetchOriginalEventForRepost(String originalEventId, Event repostEvent) async {
    try {
      debugPrint('🔍 Fetching original event $originalEventId for repost ${repostEvent.id.substring(0, 8)}...');
      
      // Create a one-shot subscription to fetch the specific event
      final eventStream = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            ids: [originalEventId],
            kinds: [22], // Only fetch if it's a video event
          ),
        ],
      );
      
      // Listen for the original event
      late StreamSubscription subscription;
      subscription = eventStream.listen(
        (originalEvent) {
          debugPrint('📥 Retrieved original event ${originalEvent.id.substring(0, 8)}...');
          debugPrint('🔍 Event tags: ${originalEvent.tags}');
          
          // Check if it's a valid video event
          if (originalEvent.kind == 22) {
            try {
              final originalVideoEvent = VideoEvent.fromNostrEvent(originalEvent);
              debugPrint('🎥 Parsed video event: hasVideo=${originalVideoEvent.hasVideo}, videoUrl=${originalVideoEvent.videoUrl}');
              
              // Only process if it has video content
              if (originalVideoEvent.hasVideo) {
                // Create the repost version
                final repostVideoEvent = VideoEvent.createRepostEvent(
                  originalEvent: originalVideoEvent,
                  repostEventId: repostEvent.id,
                  reposterPubkey: repostEvent.pubkey,
                  repostedAt: DateTime.fromMillisecondsSinceEpoch(repostEvent.createdAt * 1000),
                );
                
                // Check hashtag filter for fetched reposts too
                if (_activeHashtagFilter != null && _activeHashtagFilter!.isNotEmpty) {
                  final hasRequiredHashtag = _activeHashtagFilter!.any((tag) => 
                    repostVideoEvent.hashtags.contains(tag)
                  );
                  
                  if (!hasRequiredHashtag) {
                    debugPrint('⏩ Skipping fetched repost without required hashtags: $_activeHashtagFilter');
                    return;
                  }
                }
                
                // Add to video events
                _addVideoWithPriority(repostVideoEvent);
                
                // Keep list size manageable
                if (_videoEvents.length > 500) {
                  _videoEvents.removeRange(500, _videoEvents.length);
                }
                
                debugPrint('✅ Added fetched repost event! Total: ${_videoEvents.length} events');
                notifyListeners();
              } else {
                debugPrint('⏩ Skipping repost of video without URL');
              }
            } catch (e) {
              debugPrint('❌ Failed to parse original video event for repost: $e');
            }
          }
          
          // Clean up subscription
          subscription.cancel();
        },
        onError: (error) {
          debugPrint('❌ Error fetching original event for repost: $error');
          subscription.cancel();
        },
        onDone: () {
          debugPrint('🏁 Finished fetching original event for repost');
          subscription.cancel();
        },
      );
      
      // Set timeout to avoid hanging
      Timer(const Duration(seconds: 5), () {
        debugPrint('⏰ Timeout fetching original event for repost');
        subscription.cancel();
      });
      
    } catch (e) {
      debugPrint('❌ Error in _fetchOriginalEventForRepost: $e');
    }
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
  
  /// Check if a repost event is likely to reference video content
  bool _isLikelyVideoRepost(Event repostEvent) {
    // Check content for video-related keywords
    final content = repostEvent.content.toLowerCase();
    final videoKeywords = ['video', 'gif', 'mp4', 'webm', 'mov', 'vine', 'clip', 'watch'];
    
    // Check for video file extensions or video-related terms
    if (videoKeywords.any((keyword) => content.contains(keyword))) {
      return true;
    }
    
    // Check tags for video-related hashtags
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 't' && tag.length > 1) {
        final hashtag = tag[1].toLowerCase();
        if (videoKeywords.any((keyword) => hashtag.contains(keyword))) {
          return true;
        }
      }
    }
    
    // Check for presence of 'k' tag indicating original event kind
    for (final tag in repostEvent.tags) {
      if (tag.isNotEmpty && tag[0] == 'k' && tag.length > 1) {
        // If the repost explicitly indicates it's reposting a kind 22 event
        if (tag[1] == '22') {
          return true;
        }
      }
    }
    
    // For now, default to processing all reposts to avoid missing content
    // This can be made more strict as we gather data on repost patterns
    return true;
  }
  
  /// Ensure default content is available for new users
  void _ensureDefaultContent() {
    // DISABLED: Default video system disabled due to loading issues
    // The default video was not loading properly and causing user experience issues
    debugPrint('⚠️ Default video system is disabled - users will see real content only');
    return;
    
    /* COMMENTED OUT - DEFAULT VIDEO SYSTEM
    try {
      final defaultVideos = DefaultContentService.getDefaultVideos();
      
      if (_videoEvents.isEmpty) {
        // No videos at all - add default videos as initial content
        debugPrint('📺 Adding default content for new users (empty feed)...');
        
        for (final video in defaultVideos) {
          _videoEvents.add(video);
          debugPrint('✅ Added default video: ${video.title ?? video.id.substring(0, 8)}');
        }
        
        debugPrint('📺 Default content added. Total videos: ${_videoEvents.length}');
        notifyListeners();
        
      } else {
        // We have videos - ensure default video is first if not already present
        final defaultVideoIds = defaultVideos.map((v) => v.id).toSet();
        final hasDefaultVideo = _videoEvents.any((v) => defaultVideoIds.contains(v.id));
        
        if (!hasDefaultVideo) {
          debugPrint('📺 Ensuring default video appears first in main feed...');
          
          // Add default videos at the beginning
          for (int i = defaultVideos.length - 1; i >= 0; i--) {
            final video = defaultVideos[i];
            _videoEvents.insert(0, video);
            debugPrint('✅ Inserted default video at position 0: ${video.title ?? video.id.substring(0, 8)}');
          }
          
          debugPrint('📺 Default video now first in main feed. Total videos: ${_videoEvents.length}');
          notifyListeners();
          
        } else {
          // Default video exists - ensure it's first
          _sortVideosByPriority();
          debugPrint('📺 Default video already present, ensuring correct priority order');
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to ensure default content: $e');
    }
    */
  }
  
  /// Sort videos to prioritize default/featured content for new users
  void _sortVideosByPriority() {
    _videoEvents.sort((a, b) {
      final aPriority = DefaultContentService.getDefaultVideoPriority(a.id);
      final bPriority = DefaultContentService.getDefaultVideoPriority(b.id);
      
      // If both are default videos or both are regular, sort by timestamp (newest first)
      if (aPriority == bPriority) {
        return b.timestamp.compareTo(a.timestamp);
      }
      
      // Otherwise sort by priority (lower number = higher priority)
      return aPriority.compareTo(bPriority);
    });
  }
  
  /// Add video maintaining priority order (default videos first, then by timestamp)
  void _addVideoWithPriority(VideoEvent videoEvent) {
    final videoPriority = DefaultContentService.getDefaultVideoPriority(videoEvent.id);
    
    // If it's a default video (priority 0), keep it at the top
    if (videoPriority == 0) {
      // Find position among other default videos (sorted by timestamp)
      int insertIndex = 0;
      for (int i = 0; i < _videoEvents.length; i++) {
        final existingPriority = DefaultContentService.getDefaultVideoPriority(_videoEvents[i].id);
        if (existingPriority != 0) {
          // Found first non-default video, insert before it
          break;
        }
        if (_videoEvents[i].timestamp.isBefore(videoEvent.timestamp)) {
          // Found older default video, insert before it
          break;
        }
        insertIndex = i + 1;
      }
      _videoEvents.insert(insertIndex, videoEvent);
    } else {
      // Regular video - sorting depends on whether this is a following feed
      if (!_isFollowingFeed) {
        // Not following anyone - insert at random position among non-default videos
        int defaultCount = 0;
        for (int i = 0; i < _videoEvents.length; i++) {
          final existingPriority = DefaultContentService.getDefaultVideoPriority(_videoEvents[i].id);
          if (existingPriority == 0) {
            defaultCount++;
          } else {
            break;
          }
        }
        
        // Calculate random position among non-default videos
        final nonDefaultCount = _videoEvents.length - defaultCount;
        if (nonDefaultCount > 0) {
          // Random position between 0 and nonDefaultCount (inclusive)
          final randomOffset = DateTime.now().microsecondsSinceEpoch % (nonDefaultCount + 1);
          final insertIndex = defaultCount + randomOffset;
          _videoEvents.insert(insertIndex, videoEvent);
        } else {
          // No non-default videos yet, just add after defaults
          _videoEvents.add(videoEvent);
        }
      } else {
        // Following feed - maintain chronological order
        int insertIndex = 0;
        for (int i = 0; i < _videoEvents.length; i++) {
          final existingPriority = DefaultContentService.getDefaultVideoPriority(_videoEvents[i].id);
          if (existingPriority != 0) {
            // Found first non-default video, this is where we insert
            insertIndex = i;
            break;
          }
        }
        _videoEvents.insert(insertIndex, videoEvent);
      }
    }
  }
  
  /// Log duplicate video events in an aggregated manner to reduce noise
  void _logDuplicateVideoEventsAggregated() {
    final now = DateTime.now();
    
    // Log aggregated duplicates every 30 seconds or every 25 duplicates
    if (_lastDuplicateVideoLogTime == null || 
        now.difference(_lastDuplicateVideoLogTime!).inSeconds >= 30 ||
        _duplicateVideoEventCount % 25 == 0) {
      
      if (_duplicateVideoEventCount > 0) {
        debugPrint('⏩ Skipped $_duplicateVideoEventCount duplicate video events in last ${_lastDuplicateVideoLogTime != null ? now.difference(_lastDuplicateVideoLogTime!).inSeconds : 0}s');
      }
      
      _lastDuplicateVideoLogTime = now;
      _duplicateVideoEventCount = 0;
    }
  }
  
  @override
  void dispose() {
    _retryTimer?.cancel();
    unsubscribeFromVideoFeed();
    super.dispose();
  }
  
  /// Shuffle non-default videos for users not following anyone
  void shuffleForDiscovery() {
    if (!_isFollowingFeed && _videoEvents.isNotEmpty) {
      debugPrint('🎲 Shuffling videos for discovery mode...');
      
      // Find where non-default videos start
      int defaultCount = 0;
      for (int i = 0; i < _videoEvents.length; i++) {
        final priority = DefaultContentService.getDefaultVideoPriority(_videoEvents[i].id);
        if (priority == 0) {
          defaultCount++;
        } else {
          break;
        }
      }
      
      // Extract non-default videos
      if (defaultCount < _videoEvents.length) {
        final nonDefaultVideos = _videoEvents.sublist(defaultCount);
        
        // Shuffle them
        nonDefaultVideos.shuffle();
        
        // Remove old non-default videos
        _videoEvents.removeRange(defaultCount, _videoEvents.length);
        
        // Add shuffled videos back
        _videoEvents.addAll(nonDefaultVideos);
        
        debugPrint('✅ Shuffled ${nonDefaultVideos.length} videos for discovery');
        notifyListeners();
      }
    }
  }
}

/// Exception thrown by video event service operations
class VideoEventServiceException implements Exception {
  final String message;
  
  const VideoEventServiceException(this.message);
  
  @override
  String toString() => 'VideoEventServiceException: $message';
}