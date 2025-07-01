// ABOUTME: Riverpod stream provider for managing Nostr video event subscriptions
// ABOUTME: Handles real-time video feed updates based on current feed mode

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

import '../models/video_event.dart';
import '../services/nostr_service_interface.dart';
import '../services/subscription_manager.dart';
import '../state/video_feed_state.dart';
import '../constants/app_constants.dart';
import '../utils/unified_logger.dart';
import 'feed_mode_providers.dart';
import 'social_providers.dart' show socialProvider;

part 'video_events_providers.g.dart';

/// Provider for NostrService instance (Video Events specific)
@riverpod
INostrService videoEventsNostrService(VideoEventsNostrServiceRef ref) {
  throw UnimplementedError('VideoEventsNostrService must be overridden in ProviderScope');
}

/// Provider for SubscriptionManager instance (Video Events specific)
@riverpod
SubscriptionManager videoEventsSubscriptionManager(VideoEventsSubscriptionManagerRef ref) {
  throw UnimplementedError('VideoEventsSubscriptionManager must be overridden in ProviderScope');
}

/// Stream provider for video events from Nostr
@riverpod
class VideoEvents extends _$VideoEvents {
  final List<VideoEvent> _events = [];
  final Set<String> _seenEventIds = {};
  
  @override
  Stream<List<VideoEvent>> build() {
    _events.clear();
    _seenEventIds.clear();
    
    final nostrService = ref.watch(videoEventsNostrServiceProvider);
    
    // Check if Nostr service is initialized
    if (!nostrService.isInitialized) {
      Log.warning('VideoEvents: NostrService not initialized', 
        name: 'VideoEventsProvider', category: LogCategory.video);
      return Stream.value([]);
    }
    
    // Create filter based on current feed mode
    final filter = _createFilter();
    if (filter == null) {
      return Stream.value([]);
    }
    
    Log.info('VideoEvents: Starting subscription with filter', 
      name: 'VideoEventsProvider', category: LogCategory.video);
    
    // Subscribe to events and transform stream
    try {
      final eventStream = nostrService.subscribeToEvents(filters: [filter]);
      
      // Create a controller to manage the output stream
      final controller = StreamController<List<VideoEvent>>();
      
      // Add initial empty list
      controller.add([]);
      
      // Subscribe to events
      late StreamSubscription<Event> subscription;
      subscription = eventStream
          .where((event) => event.kind == 22 && !_seenEventIds.contains(event.id))
          .listen(
            (event) {
              Log.debug('VideoEvents: Received event ${event.id} of kind ${event.kind}', 
                name: 'VideoEventsProvider', category: LogCategory.video);
              
              try {
                Log.debug('VideoEvents: Parsing event ${event.id}', 
                  name: 'VideoEventsProvider', category: LogCategory.video);
                final videoEvent = VideoEvent.fromNostrEvent(event);
                _events.add(videoEvent);
                _seenEventIds.add(event.id);
                
                Log.verbose('VideoEvents: Added video ${videoEvent.id} (total: ${_events.length})', 
                  name: 'VideoEventsProvider', category: LogCategory.video);
                
                // Emit updated list
                controller.add(List.from(_events));
              } catch (e) {
                Log.error('VideoEvents: Failed to parse event ${event.id}: $e', 
                  name: 'VideoEventsProvider', category: LogCategory.video);
              }
            },
            onError: (error) {
              Log.error('VideoEvents: Stream error: $error', 
                name: 'VideoEventsProvider', category: LogCategory.video);
              controller.addError(error);
            },
            onDone: () {
              controller.close();
            },
          );
      
      // Clean up subscription when provider is disposed
      ref.onDispose(() {
        subscription.cancel();
        controller.close();
      });
      
      return controller.stream;
    } catch (e) {
      Log.error('VideoEvents: Stream error: $e', 
        name: 'VideoEventsProvider', category: LogCategory.video);
      return Stream.error(e);
    }
  }
  
  /// Create filter based on current feed mode
  Filter? _createFilter() {
    final feedMode = ref.read(feedModeNotifierProvider);
    final feedContext = ref.read(feedContextProvider);
    final socialData = ref.read(socialProvider);
    
    // Base filter for video events
    final filter = Filter(
      kinds: [22],
      limit: 500,
      h: ['vine'], // Required for vine.hol.is relay
    );
    
    switch (feedMode) {
      case FeedMode.following:
        // Use following list or classic vines fallback
        final followingList = socialData.followingPubkeys;
        filter.authors = followingList.isNotEmpty 
          ? followingList 
          : [AppConstants.classicVinesPubkey];
        
        Log.info('VideoEvents: Following mode with ${filter.authors!.length} authors', 
          name: 'VideoEventsProvider', category: LogCategory.video);
        break;
        
      case FeedMode.curated:
        // Only classic vines curator
        filter.authors = [AppConstants.classicVinesPubkey];
        Log.info('VideoEvents: Curated mode', 
          name: 'VideoEventsProvider', category: LogCategory.video);
        break;
        
      case FeedMode.discovery:
        // General feed - no author filter
        Log.info('VideoEvents: Discovery mode', 
          name: 'VideoEventsProvider', category: LogCategory.video);
        break;
        
      case FeedMode.hashtag:
        // Filter by hashtag
        if (feedContext != null) {
          filter.t = [feedContext];
          Log.info('VideoEvents: Hashtag mode for #$feedContext', 
            name: 'VideoEventsProvider', category: LogCategory.video);
        } else {
          Log.warning('VideoEvents: Hashtag mode but no context', 
            name: 'VideoEventsProvider', category: LogCategory.video);
          return null;
        }
        break;
        
      case FeedMode.profile:
        // Filter by specific author
        if (feedContext != null) {
          filter.authors = [feedContext];
          Log.info('VideoEvents: Profile mode for $feedContext', 
            name: 'VideoEventsProvider', category: LogCategory.video);
        } else {
          Log.warning('VideoEvents: Profile mode but no context', 
            name: 'VideoEventsProvider', category: LogCategory.video);
          return null;
        }
        break;
    }
    
    return filter;
  }
  
  /// Load more historical events
  Future<void> loadMoreEvents() async {
    final nostrService = ref.read(videoEventsNostrServiceProvider);
    if (!nostrService.isInitialized) return;
    
    // Get oldest event timestamp
    final oldestTimestamp = _events.isEmpty 
      ? DateTime.now().millisecondsSinceEpoch ~/ 1000
      : _events.map((e) => e.createdAt).reduce((a, b) => a < b ? a : b);
    
    // Create filter for older events
    final filter = _createFilter();
    if (filter == null) return;
    
    filter.until = oldestTimestamp - 1;
    filter.limit = 50;
    
    Log.info('VideoEvents: Loading more events before timestamp $oldestTimestamp', 
      name: 'VideoEventsProvider', category: LogCategory.video);
    
    try {
      final stream = nostrService.subscribeToEvents(filters: [filter]);
      
      await for (final event in stream) {
        if (event.kind == 22 && !_seenEventIds.contains(event.id)) {
          try {
            final videoEvent = VideoEvent.fromNostrEvent(event);
            _events.add(videoEvent);
            _seenEventIds.add(event.id);
          } catch (e) {
            Log.error('VideoEvents: Failed to parse historical event: $e', 
              name: 'VideoEventsProvider', category: LogCategory.video);
          }
        }
      }
      
      // Sort events by timestamp (newest first)
      _events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Notify listeners with updated list
      ref.notifyListeners();
      
    } catch (e) {
      Log.error('VideoEvents: Error loading more: $e', 
        name: 'VideoEventsProvider', category: LogCategory.video);
    }
  }
  
  /// Clear all events and refresh
  Future<void> refresh() async {
    _events.clear();
    _seenEventIds.clear();
    ref.invalidateSelf();
  }
}

/// Provider to check if video events are loading
@riverpod
bool videoEventsLoading(VideoEventsLoadingRef ref) {
  return ref.watch(videoEventsProvider).isLoading;
}

/// Provider to get video event count
@riverpod
int videoEventCount(VideoEventCountRef ref) {
  return ref.watch(videoEventsProvider).valueOrNull?.length ?? 0;
}