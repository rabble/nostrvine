// ABOUTME: Service for subscribing to and managing NIP-71 kind 22 video events
// ABOUTME: Handles real-time feed updates and local caching of video content

import 'dart:async';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/video_event.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';
import 'seen_videos_service.dart';
import 'default_content_service.dart';
import 'content_blocklist_service.dart';
import 'subscription_manager.dart';
import '../utils/unified_logger.dart';
import '../constants/app_constants.dart';

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
  
  // Track active subscription parameters to properly detect duplicates
  final Map<String, dynamic> _currentSubscriptionParams = {};
  
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
  
  // Track if reposts are enabled for current subscription
  bool _includeReposts = false;
  
  VideoEventService(
    this._nostrService, {
    SeenVideosService? seenVideosService,
    SubscriptionManager? subscriptionManager,
  }) : _subscriptionManager = subscriptionManager;
  
  /// Set the blocklist service for content filtering
  void setBlocklistService(ContentBlocklistService blocklistService) {
    _blocklistService = blocklistService;
    Log.debug('Blocklist service attached to VideoEventService', name: 'VideoEventService', category: LogCategory.video);
  }
  
  /// Set the subscription manager for centralized subscription management
  void setSubscriptionManager(SubscriptionManager subscriptionManager) {
    _subscriptionManager = subscriptionManager;
    Log.debug('SubscriptionManager attached to VideoEventService', name: 'VideoEventService', category: LogCategory.video);
  }
  
  // Getters
  List<VideoEvent> get videoEvents => List.unmodifiable(_videoEvents);
  bool get isSubscribed => _isSubscribed;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasEvents => _videoEvents.isNotEmpty;
  int get eventCount => _videoEvents.length;
  String get classicVinesPubkey => AppConstants.classicVinesPubkey;
  
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
      Log.debug('Subscription request ignored, another is already in progress.', name: 'VideoEventService', category: LogCategory.video);
      return;
    }
    
    // Check if this is a duplicate subscription by comparing parameters
    if (_isSubscribed && _isDuplicateSubscription(authors, hashtags, group, limit, since, until)) {
      Log.debug('Subscription request ignored, already subscribed with same parameters.', name: 'VideoEventService', category: LogCategory.video);
      return;
    }
    
    // Set loading state immediately to prevent race conditions
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    
    if (!_nostrService.isInitialized) {
      _isLoading = false;
      notifyListeners();
      Log.error('Cannot subscribe - Nostr service not initialized', name: 'VideoEventService', category: LogCategory.video);
      throw VideoEventServiceException('Nostr service not initialized');
    }
    
    // Check connection status
    if (!_connectionService.isOnline) {
      _isLoading = false;
      notifyListeners();
      Log.warning('Device is offline, will retry when connection is restored', name: 'VideoEventService', category: LogCategory.video);
      _scheduleRetryWhenOnline();
      throw VideoEventServiceException('Device is offline');
    }
    
    if (_nostrService.connectedRelayCount == 0) {
      Log.warning('WARNING: No relays connected - subscription will likely fail', name: 'VideoEventService', category: LogCategory.video);
    }
    
    // Only close existing subscriptions if replace=true
    if (replace) {
      Log.debug('Cancelling existing subscriptions (replace=true)', name: 'VideoEventService', category: LogCategory.video);
      await _cancelExistingSubscriptions();
    } else {
      Log.debug('➕ Keeping existing subscriptions (replace=false)', name: 'VideoEventService', category: LogCategory.video);
    }
    
    try {
      Log.debug('Creating filter for kind 22 video events...', name: 'VideoEventService', category: LogCategory.video);
      debugPrint('  - Authors: ${authors?.length ?? 'all'}');
      debugPrint('  - Hashtags: ${hashtags?.join(', ') ?? 'none'}');
      debugPrint('  - Group: ${group ?? 'none'}');
      debugPrint('  - Since: ${since != null ? DateTime.fromMillisecondsSinceEpoch(since * 1000) : 'none'}');
      debugPrint('  - Until: ${until != null ? DateTime.fromMillisecondsSinceEpoch(until * 1000) : 'none'}');
      Log.verbose('  - Limit: $limit', name: 'VideoEventService', category: LogCategory.video);
      Log.debug('  - Replace existing: $replace', name: 'VideoEventService', category: LogCategory.video);
      
      // Track if this is a following feed (has specific authors)
      _isFollowingFeed = authors != null && authors.isNotEmpty;
      _includeReposts = includeReposts;
      Log.debug('  - Is following feed: $_isFollowingFeed', name: 'VideoEventService', category: LogCategory.video);
      Log.debug('  - Include reposts: $_includeReposts', name: 'VideoEventService', category: LogCategory.video);
      
      // Create filter for kind 22 events
      // No artificial date constraints - let relays return their best content
      int? effectiveSince = since;
      int? effectiveUntil = until;
      
      if (since == null && until == null && _videoEvents.isEmpty) {
        Log.debug('� Initial load: requesting best video content (no date constraints)', name: 'VideoEventService', category: LogCategory.video);
        // Let relays decide what content to return - they know their data best
      }
      
      // Create optimized filter for Kind 22 video events
      final videoFilter = Filter(
        kinds: [22], // NIP-71 short video events only
        authors: authors,
        since: effectiveSince,
        until: effectiveUntil,
        limit: limit, // Use full limit for video events
        t: hashtags, // Add hashtag filtering at relay level
      );
      
      if (hashtags != null && hashtags.isNotEmpty) {
        Log.debug('Adding hashtag filter to relay query: $hashtags', name: 'VideoEventService', category: LogCategory.video);
      }
      
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
        Log.debug('Using primary video filter + optional repost filter:', name: 'VideoEventService', category: LogCategory.video);
        Log.debug('  - Video filter ($limit limit): ${videoFilter.toJson()}', name: 'VideoEventService', category: LogCategory.video);
        Log.debug('  - Repost filter (${(limit * 0.2).round()} limit): ${repostFilter.toJson()}', name: 'VideoEventService', category: LogCategory.video);
      } else {
        Log.debug('Using video-only filter (reposts disabled):', name: 'VideoEventService', category: LogCategory.video);
        Log.debug('  - Video filter ($limit limit): ${videoFilter.toJson()}', name: 'VideoEventService', category: LogCategory.video);
      }
      
      // Store hashtag filter for event processing
      _activeHashtagFilter = hashtags;
      
      // Use managed subscription if available, otherwise fall back to direct subscription
      if (_subscriptionManager != null) {
        Log.debug('Creating managed subscription via SubscriptionManager...', name: 'VideoEventService', category: LogCategory.video);
        final subscriptionId = await _subscriptionManager!.createSubscription(
          name: 'video_feed',
          filters: filters,
          onEvent: (event) => _handleNewVideoEvent(event),
          onError: (error) => _handleSubscriptionError(error),
          onComplete: () => _handleSubscriptionComplete(),
          priority: _isFollowingFeed ? 1 : 3, // Higher priority for following feed
        );
        
        _activeSubscriptionIds.add(subscriptionId);
        Log.info('Managed subscription created with ID: $subscriptionId', name: 'VideoEventService', category: LogCategory.video);
      } else {
        Log.debug('Creating direct subscription via nostr_sdk...', name: 'VideoEventService', category: LogCategory.video);
        final eventStream = _nostrService.subscribeToEvents(filters: filters);
        
        final subscriptionKey = 'video_feed_${DateTime.now().millisecondsSinceEpoch}';
        final subscription = eventStream.listen(
          (event) {
            _handleNewVideoEvent(event);
          },
          onError: (error) {
            Log.error('Stream error: $error', name: 'VideoEventService', category: LogCategory.video);
            _handleSubscriptionError(error);
          },
          onDone: () {
            _handleSubscriptionComplete();
          },
        );
        
        _subscriptions[subscriptionKey] = subscription;
        Log.info('Direct subscription created with key: $subscriptionKey', name: 'VideoEventService', category: LogCategory.video);
      }
      
      _isSubscribed = true;
      
      // Store current subscription parameters for duplicate detection
      _currentSubscriptionParams.clear();
      _currentSubscriptionParams['authors'] = authors;
      _currentSubscriptionParams['hashtags'] = hashtags;
      _currentSubscriptionParams['group'] = group;
      _currentSubscriptionParams['since'] = since;
      _currentSubscriptionParams['until'] = until;
      _currentSubscriptionParams['limit'] = limit;
      
      Log.info('Video event subscription established successfully!', name: 'VideoEventService', category: LogCategory.video);
      
      // Add default video if feed is empty to ensure new users have content
      _ensureDefaultContent();
      
      // Progressive loading removed - let UI trigger loadMore as needed
      final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
      Log.debug('Subscription status: active=$totalSubs subscriptions (${_activeSubscriptionIds.length} managed, ${_subscriptions.length} direct)', name: 'VideoEventService', category: LogCategory.video);
    } catch (e) {
      _error = e.toString();
      Log.error('Failed to subscribe to video events: $e', name: 'VideoEventService', category: LogCategory.video);
      
      // Check if it's a connection-related error
      if (_isConnectionError(e)) {
        Log.error('� Connection error detected, will retry when online', name: 'VideoEventService', category: LogCategory.video);
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
      
      // The event should already be an Event object from NostrService
      if (eventData is! Event) {
        Log.warning('Expected Event object but got ${eventData.runtimeType}', name: 'VideoEventService', category: LogCategory.video);
        return;
      }
      
      Event event = eventData;
      Log.debug('Received event: kind=${event.kind}, id=${event.id.substring(0, 8)}..., created=${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}', name: 'VideoEventService', category: LogCategory.video);
      
      if (event.kind != 22 && event.kind != 6) {
        Log.warning('⏩ Skipping non-video/repost event (kind ${event.kind})', name: 'VideoEventService', category: LogCategory.video);
        return;
      }
      
      // Skip repost events if reposts are disabled
      if (event.kind == 6 && !_includeReposts) {
        Log.warning('⏩ Skipping repost event ${event.id.substring(0, 8)}... (reposts disabled)', name: 'VideoEventService', category: LogCategory.video);
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
        Log.debug('Filtering blocked content from ${event.pubkey.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
        return;
      }
      
      // TEMPORARILY DISABLED: Check if user has already seen this video
      // TODO: Re-enable after testing the video feed
      // if (_seenVideosService?.hasSeenVideo(event.id) == true) {
      //   Log.warning('�️ Skipping seen video ${event.id.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
      //   return;
      // }
      
      // TEMPORARILY DISABLED: CLIENT-SIDE FILTERING to debug feed issue
      // TODO: Re-enable after fixing the feed stopping issue
      // final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      // final eventTime = DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000);
      // 
      // if (eventTime.isBefore(sevenDaysAgo)) {
      //   Log.debug('⏰ FILTERING OUT OLD EVENT: ${event.id.substring(0, 8)} from $eventTime (older than 7 days)', name: 'VideoEventService', category: LogCategory.video);
      //   return; // Return early without notifying listeners to prevent rebuild loops
      // }
      
      // Handle different event kinds
      if (event.kind == 22) {
        // Direct video event
        Log.debug('Processing new video event ${event.id.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
        Log.debug('Direct event tags: ${event.tags}', name: 'VideoEventService', category: LogCategory.video);
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          Log.debug('Parsed direct video: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}', name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Thumbnail URL: ${videoEvent.thumbnailUrl}', name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Has thumbnail: ${videoEvent.thumbnailUrl != null && videoEvent.thumbnailUrl!.isNotEmpty}', name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Video author pubkey: ${videoEvent.pubkey}', name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Video title: ${videoEvent.title}', name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('Video hashtags: ${videoEvent.hashtags}', name: 'VideoEventService', category: LogCategory.video);
          
          // Check hashtag filter if active
          if (_activeHashtagFilter != null && _activeHashtagFilter!.isNotEmpty) {
            // Check if video has any of the required hashtags
            final hasRequiredHashtag = _activeHashtagFilter!.any((tag) => 
              videoEvent.hashtags.contains(tag)
            );
            
            if (!hasRequiredHashtag) {
              Log.warning('⏩ Skipping video without required hashtags: $_activeHashtagFilter', name: 'VideoEventService', category: LogCategory.video);
              return;
            }
          }
          
          // Check group filter if active
          if (_activeGroupFilter != null && videoEvent.group != _activeGroupFilter) {
            Log.warning('⏩ Skipping video from different group: ${videoEvent.group} (want: $_activeGroupFilter)', name: 'VideoEventService', category: LogCategory.video);
            return;
          }
          
          // Only add events with video URLs
          if (videoEvent.hasVideo) {
            _addVideoWithPriority(videoEvent);
            
            // Keep only the most recent events to prevent memory issues
            if (_videoEvents.length > 500) {
              _videoEvents.removeRange(500, _videoEvents.length);
            }
            
            Log.debug('Added video event! Total: ${_videoEvents.length} events', name: 'VideoEventService', category: LogCategory.video);
            notifyListeners();
          } else {
            Log.warning('⏩ Skipping video event without video URL', name: 'VideoEventService', category: LogCategory.video);
          }
        } catch (e, stackTrace) {
          Log.error('Failed to parse video event: $e', name: 'VideoEventService', category: LogCategory.video);
          Log.verbose('� Stack trace: $stackTrace', name: 'VideoEventService', category: LogCategory.video);
          Log.debug('Event details:', name: 'VideoEventService', category: LogCategory.video);
          Log.debug('  - ID: ${event.id}', name: 'VideoEventService', category: LogCategory.video);
          Log.debug('  - Kind: ${event.kind}', name: 'VideoEventService', category: LogCategory.video);
          Log.debug('  - Pubkey: ${event.pubkey}', name: 'VideoEventService', category: LogCategory.video);
          Log.debug('  - Content: ${event.content}', name: 'VideoEventService', category: LogCategory.video);
          Log.info('  - Created at: ${event.createdAt}', name: 'VideoEventService', category: LogCategory.video);
          Log.debug('  - Tags: ${event.tags}', name: 'VideoEventService', category: LogCategory.video);
        }
      } else if (event.kind == 6) {
        // Repost event - only process if it likely references video content
        Log.debug('Processing repost event ${event.id.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
        
        String? originalEventId;
        for (final tag in event.tags) {
          if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
            originalEventId = tag[1];
            break;
          }
        }
        
        // Smart filtering: Only process reposts that are likely video-related
        if (!_isLikelyVideoRepost(event)) {
          Log.warning('⏩ Skipping non-video repost ${event.id.substring(0, 8)}... (no video indicators)', name: 'VideoEventService', category: LogCategory.video);
          return;
        }
        
        if (originalEventId != null) {
          Log.debug('Repost references event: ${originalEventId.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
          
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
            Log.info('Found cached original video, creating repost', name: 'VideoEventService', category: LogCategory.video);
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
                Log.warning('⏩ Skipping repost without required hashtags: $_activeHashtagFilter', name: 'VideoEventService', category: LogCategory.video);
                return;
              }
            }
            
            _addVideoWithPriority(repostEvent);
            Log.debug('Added repost event! Total: ${_videoEvents.length} events', name: 'VideoEventService', category: LogCategory.video);
            notifyListeners();
          } else {
            // Fetch original event from relays
            Log.debug('Fetching original video event from relays...', name: 'VideoEventService', category: LogCategory.video);
            _fetchOriginalEventForRepost(originalEventId, event);
          }
        }
      }
    } catch (e) {
      Log.error('Error processing video event: $e', name: 'VideoEventService', category: LogCategory.video);
    }
  }
  
  /// Handle subscription error
  void _handleSubscriptionError(dynamic error) {
    _error = error.toString();
    Log.error('Video subscription error: $error', name: 'VideoEventService', category: LogCategory.video);
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    Log.debug('Current state: events=${_videoEvents.length}, subscriptions=$totalSubs', name: 'VideoEventService', category: LogCategory.video);
    
    // Check if it's a connection error and schedule retry
    if (_isConnectionError(error)) {
      Log.error('� Subscription connection error, scheduling retry...', name: 'VideoEventService', category: LogCategory.video);
      _scheduleRetryWhenOnline();
    }
    
    notifyListeners();
  }
  
  /// Handle subscription completion
  void _handleSubscriptionComplete() {
    Log.info('� Video subscription completed', name: 'VideoEventService', category: LogCategory.video);
    final totalSubs = _subscriptions.length + _activeSubscriptionIds.length;
    Log.debug('Final state: events=${_videoEvents.length}, subscriptions=$totalSubs', name: 'VideoEventService', category: LogCategory.video);
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
    
    Log.debug('Subscribing to videos from group: $group', name: 'VideoEventService', category: LogCategory.video);
    
    // Note: Nostr SDK Filter doesn't support custom tags directly,
    // so we'll rely on client-side filtering for group 'h' tags
    Log.debug('Subscribing to group: $group (will filter client-side)', name: 'VideoEventService', category: LogCategory.video);
    
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
    Log.debug('Refresh requested - restarting subscription with expanded timeframe', name: 'VideoEventService', category: LogCategory.video);
    
    // Close existing subscriptions and create new ones with expanded timeframe
    await unsubscribeFromVideoFeed();
    
    Log.debug('Creating new subscription with expanded timeframe...', name: 'VideoEventService', category: LogCategory.video);
    // Preserve the current reposts setting when refreshing
    return subscribeToVideoFeed(includeReposts: _includeReposts);
  }
  
  /// Progressive loading: load more videos after initial fast load
  Future<void> loadMoreVideos({int limit = 100}) async {
    Log.debug('� Loading more videos progressively...', name: 'VideoEventService', category: LogCategory.video);
    
    // Use larger limit for progressive loading
    return subscribeToVideoFeed(
      limit: limit,
      replace: false, // Don't replace existing subscription
    );
  }

  /// Load more historical events using one-shot query (not persistent subscription)
  Future<void> loadMoreEvents({int limit = 200}) async {
    _isLoading = true;
    // Defer notifyListeners to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    
    try {
      Log.debug('� Loading more historical events...', name: 'VideoEventService', category: LogCategory.video);
      
      int? until;
      
      // If we have events, get older ones by finding the oldest timestamp
      if (_videoEvents.isNotEmpty) {
        // Sort events by timestamp to find the actual oldest
        final sortedEvents = List<VideoEvent>.from(_videoEvents)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
        final oldestEvent = sortedEvents.first;
        until = oldestEvent.createdAt - 1; // One second before oldest event
        Log.debug('� Requesting events older than ${DateTime.fromMillisecondsSinceEpoch(until * 1000)}', name: 'VideoEventService', category: LogCategory.video);
        Log.info('� Current oldest event: ${oldestEvent.title ?? oldestEvent.id.substring(0, 8)} at ${DateTime.fromMillisecondsSinceEpoch(oldestEvent.createdAt * 1000)}', name: 'VideoEventService', category: LogCategory.video);
      } else {
        // If no events yet, load without date constraints
        Log.debug('� No existing events, loading fresh content without date constraints', name: 'VideoEventService', category: LogCategory.video);
      }
      
      // Use one-shot historical query - this will complete when EOSE is received
      await _queryHistoricalEvents(until: until, limit: limit);
      
      Log.info('Historical events loaded. Total events: ${_videoEvents.length}', name: 'VideoEventService', category: LogCategory.video);
      
    } catch (e) {
      _error = e.toString();
      Log.error('Failed to load more events: $e', name: 'VideoEventService', category: LogCategory.video);
      
      if (_isConnectionError(e)) {
        Log.error('� Load more failed due to connection error', name: 'VideoEventService', category: LogCategory.video);
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
    Log.debug('Filter: ${filter.toJson()}', name: 'VideoEventService', category: LogCategory.video);
    
    // Use managed subscription if available
    if (_subscriptionManager != null) {
      final subscriptionId = await _subscriptionManager!.createSubscription(
        name: 'historical_query',
        filters: [filter],
        onEvent: (event) => _handleNewVideoEvent(event),
        onError: (error) {
          Log.error('Historical query error: $error', name: 'VideoEventService', category: LogCategory.video);
          if (!completer.isCompleted) completer.completeError(error);
        },
        onComplete: () {
          Log.info('Historical query completed (EOSE received)', name: 'VideoEventService', category: LogCategory.video);
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
          Log.error('Historical query error: $error', name: 'VideoEventService', category: LogCategory.video);
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          Log.info('Historical query completed (EOSE received)', name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
          if (!completer.isCompleted) completer.complete();
        },
      );
      
      // Set timeout for the query
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          Log.debug('⏰ Historical query timed out after 30 seconds', name: 'VideoEventService', category: LogCategory.video);
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
      Log.debug('� Loading unlimited content for end-of-feed...', name: 'VideoEventService', category: LogCategory.video);
      
      // Create a broader query without date restrictions
      final filter = Filter(
        kinds: [22], // Video events
        limit: limit,
        // No date filters - let relays return their best content
      );
      
      Log.debug('Unlimited content query: limit=$limit', name: 'VideoEventService', category: LogCategory.video);
      Log.debug('Filter: ${filter.toJson()}', name: 'VideoEventService', category: LogCategory.video);
      
      final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
      late StreamSubscription subscription;
      final completer = Completer<void>();
      
      subscription = eventStream.listen(
        (event) {
          _handleNewVideoEvent(event);
        },
        onError: (error) {
          Log.error('Unlimited content query error: $error', name: 'VideoEventService', category: LogCategory.video);
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          Log.info('Unlimited content query completed (EOSE received)', name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
          if (!completer.isCompleted) completer.complete();
        },
      );
      
      // Set timeout for the query
      Timer(const Duration(seconds: 45), () {
        if (!completer.isCompleted) {
          Log.debug('⏰ Unlimited content query timed out after 45 seconds', name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
          completer.complete();
        }
      });
      
      await completer.future;
      
    } catch (e) {
      _error = e.toString();
      Log.error('Failed to load unlimited content: $e', name: 'VideoEventService', category: LogCategory.video);
      
      if (_isConnectionError(e)) {
        Log.error('� Unlimited content load failed due to connection error', name: 'VideoEventService', category: LogCategory.video);
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
    
    Log.debug('Querying for video with vine ID: $vineId', name: 'VideoEventService', category: LogCategory.video);
    
    final completer = Completer<VideoEvent?>();
    VideoEvent? foundEvent;
    
    // Note: Since Filter doesn't support custom tags, we'll fetch recent videos
    // and filter client-side for the specific vine ID
    final filter = Filter(
      kinds: [22],
      limit: 100, // Fetch more to increase chance of finding the video
    );
    
    Log.debug('Querying for videos, will filter for vine ID: $vineId', name: 'VideoEventService', category: LogCategory.video);
    
    final eventStream = _nostrService.subscribeToEvents(filters: [filter]);
    late StreamSubscription subscription;
    
    subscription = eventStream.listen(
      (event) {
        try {
          final videoEvent = VideoEvent.fromNostrEvent(event);
          // Check if this video has the vine ID we're looking for
          if (videoEvent.vineId == vineId) {
            Log.info('Found video event for vine ID $vineId: ${event.id.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
            foundEvent = videoEvent;
            if (!completer.isCompleted) {
              completer.complete(foundEvent);
            }
            subscription.cancel();
          }
        } catch (e) {
          Log.error('Error parsing video event: $e', name: 'VideoEventService', category: LogCategory.video);
        }
      },
      onError: (error) {
        Log.error('Error querying video by vine ID: $error', name: 'VideoEventService', category: LogCategory.video);
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
        subscription.cancel();
      },
      onDone: () {
        Log.info('� Vine ID query completed', name: 'VideoEventService', category: LogCategory.video);
        if (!completer.isCompleted) {
          completer.complete(foundEvent);
        }
      },
    );
    
    // Set timeout
    Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        Log.debug('⏰ Vine ID query timed out', name: 'VideoEventService', category: LogCategory.video);
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
      Log.debug('Cancelling ${_activeSubscriptionIds.length} managed subscriptions...', name: 'VideoEventService', category: LogCategory.video);
      for (final subscriptionId in _activeSubscriptionIds) {
        await _subscriptionManager!.cancelSubscription(subscriptionId);
      }
      _activeSubscriptionIds.clear();
    }
    
    // Cancel direct subscriptions
    if (_subscriptions.isNotEmpty) {
      Log.debug('Cancelling ${_subscriptions.length} direct subscriptions...', name: 'VideoEventService', category: LogCategory.video);
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
      _currentSubscriptionParams.clear();
      
      Log.info('Successfully unsubscribed from all video events', name: 'VideoEventService', category: LogCategory.video);
    } catch (e) {
      Log.error('Error unsubscribing from video events: $e', name: 'VideoEventService', category: LogCategory.video);
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
      Log.debug('Fetching original event $originalEventId for repost ${repostEvent.id.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
      
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
          Log.debug('Retrieved original event ${originalEvent.id.substring(0, 8)}...', name: 'VideoEventService', category: LogCategory.video);
          Log.debug('Event tags: ${originalEvent.tags}', name: 'VideoEventService', category: LogCategory.video);
          
          // Check if it's a valid video event
          if (originalEvent.kind == 22) {
            try {
              final originalVideoEvent = VideoEvent.fromNostrEvent(originalEvent);
              Log.debug('Parsed video event: hasVideo=${originalVideoEvent.hasVideo}, videoUrl=${originalVideoEvent.videoUrl}', name: 'VideoEventService', category: LogCategory.video);
              
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
                    Log.warning('⏩ Skipping fetched repost without required hashtags: $_activeHashtagFilter', name: 'VideoEventService', category: LogCategory.video);
                    return;
                  }
                }
                
                // Add to video events
                _addVideoWithPriority(repostVideoEvent);
                
                // Keep list size manageable
                if (_videoEvents.length > 500) {
                  _videoEvents.removeRange(500, _videoEvents.length);
                }
                
                Log.debug('Added fetched repost event! Total: ${_videoEvents.length} events', name: 'VideoEventService', category: LogCategory.video);
                notifyListeners();
              } else {
                Log.warning('⏩ Skipping repost of video without URL', name: 'VideoEventService', category: LogCategory.video);
              }
            } catch (e) {
              Log.error('Failed to parse original video event for repost: $e', name: 'VideoEventService', category: LogCategory.video);
            }
          }
          
          // Clean up subscription
          subscription.cancel();
        },
        onError: (error) {
          Log.error('Error fetching original event for repost: $error', name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
        },
        onDone: () {
          Log.debug('� Finished fetching original event for repost', name: 'VideoEventService', category: LogCategory.video);
          subscription.cancel();
        },
      );
      
      // Set timeout to avoid hanging
      Timer(const Duration(seconds: 5), () {
        Log.debug('⏰ Timeout fetching original event for repost', name: 'VideoEventService', category: LogCategory.video);
        subscription.cancel();
      });
      
    } catch (e) {
      Log.error('Error in _fetchOriginalEventForRepost: $e', name: 'VideoEventService', category: LogCategory.video);
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
        Log.warning('Attempting to resubscribe to video feed (attempt $_retryAttempts/$_maxRetryAttempts)', name: 'VideoEventService', category: LogCategory.video);
        
        subscribeToVideoFeed().then((_) {
          // Success - cancel retry timer
          timer.cancel();
          _retryAttempts = 0;
          Log.info('Successfully resubscribed to video feed', name: 'VideoEventService', category: LogCategory.video);
        }).catchError((e) {
          Log.error('Retry attempt $_retryAttempts failed: $e', name: 'VideoEventService', category: LogCategory.video);
          
          if (_retryAttempts >= _maxRetryAttempts) {
            timer.cancel();
            Log.warning('Max retry attempts reached for video feed subscription', name: 'VideoEventService', category: LogCategory.video);
          }
        });
      } else if (!_connectionService.isOnline) {
        Log.debug('⏳ Still offline, waiting for connection...', name: 'VideoEventService', category: LogCategory.video);
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
    Log.warning('Forcing retry of video feed subscription...', name: 'VideoEventService', category: LogCategory.video);
    _retryAttempts = 0;
    _error = null;
    
    try {
      await subscribeToVideoFeed();
    } catch (e) {
      Log.error('Manual retry failed: $e', name: 'VideoEventService', category: LogCategory.video);
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
    Log.warning('Default video system is disabled - users will see real content only', name: 'VideoEventService', category: LogCategory.video);
    return;
    
    /* COMMENTED OUT - DEFAULT VIDEO SYSTEM
    try {
      final defaultVideos = DefaultContentService.getDefaultVideos();
      
      if (_videoEvents.isEmpty) {
        // No videos at all - add default videos as initial content
        Log.debug('� Adding default content for new users (empty feed)...', name: 'VideoEventService', category: LogCategory.video);
        
        for (final video in defaultVideos) {
          _videoEvents.add(video);
          Log.info('Added default video: ${video.title ?? video.id.substring(0, 8)}', name: 'VideoEventService', category: LogCategory.video);
        }
        
        Log.debug('� Default content added. Total videos: ${_videoEvents.length}', name: 'VideoEventService', category: LogCategory.video);
        notifyListeners();
        
      } else {
        // We have videos - ensure default video is first if not already present
        final defaultVideoIds = defaultVideos.map((v) => v.id).toSet();
        final hasDefaultVideo = _videoEvents.any((v) => defaultVideoIds.contains(v.id));
        
        if (!hasDefaultVideo) {
          Log.debug('� Ensuring default video appears first in main feed...', name: 'VideoEventService', category: LogCategory.video);
          
          // Add default videos at the beginning
          for (int i = defaultVideos.length - 1; i >= 0; i--) {
            final video = defaultVideos[i];
            _videoEvents.insert(0, video);
            Log.info('Inserted default video at position 0: ${video.title ?? video.id.substring(0, 8)}', name: 'VideoEventService', category: LogCategory.video);
          }
          
          Log.debug('� Default video now first in main feed. Total videos: ${_videoEvents.length}', name: 'VideoEventService', category: LogCategory.video);
          notifyListeners();
          
        } else {
          // Default video exists - ensure it's first
          _sortVideosByPriority();
          Log.debug('� Default video already present, ensuring correct priority order', name: 'VideoEventService', category: LogCategory.video);
        }
      }
    } catch (e) {
      Log.error('Failed to ensure default content: $e', name: 'VideoEventService', category: LogCategory.video);
    }
    */
  }
  
  /// Sort videos to prioritize default/featured content for new users
  // ignore: unused_element
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
  
  /// Add video maintaining priority order (classic vines first, then default videos, then by timestamp)
  void _addVideoWithPriority(VideoEvent videoEvent) {
    // Check for duplicates - CRITICAL to prevent the same event being added multiple times
    final existingIndex = _videoEvents.indexWhere((existing) => existing.id == videoEvent.id);
    if (existingIndex != -1) {
      _duplicateVideoEventCount++;
      _logDuplicateVideoEventsAggregated();
      return; // Don't add duplicate events
    }
    
    // Classic Vines account has HIGHEST priority
    final isClassicVine = videoEvent.pubkey == AppConstants.classicVinesPubkey;
    
    final videoPriority = DefaultContentService.getDefaultVideoPriority(videoEvent.id);
    
    // Priority order: 1) Classic Vines, 2) Default videos, 3) Everything else
    if (isClassicVine) {
      // Classic vine - keep at the very top
      int insertIndex = 0;
      for (int i = 0; i < _videoEvents.length; i++) {
        if (_videoEvents[i].pubkey == AppConstants.classicVinesPubkey) {
          // Found another classic vine, sort by timestamp (newest first)
          if (_videoEvents[i].timestamp.isBefore(videoEvent.timestamp)) {
            break;
          }
          insertIndex = i + 1;
        } else {
          // Found non-classic vine, insert before it
          break;
        }
      }
      _videoEvents.insert(insertIndex, videoEvent);
      Log.debug('Added CLASSIC VINE at position $insertIndex: ${videoEvent.title ?? videoEvent.id.substring(0, 8)}', name: 'VideoEventService', category: LogCategory.video);
    } else if (videoPriority == 0) {
      // Default video - keep after classic vines but before regular videos
      int insertIndex = 0;
      // Skip past classic vines
      for (int i = 0; i < _videoEvents.length; i++) {
        if (_videoEvents[i].pubkey == AppConstants.classicVinesPubkey) {
          insertIndex = i + 1;
        } else {
          break;
        }
      }
      // Now find position among default videos
      for (int i = insertIndex; i < _videoEvents.length; i++) {
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
      // Regular video - insert after classic vines and default videos
      int insertIndex = 0;
      // Skip past classic vines and default videos
      for (int i = 0; i < _videoEvents.length; i++) {
        if (_videoEvents[i].pubkey == AppConstants.classicVinesPubkey || 
            DefaultContentService.getDefaultVideoPriority(_videoEvents[i].id) == 0) {
          insertIndex = i + 1;
        } else {
          break;
        }
      }
      
      // Insert at the calculated position (after all priority content)
      if (insertIndex < _videoEvents.length) {
        _videoEvents.insert(insertIndex, videoEvent);
      } else {
        _videoEvents.add(videoEvent);
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
        Log.debug('⏩ Skipped $_duplicateVideoEventCount duplicate video events in last ${_lastDuplicateVideoLogTime != null ? now.difference(_lastDuplicateVideoLogTime!).inSeconds : 0}s', name: 'VideoEventService', category: LogCategory.video);
      }
      
      _lastDuplicateVideoLogTime = now;
      _duplicateVideoEventCount = 0;
    }
  }
  
  /// Check if the given subscription parameters match the current active subscription
  bool _isDuplicateSubscription(
    List<String>? authors,
    List<String>? hashtags,
    String? group,
    int limit,
    int? since,
    int? until,
  ) {
    // If no active subscriptions, it's not a duplicate
    if (_subscriptions.isEmpty && _activeSubscriptionIds.isEmpty) {
      return false;
    }
    
    // Compare with stored subscription parameters
    final currentAuthors = _currentSubscriptionParams['authors'] as List<String>?;
    final currentHashtags = _currentSubscriptionParams['hashtags'] as List<String>?;
    final currentGroup = _currentSubscriptionParams['group'] as String?;
    final currentSince = _currentSubscriptionParams['since'] as int?;
    final currentUntil = _currentSubscriptionParams['until'] as int?;
    final currentLimit = _currentSubscriptionParams['limit'] as int?;
    
    // Check if parameters match
    return _listEquals(authors, currentAuthors) &&
           _listEquals(hashtags, currentHashtags) &&
           group == currentGroup &&
           since == currentSince &&
           until == currentUntil &&
           limit == currentLimit;
  }
  
  /// Helper to compare two lists for equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
      Log.debug('� Shuffling videos for discovery mode...', name: 'VideoEventService', category: LogCategory.video);
      
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
        
        Log.info('Shuffled ${nonDefaultVideos.length} videos for discovery', name: 'VideoEventService', category: LogCategory.video);
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