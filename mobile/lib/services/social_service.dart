// ABOUTME: Social interaction service managing likes, follows, comments and reposts
// ABOUTME: Handles NIP-25 reactions, NIP-02 contact lists, and other social Nostr events

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr/nostr.dart';
import 'nostr_service_interface.dart';
import 'auth_service.dart';

/// Service for managing social interactions on Nostr
class SocialService extends ChangeNotifier {
  final INostrService _nostrService;
  final AuthService _authService;
  
  // Cache for UI state - liked events by current user
  final Set<String> _likedEventIds = <String>{};
  
  // Cache for like counts to avoid redundant network requests
  final Map<String, int> _likeCounts = <String, int>{};
  
  // Cache mapping liked event IDs to their reaction event IDs (needed for deletion)
  final Map<String, String> _likeEventIdToReactionId = <String, String>{};
  
  // Cache for following list (NIP-02 contact list)
  List<String> _followingPubkeys = <String>[];
  
  // Cache for follower/following counts
  final Map<String, Map<String, int>> _followerStats = <String, Map<String, int>>{};
  
  // Current user's latest Kind 3 event for follow list management
  Event? _currentUserContactListEvent;
  
  // Subscription for real-time like updates
  StreamSubscription<Event>? _likeSubscription;
  
  // Subscription for real-time follow list updates
  StreamSubscription<Event>? _followSubscription;
  
  SocialService(this._nostrService, this._authService) {
    _initialize();
  }
  
  /// Initialize the service
  Future<void> _initialize() async {
    debugPrint('🤝 Initializing SocialService');
    
    try {
      // Initialize current user's social data if authenticated
      if (_authService.isAuthenticated) {
        await _loadUserLikedEvents();
        await fetchCurrentUserFollowList();
      }
      
      debugPrint('✅ SocialService initialized');
    } catch (e) {
      debugPrint('❌ SocialService initialization error: $e');
    }
  }
  
  /// Get current user's liked event IDs
  Set<String> get likedEventIds => Set.from(_likedEventIds);
  
  /// Check if current user has liked an event
  bool isLiked(String eventId) {
    return _likedEventIds.contains(eventId);
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
      debugPrint('❌ Cannot like - user not authenticated');
      return;
    }
    
    debugPrint('❤️ Toggling like for event: ${eventId.substring(0, 8)}...');
    
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
          
          debugPrint('✅ Like published for event: ${eventId.substring(0, 8)}...');
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
          
          debugPrint('✅ Unlike (deletion) published for event: ${eventId.substring(0, 8)}...');
        } else {
          debugPrint('⚠️ Cannot unlike - reaction event ID not found');
          
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
      debugPrint('❌ Error toggling like: $e');
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
      
      debugPrint('📡 Like event broadcasted: ${event.id}');
      return event.id;
      
    } catch (e) {
      debugPrint('❌ Error publishing like: $e');
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
      
      debugPrint('📡 Deletion event broadcasted: ${event.id}');
      
    } catch (e) {
      debugPrint('❌ Error publishing deletion: $e');
      rethrow;
    }
  }
  
  /// Fetches like count and determines if current user has liked an event
  /// Returns {'count': int, 'user_liked': bool}
  Future<Map<String, dynamic>> getLikeStatus(String eventId) async {
    debugPrint('📊 Fetching like status for event: ${eventId.substring(0, 8)}...');
    
    try {
      // Check cache first
      final cachedCount = _likeCounts[eventId];
      final userLiked = _likedEventIds.contains(eventId);
      
      if (cachedCount != null) {
        debugPrint('💾 Using cached like count: $cachedCount');
        return {
          'count': cachedCount,
          'user_liked': userLiked,
        };
      }
      
      // Fetch from network
      final likeCount = await _fetchLikeCount(eventId);
      
      // Cache the result
      _likeCounts[eventId] = likeCount;
      
      debugPrint('📊 Like count fetched: $likeCount');
      
      return {
        'count': likeCount,
        'user_liked': userLiked,
      };
      
    } catch (e) {
      debugPrint('❌ Error fetching like status: $e');
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
      
      // Subscribe to Kind 7 reactions for this event
      final subscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [7],
            e: [eventId],
          ),
        ],
      );
      
      // Count the reactions
      final streamSubscription = subscription.listen(
        (event) {
          // Only count '+' reactions as likes
          if (event.content.trim() == '+') {
            likeCount++;
          }
        },
        onError: (error) {
          debugPrint('❌ Error in like count subscription: $error');
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(likeCount);
          }
        },
      );
      
      // Set a timeout to avoid hanging indefinitely
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          streamSubscription.cancel();
          completer.complete(likeCount);
        }
      });
      
      return await completer.future;
      
    } catch (e) {
      debugPrint('❌ Error fetching like count: $e');
      return 0;
    }
  }
  
  /// Loads current user's liked events from their reaction history
  Future<void> _loadUserLikedEvents() async {
    if (!_authService.isAuthenticated) return;
    
    try {
      final currentUserPubkey = _authService.currentPublicKeyHex;
      if (currentUserPubkey == null) return;
      
      debugPrint('📥 Loading user liked events for: ${currentUserPubkey.substring(0, 8)}...');
      
      // Subscribe to current user's reactions (Kind 7)
      final subscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [7],
          ),
        ],
      );
      
      // Process user's reaction events
      subscription.listen(
        (event) {
          // Only process '+' reactions as likes
          if (event.content.trim() == '+') {
            // Extract the liked event ID from 'e' tags
            for (final tag in event.tags) {
              if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
                final likedEventId = tag[1];
                _likedEventIds.add(likedEventId);
                // Store the reaction event ID for future deletion
                _likeEventIdToReactionId[likedEventId] = event.id;
                debugPrint('💾 Cached user like: ${likedEventId.substring(0, 8)}... (reaction: ${event.id.substring(0, 8)}...)');
                break;
              }
            }
          }
        },
        onError: (error) {
          debugPrint('❌ Error loading user likes: $error');
        },
      );
      
    } catch (e) {
      debugPrint('❌ Error loading user liked events: $e');
    }
  }
  
  /// Fetches all events liked by a specific user
  Future<List<Event>> fetchLikedEvents(String pubkey) async {
    debugPrint('📥 Fetching liked events for user: ${pubkey.substring(0, 8)}...');
    
    try {
      final List<Event> likedEvents = [];
      final Set<String> likedEventIds = {};
      
      // First, get all reactions by this user
      final reactionSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [7], // NIP-25 reactions
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
          debugPrint('❌ Error fetching liked events: $error');
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
              debugPrint('❌ Error fetching liked event details: $e');
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
      debugPrint('✅ Fetched ${result.length} liked events');
      return result;
      
    } catch (e) {
      debugPrint('❌ Error fetching liked events: $e');
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
      
      debugPrint('👥 Loading follow list for: ${currentUserPubkey.substring(0, 8)}...');
      
      // Subscribe to current user's Kind 3 events (contact lists)
      final subscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [currentUserPubkey],
            kinds: [3], // NIP-02 contact list
            limit: 1, // Get most recent only
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
          debugPrint('❌ Error loading follow list: $error');
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
      debugPrint('❌ Error fetching follow list: $e');
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
      debugPrint('✅ Updated follow list: ${_followingPubkeys.length} following');
      
      notifyListeners();
    }
  }
  
  /// Follow a user by adding them to the contact list
  Future<void> followUser(String pubkeyToFollow) async {
    if (!_authService.isAuthenticated) {
      debugPrint('❌ Cannot follow - user not authenticated');
      return;
    }
    
    if (_followingPubkeys.contains(pubkeyToFollow)) {
      debugPrint('ℹ️ Already following user: ${pubkeyToFollow.substring(0, 8)}...');
      return;
    }
    
    debugPrint('👥 Following user: ${pubkeyToFollow.substring(0, 8)}...');
    
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
      
      debugPrint('✅ Successfully followed user: ${pubkeyToFollow.substring(0, 8)}...');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      rethrow;
    }
  }
  
  /// Unfollow a user by removing them from the contact list
  Future<void> unfollowUser(String pubkeyToUnfollow) async {
    if (!_authService.isAuthenticated) {
      debugPrint('❌ Cannot unfollow - user not authenticated');
      return;
    }
    
    if (!_followingPubkeys.contains(pubkeyToUnfollow)) {
      debugPrint('ℹ️ Not following user: ${pubkeyToUnfollow.substring(0, 8)}...');
      return;
    }
    
    debugPrint('👥 Unfollowing user: ${pubkeyToUnfollow.substring(0, 8)}...');
    
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
      
      debugPrint('✅ Successfully unfollowed user: ${pubkeyToUnfollow.substring(0, 8)}...');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
      rethrow;
    }
  }
  
  /// Get follower and following counts for a specific pubkey
  Future<Map<String, int>> getFollowerStats(String pubkey) async {
    debugPrint('📊 Fetching follower stats for: ${pubkey.substring(0, 8)}...');
    
    try {
      // Check cache first
      final cachedStats = _followerStats[pubkey];
      if (cachedStats != null) {
        debugPrint('💾 Using cached follower stats: $cachedStats');
        return cachedStats;
      }
      
      // Fetch from network
      final stats = await _fetchFollowerStats(pubkey);
      
      // Cache the result
      _followerStats[pubkey] = stats;
      
      debugPrint('📊 Follower stats fetched: $stats');
      return stats;
      
    } catch (e) {
      debugPrint('❌ Error fetching follower stats: $e');
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
          debugPrint('❌ Error fetching following count: $error');
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
          debugPrint('❌ Error fetching followers count: $error');
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
      debugPrint('❌ Error fetching follower stats: $e');
      return {'followers': 0, 'following': 0};
    }
  }
  
  // === PROFILE STATISTICS ===
  
  /// Get video count for a specific user
  Future<int> getUserVideoCount(String pubkey) async {
    debugPrint('📹 Fetching video count for: ${pubkey.substring(0, 8)}...');
    
    try {
      final completer = Completer<int>();
      int videoCount = 0;
      
      // Subscribe to user's video events (Kind 34550)
      final subscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [34550], // Video events
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
          debugPrint('❌ Error fetching video count: $error');
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
      debugPrint('📹 Video count fetched: $result');
      return result;
      
    } catch (e) {
      debugPrint('❌ Error fetching video count: $e');
      return 0;
    }
  }
  
  /// Get total likes across all videos for a specific user
  Future<int> getUserTotalLikes(String pubkey) async {
    debugPrint('❤️ Fetching total likes for: ${pubkey.substring(0, 8)}...');
    
    try {
      // First, get all video events by this user
      final userVideos = <String>[];
      final videoCompleter = Completer<List<String>>();
      
      final videoSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            authors: [pubkey],
            kinds: [34550], // Video events
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
          debugPrint('❌ Error fetching user videos: $error');
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
        debugPrint('❤️ No videos found, total likes: 0');
        return 0;
      }
      
      debugPrint('📹 Found ${videoIds.length} videos, fetching likes...');
      
      // Now get likes for all these videos
      final likesCompleter = Completer<int>();
      int totalLikes = 0;
      
      final likesSubscription = _nostrService.subscribeToEvents(
        filters: [
          Filter(
            kinds: [7], // Like events
            e: videoIds, // Events that reference our videos
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
          debugPrint('❌ Error fetching likes: $error');
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
      debugPrint('❤️ Total likes fetched: $result');
      return result;
      
    } catch (e) {
      debugPrint('❌ Error fetching total likes: $e');
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
      debugPrint('❌ Cannot post comment - user not authenticated');
      throw Exception('User not authenticated');
    }
    
    if (content.trim().isEmpty) {
      debugPrint('❌ Cannot post empty comment');
      throw Exception('Comment content cannot be empty');
    }
    
    debugPrint('💬 Posting comment to event: ${rootEventId.substring(0, 8)}...');
    
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
      
      debugPrint('✅ Comment posted successfully: ${event.id.substring(0, 8)}...');
      
    } catch (e) {
      debugPrint('❌ Error posting comment: $e');
      rethrow;
    }
  }
  
  /// Fetches all comments for a given root event ID
  Stream<Event> fetchCommentsForEvent(String rootEventId) {
    debugPrint('💬 Fetching comments for event: ${rootEventId.substring(0, 8)}...');
    
    // Create filter for comments
    // Comments are Kind 1 events that have an 'e' tag pointing to the root event
    final filter = Filter(
      kinds: [1], // Text notes
      e: [rootEventId], // Comments that reference this event
    );
    
    // Subscribe to comment events
    return _nostrService.subscribeToEvents(filters: [filter]);
  }
  
  /// Fetches comment count for an event
  Future<int> getCommentCount(String rootEventId) async {
    debugPrint('📊 Fetching comment count for event: ${rootEventId.substring(0, 8)}...');
    
    try {
      final completer = Completer<int>();
      int commentCount = 0;
      
      // Subscribe to comments for this event
      final subscription = fetchCommentsForEvent(rootEventId).listen(
        (event) {
          commentCount++;
        },
        onError: (error) {
          debugPrint('❌ Error fetching comment count: $error');
          if (!completer.isCompleted) {
            completer.complete(0);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(commentCount);
          }
        },
      );
      
      // Set a timeout
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(commentCount);
        }
      });
      
      final result = await completer.future;
      debugPrint('💬 Comment count fetched: $result');
      return result;
      
    } catch (e) {
      debugPrint('❌ Error fetching comment count: $e');
      return 0;
    }
  }
  
  @override
  void dispose() {
    debugPrint('🗑️ Disposing SocialService');
    _likeSubscription?.cancel();
    _followSubscription?.cancel();
    super.dispose();
  }
}