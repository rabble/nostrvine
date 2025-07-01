// ABOUTME: Riverpod providers for social service with reactive state management
// ABOUTME: Replaces Provider-based SocialService with StateNotifier pattern

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

import '../state/social_state.dart';
import '../services/nostr_service_interface.dart';
import '../services/auth_service.dart';
import '../services/subscription_manager.dart';
import '../utils/unified_logger.dart';

part 'social_providers.g.dart';

// Provider dependencies
@riverpod
INostrService nostrService(Ref ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
}

@riverpod
AuthService authService(Ref ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
}

@riverpod
SubscriptionManager subscriptionManager(Ref ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
}

// Social service provider with state management
@riverpod
class Social extends _$Social {
  // Managed subscription IDs
  String? _likeSubscriptionId;
  String? _followSubscriptionId;
  String? _repostSubscriptionId;
  String? _userLikesSubscriptionId;
  String? _userRepostsSubscriptionId;
  
  @override
  SocialState build() {
    ref.onDispose(() {
      _cleanupSubscriptions();
    });
    
    return SocialState.initial;
  }
  
  /// Initialize the service
  Future<void> initialize() async {
    if (state.isInitialized) return;
    
    Log.debug('🤝 Initializing SocialProvider', name: 'SocialProvider', category: LogCategory.system);
    
    state = state.copyWith(isLoading: true);
    
    try {
      final authService = ref.read(authServiceProvider);
      
      // Initialize current user's social data if authenticated
      if (authService.isAuthenticated) {
        await _loadUserLikedEvents();
        await _loadUserRepostedEvents();
        await fetchCurrentUserFollowList();
      }
      
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        error: null,
      );
      
      Log.info('SocialProvider initialized', name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('SocialProvider initialization error: $e', name: 'SocialProvider', category: LogCategory.system);
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  /// Toggle like on/off for an event
  Future<void> toggleLike(String eventId, String authorPubkey) async {
    final authService = ref.read(authServiceProvider);
    
    if (!authService.isAuthenticated) {
      Log.error('Cannot like - user not authenticated', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    // Check if operation is already in progress
    if (state.isLikeInProgress(eventId)) {
      Log.debug('Like operation already in progress for $eventId', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    Log.debug('❤️ Toggling like for event: ${eventId.substring(0, 8)}...', name: 'SocialProvider', category: LogCategory.system);
    
    // Add to in-progress set
    state = state.copyWith(
      likesInProgress: {...state.likesInProgress, eventId},
    );
    
    try {
      final wasLiked = state.isLiked(eventId);
      
      if (!wasLiked) {
        // Add like
        final reactionEventId = await _publishLike(eventId, authorPubkey);
        
        // Update state
        state = state.copyWith(
          likedEventIds: {...state.likedEventIds, eventId},
          likeEventIdToReactionId: {...state.likeEventIdToReactionId, eventId: reactionEventId},
          likeCounts: {...state.likeCounts, eventId: (state.likeCounts[eventId] ?? 0) + 1},
        );
        
        Log.info('Like published for event: ${eventId.substring(0, 8)}...', name: 'SocialProvider', category: LogCategory.system);
      } else {
        // Unlike by publishing NIP-09 deletion event
        final reactionEventId = state.likeEventIdToReactionId[eventId];
        if (reactionEventId != null) {
          await _publishUnlike(reactionEventId);
          
          // Update state
          final newLikedEventIds = {...state.likedEventIds}..remove(eventId);
          final newLikeEventIdToReactionId = {...state.likeEventIdToReactionId}..remove(eventId);
          final currentCount = state.likeCounts[eventId] ?? 0;
          
          state = state.copyWith(
            likedEventIds: newLikedEventIds,
            likeEventIdToReactionId: newLikeEventIdToReactionId,
            likeCounts: {...state.likeCounts, eventId: currentCount > 0 ? currentCount - 1 : 0},
          );
          
          Log.info('Unlike (deletion) published for event: ${eventId.substring(0, 8)}...', name: 'SocialProvider', category: LogCategory.system);
        } else {
          Log.warning('Cannot unlike - reaction event ID not found', name: 'SocialProvider', category: LogCategory.system);
          
          // Fallback: remove from local state only
          final newLikedEventIds = {...state.likedEventIds}..remove(eventId);
          final currentCount = state.likeCounts[eventId] ?? 0;
          
          state = state.copyWith(
            likedEventIds: newLikedEventIds,
            likeCounts: {...state.likeCounts, eventId: currentCount > 0 ? currentCount - 1 : 0},
          );
        }
      }
      
      // Remove from in-progress set on success
      final newLikesInProgress = {...state.likesInProgress}..remove(eventId);
      state = state.copyWith(likesInProgress: newLikesInProgress);
    } catch (e) {
      Log.error('Error toggling like: $e', name: 'SocialProvider', category: LogCategory.system);
      // Remove from in-progress set before updating error
      final newLikesInProgress = {...state.likesInProgress}..remove(eventId);
      state = state.copyWith(
        error: e.toString(),
        likesInProgress: newLikesInProgress,
      );
      rethrow;
    }
  }
  
  /// Follow a user
  Future<void> followUser(String pubkeyToFollow) async {
    final authService = ref.read(authServiceProvider);
    
    if (!authService.isAuthenticated) {
      Log.error('Cannot follow - user not authenticated', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    if (state.isFollowing(pubkeyToFollow)) {
      Log.debug('Already following user: $pubkeyToFollow', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    if (state.isFollowInProgress(pubkeyToFollow)) {
      Log.debug('Follow operation already in progress for $pubkeyToFollow', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    // Add to in-progress set
    state = state.copyWith(
      followsInProgress: {...state.followsInProgress, pubkeyToFollow},
    );
    
    try {
      final newFollowingList = [...state.followingPubkeys, pubkeyToFollow];
      
      // Publish updated contact list
      await _publishContactList(newFollowingList);
      
      // Update state
      state = state.copyWith(followingPubkeys: newFollowingList);
      
      Log.info('Now following: $pubkeyToFollow', name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error following user: $e', name: 'SocialProvider', category: LogCategory.system);
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      // Remove from in-progress set
      final newFollowsInProgress = {...state.followsInProgress}..remove(pubkeyToFollow);
      state = state.copyWith(followsInProgress: newFollowsInProgress);
    }
  }
  
  /// Unfollow a user
  Future<void> unfollowUser(String pubkeyToUnfollow) async {
    final authService = ref.read(authServiceProvider);
    
    if (!authService.isAuthenticated) {
      Log.error('Cannot unfollow - user not authenticated', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    if (!state.isFollowing(pubkeyToUnfollow)) {
      Log.debug('Not following user: $pubkeyToUnfollow', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    if (state.isFollowInProgress(pubkeyToUnfollow)) {
      Log.debug('Follow operation already in progress for $pubkeyToUnfollow', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    // Add to in-progress set
    state = state.copyWith(
      followsInProgress: {...state.followsInProgress, pubkeyToUnfollow},
    );
    
    try {
      final newFollowingList = state.followingPubkeys.where((p) => p != pubkeyToUnfollow).toList();
      
      // Publish updated contact list
      await _publishContactList(newFollowingList);
      
      // Update state
      state = state.copyWith(followingPubkeys: newFollowingList);
      
      Log.info('Unfollowed: $pubkeyToUnfollow', name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error unfollowing user: $e', name: 'SocialProvider', category: LogCategory.system);
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      // Remove from in-progress set
      final newFollowsInProgress = {...state.followsInProgress}..remove(pubkeyToUnfollow);
      state = state.copyWith(followsInProgress: newFollowsInProgress);
    }
  }
  
  /// Repost an event
  Future<void> repostEvent(Event eventToRepost) async {
    final authService = ref.read(authServiceProvider);
    
    if (!authService.isAuthenticated) {
      Log.error('Cannot repost - user not authenticated', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    final eventId = eventToRepost.id;
    
    if (state.hasReposted(eventId)) {
      Log.debug('Already reposted event: $eventId', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    if (state.isRepostInProgress(eventId)) {
      Log.debug('Repost operation already in progress for $eventId', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    // Add to in-progress set
    state = state.copyWith(
      repostsInProgress: {...state.repostsInProgress, eventId},
    );
    
    try {
      // Publish repost event (Kind 6)
      final repostEventId = await _publishRepost(eventToRepost);
      
      // Update state
      state = state.copyWith(
        repostedEventIds: {...state.repostedEventIds, eventId},
        repostEventIdToRepostId: {...state.repostEventIdToRepostId, eventId: repostEventId},
      );
      
      Log.info('Reposted event: ${eventId.substring(0, 8)}...', name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error reposting event: $e', name: 'SocialProvider', category: LogCategory.system);
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      // Remove from in-progress set
      final newRepostsInProgress = {...state.repostsInProgress}..remove(eventId);
      state = state.copyWith(repostsInProgress: newRepostsInProgress);
    }
  }
  
  /// Update follower stats for a user
  void updateFollowerStats(String pubkey, Map<String, int> stats) {
    state = state.copyWith(
      followerStats: {...state.followerStats, pubkey: stats},
    );
  }
  
  /// Update following list (for testing or external updates)
  void updateFollowingList(List<String> followingPubkeys) {
    state = state.copyWith(followingPubkeys: followingPubkeys);
  }
  
  /// Fetch current user's follow list
  Future<void> fetchCurrentUserFollowList() async {
    final authService = ref.read(authServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);
    
    if (!authService.isAuthenticated || authService.currentPublicKeyHex == null) {
      Log.warning('Cannot fetch follow list - user not authenticated', name: 'SocialProvider', category: LogCategory.system);
      return;
    }
    
    try {
      Log.debug('📋 Fetching current user follow list', name: 'SocialProvider', category: LogCategory.system);
      
      // Query for Kind 3 events (contact lists) from current user
      final filter = Filter(
        kinds: const [3],
        authors: [authService.currentPublicKeyHex!],
        limit: 1,
        h: ['vine'], // Required for vine.hol.is relay
      );
      
      // Use stream subscription to get events
      final completer = Completer<List<Event>>();
      final events = <Event>[];
      
      final stream = nostrService.subscribeToEvents(filters: [filter]);
      final subscription = stream.listen(
        (event) => events.add(event),
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(events);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      
      // Wait for events with timeout
      final fetchedEvents = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          subscription.cancel();
          return events;
        },
      );
      
      // Cancel subscription after getting events
      subscription.cancel();
      
      if (fetchedEvents.isNotEmpty) {
        // Get the most recent contact list event
        fetchedEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latestContactList = fetchedEvents.first;
        
        _processContactListEvent(latestContactList);
        
        Log.info('Loaded ${state.followingPubkeys.length} following pubkeys', 
                 name: 'SocialProvider', category: LogCategory.system);
      } else {
        Log.info('No contact list found for current user', name: 'SocialProvider', category: LogCategory.system);
      }
    } catch (e) {
      Log.error('Error fetching follow list: $e', name: 'SocialProvider', category: LogCategory.system);
      state = state.copyWith(error: e.toString());
    }
  }
  
  // Private helper methods
  
  Future<String> _publishLike(String eventId, String authorPubkey) async {
    try {
      final authService = ref.read(authServiceProvider);
      final nostrService = ref.read(nostrServiceProvider);
      
      // Create NIP-25 reaction event (Kind 7)
      final event = await authService.createAndSignEvent(
        kind: 7,
        content: '+', // Standard like reaction
        tags: [
          ['e', eventId], // Reference to liked event
          ['p', authorPubkey], // Reference to liked event author
        ],
      );
      
      if (event == null) {
        throw Exception('Failed to create like event');
      }
      
      // Broadcast the like event
      final result = await nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast like event: $errorMessages');
      }
      
      Log.debug('Like event broadcasted: ${event.id}', name: 'SocialProvider', category: LogCategory.system);
      return event.id;
    } catch (e) {
      Log.error('Error publishing like: $e', name: 'SocialProvider', category: LogCategory.system);
      rethrow;
    }
  }
  
  Future<void> _publishUnlike(String reactionEventId) async {
    try {
      final authService = ref.read(authServiceProvider);
      final nostrService = ref.read(nostrServiceProvider);
      
      // Create NIP-09 deletion event (Kind 5)
      final deletionEvent = await authService.createAndSignEvent(
        kind: 5,
        content: 'Deleting like reaction',
        tags: [
          ['e', reactionEventId], // Reference to the reaction event to delete
        ],
      );
      
      if (deletionEvent == null) {
        throw Exception('Failed to create deletion event');
      }
      
      // Broadcast the deletion event
      final result = await nostrService.broadcastEvent(deletionEvent);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast deletion event: $errorMessages');
      }
      
      Log.debug('Unlike (deletion) event broadcasted: ${deletionEvent.id}', name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error publishing unlike: $e', name: 'SocialProvider', category: LogCategory.system);
      rethrow;
    }
  }
  
  Future<void> _publishContactList(List<String> followingPubkeys) async {
    try {
      final authService = ref.read(authServiceProvider);
      final nostrService = ref.read(nostrServiceProvider);
      
      // Build tags for contact list (NIP-02)
      final tags = followingPubkeys.map((pubkey) => ['p', pubkey]).toList();
      
      // Create Kind 3 event (contact list)
      final event = await authService.createAndSignEvent(
        kind: 3,
        content: '', // Contact lists typically have empty content
        tags: tags,
      );
      
      if (event == null) {
        throw Exception('Failed to create contact list event');
      }
      
      // Broadcast the contact list event
      final result = await nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast contact list: $errorMessages');
      }
      
      // Update current contact list event
      state = state.copyWith(currentUserContactListEvent: event);
      
      Log.debug('Contact list published with ${followingPubkeys.length} contacts', 
                name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error publishing contact list: $e', name: 'SocialProvider', category: LogCategory.system);
      rethrow;
    }
  }
  
  Future<String> _publishRepost(Event eventToRepost) async {
    try {
      final authService = ref.read(authServiceProvider);
      final nostrService = ref.read(nostrServiceProvider);
      
      // Build tags for repost (NIP-18)
      final tags = <List<String>>[
        ['e', eventToRepost.id, '', 'mention'],
        ['p', eventToRepost.pubkey],
      ];
      
      // Add original event kind tag if it's a video
      if (eventToRepost.kind == 22) {
        tags.add(['k', '22']);
      }
      
      // Create Kind 6 event (repost)
      final event = await authService.createAndSignEvent(
        kind: 6,
        content: '', // Content is typically empty for reposts
        tags: tags,
      );
      
      if (event == null) {
        throw Exception('Failed to create repost event');
      }
      
      // Broadcast the repost event
      final result = await nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast repost: $errorMessages');
      }
      
      Log.debug('Repost event broadcasted: ${event.id}', name: 'SocialProvider', category: LogCategory.system);
      return event.id;
    } catch (e) {
      Log.error('Error publishing repost: $e', name: 'SocialProvider', category: LogCategory.system);
      rethrow;
    }
  }
  
  void _processContactListEvent(Event event) {
    if (event.kind != 3) return;
    
    final followingPubkeys = <String>[];
    
    // Extract pubkeys from 'p' tags
    for (final tag in event.tags) {
      if (tag.length >= 2 && tag[0] == 'p') {
        followingPubkeys.add(tag[1]);
      }
    }
    
    // Update state
    state = state.copyWith(
      followingPubkeys: followingPubkeys,
      currentUserContactListEvent: event,
    );
    
    Log.debug('Processed contact list with ${followingPubkeys.length} pubkeys', 
              name: 'SocialProvider', category: LogCategory.system);
  }
  
  Future<void> _loadUserLikedEvents() async {
    final authService = ref.read(authServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);
    
    if (!authService.isAuthenticated || authService.currentPublicKeyHex == null) {
      return;
    }
    
    try {
      Log.debug('Loading user liked events...', name: 'SocialProvider', category: LogCategory.system);
      
      // Query for reaction events (Kind 7) from current user
      final filter = Filter(
        kinds: const [7],
        authors: [authService.currentPublicKeyHex!],
        limit: 500,
        h: ['vine'], // Required for vine.hol.is relay
      );
      
      // Use stream subscription to get events
      final completer = Completer<List<Event>>();
      final events = <Event>[];
      
      final stream = nostrService.subscribeToEvents(filters: [filter]);
      StreamSubscription<Event>? subscription;
      
      final timer = Timer(const Duration(seconds: 5), () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(events);
        }
      });
      
      subscription = stream.listen(
        (event) => events.add(event),
        onDone: () {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(events);
          }
        },
        onError: (error) {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      
      final fetchedEvents = await completer.future;
      subscription.cancel();
      
      final likedEventIds = <String>{};
      final likeEventIdToReactionId = <String, String>{};
      
      for (final event in fetchedEvents) {
        if (event.content == '+') { // Standard like reaction
          // Find the 'e' tag (event being liked)
          for (final tag in event.tags) {
            if (tag.length >= 2 && tag[0] == 'e') {
              final likedEventId = tag[1];
              likedEventIds.add(likedEventId);
              likeEventIdToReactionId[likedEventId] = event.id;
              break;
            }
          }
        }
      }
      
      // Update state
      state = state.copyWith(
        likedEventIds: likedEventIds,
        likeEventIdToReactionId: likeEventIdToReactionId,
      );
      
      Log.info('Loaded ${likedEventIds.length} liked events', name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error loading user liked events: $e', name: 'SocialProvider', category: LogCategory.system);
    }
  }
  
  Future<void> _loadUserRepostedEvents() async {
    final authService = ref.read(authServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);
    
    if (!authService.isAuthenticated || authService.currentPublicKeyHex == null) {
      return;
    }
    
    try {
      Log.debug('Loading user reposted events...', name: 'SocialProvider', category: LogCategory.system);
      
      // Query for repost events (Kind 6) from current user
      final filter = Filter(
        kinds: const [6],
        authors: [authService.currentPublicKeyHex!],
        limit: 500,
        h: ['vine'], // Required for vine.hol.is relay
      );
      
      // Use stream subscription to get events
      final completer = Completer<List<Event>>();
      final events = <Event>[];
      
      final stream = nostrService.subscribeToEvents(filters: [filter]);
      StreamSubscription<Event>? subscription;
      
      final timer = Timer(const Duration(seconds: 5), () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(events);
        }
      });
      
      subscription = stream.listen(
        (event) => events.add(event),
        onDone: () {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete(events);
          }
        },
        onError: (error) {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );
      
      final fetchedEvents = await completer.future;
      subscription.cancel();
      
      final repostedEventIds = <String>{};
      final repostEventIdToRepostId = <String, String>{};
      
      for (final event in fetchedEvents) {
        // Find the 'e' tag (event being reposted)
        for (final tag in event.tags) {
          if (tag.length >= 2 && tag[0] == 'e') {
            final repostedEventId = tag[1];
            repostedEventIds.add(repostedEventId);
            repostEventIdToRepostId[repostedEventId] = event.id;
            break;
          }
        }
      }
      
      // Update state
      state = state.copyWith(
        repostedEventIds: repostedEventIds,
        repostEventIdToRepostId: repostEventIdToRepostId,
      );
      
      Log.info('Loaded ${repostedEventIds.length} reposted events', name: 'SocialProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error loading user reposted events: $e', name: 'SocialProvider', category: LogCategory.system);
    }
  }
  
  void _cleanupSubscriptions() {
    try {
      // Only try to clean up if the ref is still valid
      final subscriptionManager = ref.read(subscriptionManagerProvider);
      
      if (_likeSubscriptionId != null) {
        subscriptionManager.cancelSubscription(_likeSubscriptionId!);
      }
      if (_followSubscriptionId != null) {
        subscriptionManager.cancelSubscription(_followSubscriptionId!);
      }
      if (_repostSubscriptionId != null) {
        subscriptionManager.cancelSubscription(_repostSubscriptionId!);
      }
      if (_userLikesSubscriptionId != null) {
        subscriptionManager.cancelSubscription(_userLikesSubscriptionId!);
      }
      if (_userRepostsSubscriptionId != null) {
        subscriptionManager.cancelSubscription(_userRepostsSubscriptionId!);
      }
    } catch (e) {
      // Container might be disposed, ignore cleanup errors
      Log.debug('Cleanup error during disposal: $e', name: 'SocialProvider', category: LogCategory.system);
    }
  }
}