// ABOUTME: Social interaction service managing likes, follows, comments and reposts
// ABOUTME: Handles NIP-25 reactions, NIP-02 contact lists, and other social Nostr events

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'nostr_service_interface.dart';
import 'auth_service.dart';
import 'subscription_manager.dart';
import '../utils/unified_logger.dart';

/// Service for managing social interactions on Nostr
class SocialService extends ChangeNotifier {
  final INostrService _nostrService;
  final AuthService _authService;
  final SubscriptionManager _subscriptionManager;
  
  // Cache for UI state - liked events by current user
  final Set<String> _likedEventIds = <String>{};
  
  // Cache for like counts to avoid redundant network requests
  final Map<String, int> _likeCounts = <String, int>{};
  
  // Cache mapping liked event IDs to their reaction event IDs (needed for deletion)
  final Map<String, String> _likeEventIdToReactionId = <String, String>{};
  
  // Cache for UI state - reposted events by current user
  final Set<String> _repostedEventIds = <String>{};
  
  // Cache mapping reposted event IDs to their repost event IDs (needed for deletion)
  final Map<String, String> _repostEventIdToRepostId = <String, String>{};
  
  // Cache for following list (NIP-02 contact list)
  List<String> _followingPubkeys = <String>[];
  
  // Cache for follower/following counts
  final Map<String, Map<String, int>> _followerStats = <String, Map<String, int>>{};
  
  // Current user's latest Kind 3 event for follow list management
  Event? _currentUserContactListEvent;
  
  // Managed subscription IDs
  String? _likeSubscriptionId;
  String? _followSubscriptionId;
  String? _repostSubscriptionId;
  String? _userLikesSubscriptionId;
  String? _userRepostsSubscriptionId;
  
  SocialService(this._nostrService, this._authService, {required SubscriptionManager subscriptionManager}) 
      : _subscriptionManager = subscriptionManager {
    _initialize();
  }
  
  /// Initialize the service
  Future<void> _initialize() async {
    Log.debug('🤝 Initializing SocialService', name: 'SocialService', category: LogCategory.system);
    
    try {
      // Initialize current user's social data if authenticated
      if (_authService.isAuthenticated) {
        await _loadUserLikedEvents();
        await _loadUserRepostedEvents();
        await fetchCurrentUserFollowList();
      }
      
      Log.info('SocialService initialized', name: 'SocialService', category: LogCategory.system);
    } catch (e) {
      Log.error('SocialService initialization error: $e', name: 'SocialService', category: LogCategory.system);
    }
  }
  
  /// Get current user's liked event IDs
  Set<String> get likedEventIds => Set.from(_likedEventIds);
  
  /// Check if current user has liked an event
  bool isLiked(String eventId) {
    return _likedEventIds.contains(eventId);
  }
  
  /// Check if current user has reposted an event
  bool hasReposted(String eventId) {
    return _repostedEventIds.contains(eventId);
  }
  
  /// Get cached like count for an event
  int? getCachedLikeCount(String eventId) {
    return _likeCounts[eventId];
  }
  
  // === FOLLOW SYSTEM GETTERS ===
  
  /// Get current user's following list
  List<String> get followingPubkeys => List.from(_followingPubkeys);
  
  /// Check if current user is following a specific pubkey
  bool isFollowing(String pubkey) {
    return _followingPubkeys.contains(pubkey);
  }
  
  /// Get cached follower stats for a pubkey
  Map<String, int>? getCachedFollowerStats(String pubkey) {
    return _followerStats[pubkey];
  }
  
  /// Likes or unlikes a Nostr event using proper NIP-09 deletion
  Future<void> toggleLike(String eventId, String authorPubkey) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot like - user not authenticated', name: 'SocialService', category: LogCategory.system);
      return;
    }
    
    Log.debug('❤️ Toggling like for event: ${eventId.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      final wasLiked = _likedEventIds.contains(eventId);
      
      if (!wasLiked) {
        // Add like
        final reactionEventId = await _publishLike(eventId, authorPubkey);
        
        if (reactionEventId != null) {
          // Update local state immediately for UI responsiveness
          _likedEventIds.add(eventId);
          _likeEventIdToReactionId[eventId] = reactionEventId;
          
          // Increment like count in cache
          final currentCount = _likeCounts[eventId] ?? 0;
          _likeCounts[eventId] = currentCount + 1;
          
          Log.info('Like published for event: ${eventId.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
        }
      } else {
        // Unlike by publishing NIP-09 deletion event
        final reactionEventId = _likeEventIdToReactionId[eventId];
        if (reactionEventId != null) {
          await _publishUnlike(reactionEventId);
          
          // Update local state
          _likedEventIds.remove(eventId);
          _likeEventIdToReactionId.remove(eventId);
          
          // Decrement like count in cache
          final currentCount = _likeCounts[eventId] ?? 0;
          if (currentCount > 0) {
            _likeCounts[eventId] = currentCount - 1;
          }
          
          Log.info('Unlike (deletion) published for event: ${eventId.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
        } else {
          Log.warning('Cannot unlike - reaction event ID not found', name: 'SocialService', category: LogCategory.system);
          
          // Fallback: remove from local state only
          _likedEventIds.remove(eventId);
          final currentCount = _likeCounts[eventId] ?? 0;
          if (currentCount > 0) {
            _likeCounts[eventId] = currentCount - 1;
          }
        }
      }
      
      notifyListeners();
      
    } catch (e) {
      Log.error('Error toggling like: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Publishes a NIP-25 reaction event (like) and returns the reaction event ID
  Future<String?> _publishLike(String eventId, String authorPubkey) async {
    try {
      // Create NIP-25 reaction event (Kind 7)
      final event = await _authService.createAndSignEvent(
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
      final result = await _nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast like event: $errorMessages');
      }
      
      Log.debug('Like event broadcasted: ${event.id}', name: 'SocialService', category: LogCategory.system);
      return event.id;
      
    } catch (e) {
      Log.error('Error publishing like: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Publishes a NIP-09 deletion event for unlike functionality
  Future<void> _publishUnlike(String reactionEventId) async {
    try {
      // Create NIP-09 deletion event (Kind 5)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content: 'Unliked', // Optional deletion reason
        tags: [
          ['e', reactionEventId], // Reference to the reaction event to delete
        ],
      );
      
      if (event == null) {
        throw Exception('Failed to create deletion event');
      }
      
      // Broadcast the deletion event
      final result = await _nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast deletion event: $errorMessages');
      }
      
      Log.debug('Deletion event broadcasted: ${event.id}', name: 'SocialService', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Error publishing deletion: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Fetches like count and determines if current user has liked an event
  /// Returns {'count': int, 'user_liked': bool}
  Future<Map<String, dynamic>> getLikeStatus(String eventId) async {
    Log.debug('Fetching like status for event: ${eventId.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // Check cache first
      final cachedCount = _likeCounts[eventId];
      final userLiked = _likedEventIds.contains(eventId);
      
      if (cachedCount != null) {
        Log.debug('� Using cached like count: $cachedCount', name: 'SocialService', category: LogCategory.system);
        return {
          'count': cachedCount,
          'user_liked': userLiked,
        };
      }
      
      // Fetch from network
      final likeCount = await _fetchLikeCount(eventId);
      
      // Cache the result
      _likeCounts[eventId] = likeCount;
      
      Log.debug('Like count fetched: $likeCount', name: 'SocialService', category: LogCategory.system);
      
      return {
        'count': likeCount,
        'user_liked': userLiked,
      };
      
    } catch (e) {
      Log.error('Error fetching like status: $e', name: 'SocialService', category: LogCategory.system);
      return {
        'count': 0,
        'user_liked': false,
      };
    }
  }
  
  /// Fetches like count for a specific event
  Future<int> _fetchLikeCount(String eventId) async {
    try {
      final completer = Completer<int>();
      int likeCount = 0;
      
      // Subscribe to Kind 7 reactions for this event using SubscriptionManager
      final subscriptionId = await _subscriptionManager.createSubscription(
        name: 'like_count_${eventId.substring(0, 8)}',
        filters: [
          Filter(
            kinds: [7],
            e: [eventId],
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
        onEvent: (event) {
          // Only count '+' reactions as likes
          if (event.content.trim() == '+') {
            likeCount++;
          }
        },
        onError: (error) {
          Log.error('Error in like count subscription: $error', name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete(likeCount);
          }
        },
        timeout: const Duration(seconds: 5),
        priority: 4, // Lower priority for count queries
      );
      
      return await completer.future;
      
    } catch (e) {
      Log.error('Error fetching like count: $e', name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }
  
  /// Loads current user's liked events from their reaction history
  Future<void> _loadUserLikedEvents() async {
    if (!_authService.isAuthenticated) return;
    
    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;
      
      Log.debug('Loading user liked events for: ${currentUserPubkey.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      
      // Subscribe to current user's reactions (Kind 7) using SubscriptionManager
      _userLikesSubscriptionId = await _subscriptionManager.createSubscription(
        name: 'user_likes_${currentUserPubkey.substring(0, 8)}',
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [7],
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
        onEvent: (event) {
          // Only process '+' reactions as likes
          if (event.content.trim() == '+') {
            // Extract the liked event ID from 'e' tags
            for (final tag in event.tags) {
              if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
                final likedEventId = tag[1];
                _likedEventIds.add(likedEventId);
                // Store the reaction event ID for future deletion
                _likeEventIdToReactionId[likedEventId] = event.id;
                Log.debug('� Cached user like: ${likedEventId.substring(0, 8)}... (reaction: ${event.id.substring(0, 8)}...)', name: 'SocialService', category: LogCategory.system);
                break;
              }
            }
          }
        },
        onError: (error) => Log.error('Error loading user likes: $error', name: 'SocialService', category: LogCategory.system),
        priority: 3, // Lower priority for historical data
      );
      
    } catch (e) {
      Log.error('Error loading user liked events: $e', name: 'SocialService', category: LogCategory.system);
    }
  }
  
  /// Loads current user's reposted events from their repost history
  Future<void> _loadUserRepostedEvents() async {
    if (!_authService.isAuthenticated) return;
    
    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;
      
      Log.debug('Loading user reposted events for: ${currentUserPubkey.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      
      // Subscribe to current user's reposts (Kind 6) using SubscriptionManager
      _userRepostsSubscriptionId = await _subscriptionManager.createSubscription(
        name: 'user_reposts_${currentUserPubkey.substring(0, 8)}',
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [6],
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
        onEvent: (event) {
          // Extract the reposted event ID from 'e' tags
          for (final tag in event.tags) {
            if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
              final repostedEventId = tag[1];
              _repostedEventIds.add(repostedEventId);
              // Store the repost event ID for future deletion
              _repostEventIdToRepostId[repostedEventId] = event.id;
              Log.debug('� Cached user repost: ${repostedEventId.substring(0, 8)}... (repost: ${event.id.substring(0, 8)}...)', name: 'SocialService', category: LogCategory.system);
              break;
            }
          }
          notifyListeners(); // Notify UI of repost changes
        },
        onError: (error) => Log.error('Error loading user reposts: $error', name: 'SocialService', category: LogCategory.system),
        priority: 3, // Lower priority for historical data
      );
      
    } catch (e) {
      Log.error('Error loading user reposted events: $e', name: 'SocialService', category: LogCategory.system);
    }
  }
  
  /// Fetches all events liked by a specific user
  Future<List<Event>> fetchLikedEvents(String pubkey) async {
    Log.debug('Fetching liked events for user: ${pubkey.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      final List<Event> likedEvents = [];
      final Set<String> likedEventIds = {};
      
      // First, get all reactions by this user
      final reactionSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [7], // NIP-25 reactions
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
      );
      
      final completer = Completer<List<Event>>();
      
      // Collect liked event IDs
      reactionSubscription.listen(
        (reactionEvent) {
          if (reactionEvent.content.trim() == '+') {
            // Extract liked event ID from 'e' tag
            for (final tag in reactionEvent.tags) {
              if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
                likedEventIds.add(tag[1]);
                break;
              }
            }
          }
        },
        onError: (error) {
          Log.error('Error fetching liked events: $error', name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete([]);
          }
        },
        onDone: () async {
          // Now fetch the actual liked events
          if (likedEventIds.isNotEmpty) {
            try {
              final eventSubscription = _nostrService.subscribeToEvents(
                filters: [
                  Filter(
                    ids: likedEventIds.toList(),
                    h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
                  ),
                ],
              );
              
              eventSubscription.listen(
                (event) {
                  likedEvents.add(event);
                },
                onDone: () {
                  if (!completer.isCompleted) {
                    completer.complete(likedEvents);
                  }
                },
              );
              
              // Timeout for event fetching
              Timer(const Duration(seconds: 5), () {
                if (!completer.isCompleted) {
                  completer.complete(likedEvents);
                }
              });
              
            } catch (e) {
              Log.error('Error fetching liked event details: $e', name: 'SocialService', category: LogCategory.system);
              if (!completer.isCompleted) {
                completer.complete([]);
              }
            }
          } else {
            if (!completer.isCompleted) {
              completer.complete([]);
            }
          }
        },
      );
      
      // Timeout for reaction fetching
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      });
      
      final result = await completer.future;
      Log.info('Fetched ${result.length} liked events', name: 'SocialService', category: LogCategory.system);
      return result;
      
    } catch (e) {
      Log.error('Error fetching liked events: $e', name: 'SocialService', category: LogCategory.system);
      return [];
    }
  }
  
  // === NIP-02 FOLLOW SYSTEM ===
  
  /// Fetches current user's follow list from their latest Kind 3 event
  Future<void> fetchCurrentUserFollowList() async {
    if (!_authService.isAuthenticated) return;
    
    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;
      
      Log.debug('� Loading follow list for: ${currentUserPubkey.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      
      // Subscribe to current user's Kind 3 events (contact lists)
      final subscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [3], // NIP-02 contact list
            limit: 1, // Get most recent only
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
      );
      
      final completer = Completer<void>();
      
      // Process user's contact list events
      subscription.listen(
        (event) {
          _processContactListEvent(event);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          Log.error('Error loading follow list: $error', name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );
      
      // Timeout after 5 seconds
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      
      await completer.future;
      
    } catch (e) {
      Log.error('Error fetching follow list: $e', name: 'SocialService', category: LogCategory.system);
    }
  }
  
  /// Process a NIP-02 contact list event (Kind 3)
  void _processContactListEvent(Event event) {
    // Only update if this is newer than our current contact list event
    if (_currentUserContactListEvent == null || 
        event.createdAt > _currentUserContactListEvent!.createdAt) {
      
      _currentUserContactListEvent = event;
      
      // Extract followed pubkeys from 'p' tags
      final followedPubkeys = <String>[];
      for (final tag in event.tags) {
        if (tag.isNotEmpty && tag[0] == 'p' && tag.length > 1) {
          followedPubkeys.add(tag[1]);
        }
      }
      
      _followingPubkeys = followedPubkeys;
      Log.info('Updated follow list: ${_followingPubkeys.length} following', name: 'SocialService', category: LogCategory.system);
      
      notifyListeners();
    }
  }
  
  /// Follow a user by adding them to the contact list
  Future<void> followUser(String pubkeyToFollow) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot follow - user not authenticated', name: 'SocialService', category: LogCategory.system);
      return;
    }
    
    if (_followingPubkeys.contains(pubkeyToFollow)) {
      Log.debug('ℹ️ Already following user: ${pubkeyToFollow.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      return;
    }
    
    Log.debug('� Following user: ${pubkeyToFollow.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // Add to current follow list
      final updatedFollowList = List<String>.from(_followingPubkeys)..add(pubkeyToFollow);
      
      // Create new Kind 3 event with updated follow list
      final tags = updatedFollowList.map((pubkey) => ['p', pubkey]).toList();
      
      // Preserve existing content from previous contact list event if available
      final content = _currentUserContactListEvent?.content ?? '';
      
      final event = await _authService.createAndSignEvent(
        kind: 3,
        content: content,
        tags: tags,
      );
      
      if (event == null) {
        throw Exception('Failed to create contact list event');
      }
      
      // Broadcast the updated contact list
      final result = await _nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast contact list: $errorMessages');
      }
      
      // Update local state immediately for UI responsiveness
      _followingPubkeys = updatedFollowList;
      _currentUserContactListEvent = event;
      
      Log.info('Successfully followed user: ${pubkeyToFollow.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      notifyListeners();
      
    } catch (e) {
      Log.error('Error following user: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Unfollow a user by removing them from the contact list
  Future<void> unfollowUser(String pubkeyToUnfollow) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot unfollow - user not authenticated', name: 'SocialService', category: LogCategory.system);
      return;
    }
    
    if (!_followingPubkeys.contains(pubkeyToUnfollow)) {
      Log.debug('ℹ️ Not following user: ${pubkeyToUnfollow.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      return;
    }
    
    Log.debug('� Unfollowing user: ${pubkeyToUnfollow.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // Remove from current follow list
      final updatedFollowList = List<String>.from(_followingPubkeys)..remove(pubkeyToUnfollow);
      
      // Create new Kind 3 event with updated follow list
      final tags = updatedFollowList.map((pubkey) => ['p', pubkey]).toList();
      
      // Preserve existing content from previous contact list event if available
      final content = _currentUserContactListEvent?.content ?? '';
      
      final event = await _authService.createAndSignEvent(
        kind: 3,
        content: content,
        tags: tags,
      );
      
      if (event == null) {
        throw Exception('Failed to create contact list event');
      }
      
      // Broadcast the updated contact list
      final result = await _nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast contact list: $errorMessages');
      }
      
      // Update local state immediately for UI responsiveness
      _followingPubkeys = updatedFollowList;
      _currentUserContactListEvent = event;
      
      Log.info('Successfully unfollowed user: ${pubkeyToUnfollow.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      notifyListeners();
      
    } catch (e) {
      Log.error('Error unfollowing user: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Get follower and following counts for a specific pubkey
  Future<Map<String, int>> getFollowerStats(String pubkey) async {
    Log.debug('Fetching follower stats for: ${pubkey.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // Check cache first
      final cachedStats = _followerStats[pubkey];
      if (cachedStats != null) {
        Log.debug('� Using cached follower stats: $cachedStats', name: 'SocialService', category: LogCategory.system);
        return cachedStats;
      }
      
      // Fetch from network
      final stats = await _fetchFollowerStats(pubkey);
      
      // Cache the result
      _followerStats[pubkey] = stats;
      
      Log.debug('Follower stats fetched: $stats', name: 'SocialService', category: LogCategory.system);
      return stats;
      
    } catch (e) {
      Log.error('Error fetching follower stats: $e', name: 'SocialService', category: LogCategory.system);
      return {'followers': 0, 'following': 0};
    }
  }
  
  /// Fetch follower stats from the network
  Future<Map<String, int>> _fetchFollowerStats(String pubkey) async {
    try {
      final completer = Completer<Map<String, int>>();
      int followingCount = 0;
      int followersCount = 0;
      bool followingFetched = false;
      bool followersFetched = false;
      
      void checkComplete() {
        if (followingFetched && followersFetched && !completer.isCompleted) {
          completer.complete({
            'followers': followersCount,
            'following': followingCount,
          });
        }
      }
      
      // 1. Get following count: Find user's latest Kind 3 event and count p tags
      final followingSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [3],
            limit: 1,
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
      );
      
      followingSubscription.listen(
        (event) {
          // Count p tags in the contact list
          followingCount = event.tags.where((tag) => tag.isNotEmpty && tag[0] == 'p').length;
        },
        onDone: () {
          followingFetched = true;
          checkComplete();
        },
        onError: (error) {
          Log.error('Error fetching following count: $error', name: 'SocialService', category: LogCategory.system);
          followingFetched = true;
          checkComplete();
        },
      );
      
      // 2. Get followers count: Find all Kind 3 events that include this pubkey in p tags
      final followersSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [3],
            p: [pubkey], // Events that mention this pubkey in p tags
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
      );
      
      final followerPubkeys = <String>{};
      followersSubscription.listen(
        (event) {
          // Each unique author who has this pubkey in their contact list is a follower
          followerPubkeys.add(event.pubkey);
        },
        onDone: () {
          followersCount = followerPubkeys.length;
          followersFetched = true;
          checkComplete();
        },
        onError: (error) {
          Log.error('Error fetching followers count: $error', name: 'SocialService', category: LogCategory.system);
          followersFetched = true;
          checkComplete();
        },
      );
      
      // Set a timeout to avoid hanging indefinitely
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.complete({
            'followers': followersCount,
            'following': followingCount,
          });
        }
      });
      
      return await completer.future;
      
    } catch (e) {
      Log.error('Error fetching follower stats: $e', name: 'SocialService', category: LogCategory.system);
      return {'followers': 0, 'following': 0};
    }
  }
  
  // === PROFILE STATISTICS ===
  
  /// Get video count for a specific user
  Future<int> getUserVideoCount(String pubkey) async {
    Log.debug('� Fetching video count for: ${pubkey.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      final completer = Completer<int>();
      int videoCount = 0;
      
      // Subscribe to user's video events (Kind 22 - NIP-71)
      final subscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [22], // NIP-71 short video events
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
      );
      
      subscription.listen(
        (event) {
          videoCount++;
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(videoCount);
          }
        },
        onError: (error) {
          Log.error('Error fetching video count: $error', name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
      );
      
      // Set a timeout to avoid hanging indefinitely
      Timer(const Duration(seconds: 8), () {
        if (!completer.isCompleted) {
          completer.complete(videoCount);
        }
      });
      
      final result = await completer.future;
      Log.debug('� Video count fetched: $result', name: 'SocialService', category: LogCategory.system);
      return result;
      
    } catch (e) {
      Log.error('Error fetching video count: $e', name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }
  
  /// Get total likes across all videos for a specific user
  Future<int> getUserTotalLikes(String pubkey) async {
    Log.debug('❤️ Fetching total likes for: ${pubkey.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // First, get all video events by this user
      final userVideos = <String>[];
      final videoCompleter = Completer<List<String>>();
      
      final videoSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [22], // NIP-71 short video events
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
      );
      
      videoSubscription.listen(
        (event) {
          userVideos.add(event.id);
        },
        onDone: () {
          if (!videoCompleter.isCompleted) {
            videoCompleter.complete(userVideos);
          }
        },
        onError: (error) {
          Log.error('Error fetching user videos: $error', name: 'SocialService', category: LogCategory.system);
          if (!videoCompleter.isCompleted) {
            videoCompleter.complete([]);
          }
        },
      );
      
      // Timeout for video fetching
      Timer(const Duration(seconds: 8), () {
        if (!videoCompleter.isCompleted) {
          videoCompleter.complete(userVideos);
        }
      });
      
      final videoIds = await videoCompleter.future;
      
      if (videoIds.isEmpty) {
        Log.info('❤️ No videos found, total likes: 0', name: 'SocialService', category: LogCategory.system);
        return 0;
      }
      
      Log.info('� Found ${videoIds.length} videos, fetching likes...', name: 'SocialService', category: LogCategory.system);
      
      // Now get likes for all these videos
      final likesCompleter = Completer<int>();
      int totalLikes = 0;
      
      final likesSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [7], // Like events
            e: videoIds, // Events that reference our videos
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
          ),
        ],
      );
      
      likesSubscription.listen(
        (event) {
          // Only count '+' reactions as likes
          if (event.content.trim() == '+') {
            totalLikes++;
          }
        },
        onDone: () {
          if (!likesCompleter.isCompleted) {
            likesCompleter.complete(totalLikes);
          }
        },
        onError: (error) {
          Log.error('Error fetching likes: $error', name: 'SocialService', category: LogCategory.system);
          if (!likesCompleter.isCompleted) {
            likesCompleter.complete(totalLikes);
          }
        },
      );
      
      // Timeout for likes fetching
      Timer(const Duration(seconds: 10), () {
        if (!likesCompleter.isCompleted) {
          likesCompleter.complete(totalLikes);
        }
      });
      
      final result = await likesCompleter.future;
      Log.debug('❤️ Total likes fetched: $result', name: 'SocialService', category: LogCategory.system);
      return result;
      
    } catch (e) {
      Log.error('Error fetching total likes: $e', name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }
  
  // === COMMENT SYSTEM ===
  
  /// Posts a comment in reply to a root event (video)
  Future<void> postComment({
    required String content,
    required String rootEventId,
    required String rootEventAuthorPubkey,
    String? replyToEventId,
    String? replyToAuthorPubkey,
  }) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot post comment - user not authenticated', name: 'SocialService', category: LogCategory.system);
      throw Exception('User not authenticated');
    }
    
    if (content.trim().isEmpty) {
      Log.error('Cannot post empty comment', name: 'SocialService', category: LogCategory.system);
      throw Exception('Comment content cannot be empty');
    }
    
    Log.debug('� Posting comment to event: ${rootEventId.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // We don't need the keyPair directly since createAndSignEvent handles signing
      
      // Create tags for the comment
      final tags = <List<String>>[];
      
      // Always include root event tag (the video being commented on)
      tags.add(['e', rootEventId, '', 'root']);
      
      // Tag the root event author
      tags.add(['p', rootEventAuthorPubkey]);
      
      // If this is a reply to another comment, add reply tags
      if (replyToEventId != null) {
        tags.add(['e', replyToEventId, '', 'reply']);
        
        if (replyToAuthorPubkey != null) {
          tags.add(['p', replyToAuthorPubkey]);
        }
      }
      
      // Create the comment event (Kind 1 text note)
      final event = await _authService.createAndSignEvent(
        kind: 1, // Text note
        tags: tags,
        content: content.trim(),
      );
      
      if (event == null) {
        throw Exception('Failed to create comment event');
      }
      
      // Broadcast the comment
      final result = await _nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast comment: $errorMessages');
      }
      
      Log.info('Comment posted successfully: ${event.id.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Error posting comment: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Fetches all comments for a given root event ID
  Stream<Event> fetchCommentsForEvent(String rootEventId) {
    Log.debug('� Fetching comments for event: ${rootEventId.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    // Create filter for comments
    // Comments are Kind 1 events that have an 'e' tag pointing to the root event
    final filter = Filter(
      kinds: [1], // Text notes
      e: [rootEventId], // Comments that reference this event
      h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
    );
    
    // Create a StreamController to emit events
    final controller = StreamController<Event>();
    
    // Create managed subscription for comments
    _subscriptionManager.createSubscription(
      name: 'comments_${rootEventId.substring(0, 8)}',
      filters: [
        Filter(
          kinds: filter.kinds,
          e: filter.e,
          h: filter.h,
          limit: 50, // Limit comment fetching
        ),
      ],
      onEvent: (event) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
      onComplete: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
      timeout: const Duration(minutes: 2), // Shorter timeout for comments
      priority: 6, // Lower priority for comments
    ).catchError((error) {
      Log.error('Failed to create comment subscription: $error', name: 'SocialService', category: LogCategory.system);
      if (!controller.isClosed) {
        controller.addError(error);
      }
    });
    
    return controller.stream;
  }
  
  /// Fetches comment count for an event
  Future<int> getCommentCount(String rootEventId) async {
    Log.debug('Fetching comment count for event: ${rootEventId.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      final completer = Completer<int>();
      int commentCount = 0;
      
      // Create a dedicated comment count subscription with higher priority and shorter timeout
      final subscriptionId = await _subscriptionManager.createSubscription(
        name: 'comment_count_${rootEventId.substring(0, 8)}',
        filters: [
          Filter(
            kinds: [1], // Text notes
            e: [rootEventId], // Comments that reference this event
            h: ['vine'], // REQUIRED: vine.hol.is relay only stores events with this tag
            limit: 100, // Reasonable limit for counting
          ),
        ],
        onEvent: (event) {
          commentCount++;
        },
        onError: (error) {
          Log.error('Error fetching comment count: $error', name: 'SocialService', category: LogCategory.system);
          if (!completer.isCompleted) {
            completer.complete(commentCount);
          }
        },
        onComplete: () {
          if (!completer.isCompleted) {
            completer.complete(commentCount);
          }
        },
        timeout: const Duration(seconds: 5), // Short timeout for count
        priority: 5, // Higher priority for counts
      );
      
      // Set a backup timeout
      Timer(const Duration(seconds: 6), () {
        if (!completer.isCompleted) {
          _subscriptionManager.cancelSubscription(subscriptionId);
          completer.complete(commentCount);
        }
      });
      
      final result = await completer.future;
      Log.debug('� Comment count fetched: $result', name: 'SocialService', category: LogCategory.system);
      return result;
      
    } catch (e) {
      Log.error('Error fetching comment count: $e', name: 'SocialService', category: LogCategory.system);
      return 0;
    }
  }
  
  /// Cancel comment subscriptions for a specific video (call when video scrolls out of view)
  Future<void> cancelCommentSubscriptions(String rootEventId) async {
    final shortId = rootEventId.substring(0, 8);
    await _subscriptionManager.cancelSubscriptionsByName('comments_$shortId');
    await _subscriptionManager.cancelSubscriptionsByName('comment_count_$shortId');
    Log.debug('🗑️ Cancelled comment subscriptions for: $shortId', name: 'SocialService', category: LogCategory.system);
  }
  
  // === REPOST SYSTEM (NIP-18) ===
  
  /// Reposts a Nostr event (Kind 6)
  Future<void> repostEvent(Event eventToRepost) async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot repost - user not authenticated', name: 'SocialService', category: LogCategory.system);
      throw Exception('User not authenticated');
    }
    
    Log.debug('Reposting event: ${eventToRepost.id.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // Create NIP-18 repost event (Kind 6)
      final event = await _authService.createAndSignEvent(
        kind: 6, // Repost event
        content: '', // Content is typically empty for reposts
        tags: [
          ['e', eventToRepost.id], // Reference to reposted event
          ['p', eventToRepost.pubkey], // Reference to original author
        ],
      );
      
      if (event == null) {
        throw Exception('Failed to create repost event');
      }
      
      // Broadcast the repost event
      final result = await _nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast repost: $errorMessages');
      }
      
      // Track the repost locally
      _repostedEventIds.add(eventToRepost.id);
      _repostEventIdToRepostId[eventToRepost.id] = event.id;
      
      Log.info('Event reposted successfully: ${event.id.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      notifyListeners(); // Notify UI of the change
      
    } catch (e) {
      Log.error('Error reposting event: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Publishes a NIP-62 "right to be forgotten" deletion request event
  Future<void> publishRightToBeForgotten() async {
    if (!_authService.isAuthenticated) {
      Log.error('Cannot publish deletion request - user not authenticated', name: 'SocialService', category: LogCategory.system);
      throw Exception('User not authenticated');
    }
    
    Log.debug('�️ Publishing NIP-62 right to be forgotten event...', name: 'SocialService', category: LogCategory.system);
    
    try {
      // Create NIP-62 deletion request event (Kind 5 with special formatting)
      final event = await _authService.createAndSignEvent(
        kind: 5,
        content: 'REQUEST: Delete all data associated with this pubkey under right to be forgotten',
        tags: [
          ['p', _authService.currentPublicKeyHex!], // Reference to own pubkey
          ['k', '0'], // Request deletion of Kind 0 (profile) events
          ['k', '1'], // Request deletion of Kind 1 (text note) events  
          ['k', '3'], // Request deletion of Kind 3 (contact list) events
          ['k', '6'], // Request deletion of Kind 6 (repost) events
          ['k', '7'], // Request deletion of Kind 7 (reaction) events
          ['k', '22'], // Request deletion of Kind 22 (video) events
        ],
      );
      
      if (event == null) {
        throw Exception('Failed to create deletion request event');
      }
      
      // Broadcast the deletion request
      final result = await _nostrService.broadcastEvent(event);
      
      if (!result.isSuccessful) {
        final errorMessages = result.errors.values.join(', ');
        throw Exception('Failed to broadcast deletion request: $errorMessages');
      }
      
      Log.info('NIP-62 deletion request published: ${event.id.substring(0, 8)}...', name: 'SocialService', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Error publishing deletion request: $e', name: 'SocialService', category: LogCategory.system);
      rethrow;
    }
  }

  @override
  void dispose() {
    Log.debug('�️ Disposing SocialService', name: 'SocialService', category: LogCategory.system);
    
    // Cancel all managed subscriptions
    if (_likeSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_likeSubscriptionId!);
      _likeSubscriptionId = null;
    }
    if (_followSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_followSubscriptionId!);
      _followSubscriptionId = null;
    }
    if (_repostSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_repostSubscriptionId!);
      _repostSubscriptionId = null;
    }
    if (_userLikesSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_userLikesSubscriptionId!);
      _userLikesSubscriptionId = null;
    }
    if (_userRepostsSubscriptionId != null) {
      _subscriptionManager.cancelSubscription(_userRepostsSubscriptionId!);
      _userRepostsSubscriptionId = null;
    }
    
    super.dispose();
  }
}