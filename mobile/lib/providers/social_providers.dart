// ABOUTME: Riverpod providers for social service with reactive state management
// ABOUTME: Pure @riverpod functions for social interactions like follows and reposts

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/state/social_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'social_providers.g.dart';

/// Social state notifier with reactive state management
/// keepAlive: true prevents disposal during async initialization and keeps following list cached
@Riverpod(keepAlive: true)
class SocialNotifier extends _$SocialNotifier {
  // Managed subscription IDs
  String? _followSubscriptionId;
  String? _repostSubscriptionId;
  String? _userRepostsSubscriptionId;

  // Save subscription manager for safe disposal
  dynamic _subscriptionManager;

  // Step 3: Idempotency guard to prevent duplicate fetch attempts
  Completer<void>? _contactsFetchInFlight;

  @override
  SocialState build() {
    // Save subscription manager reference before disposal callback
    _subscriptionManager = ref.read(subscriptionManagerProvider);

    // Step 2: Listen to auth state changes and react immediately
    // fireImmediately ensures we catch the current state even if already authenticated
    ref.listen(authServiceProvider, (previous, current) {
      final previousState = previous?.authState;
      final currentState = current.authState;

      Log.info(
        '🔔 SocialNotifier: Auth state transition: ${previousState?.name ?? 'null'} → ${currentState.name}',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      // When auth becomes authenticated, fetch contacts and set up Zendesk identity
      if (currentState == AuthState.authenticated) {
        _ensureContactsFetched();
        // Set up Zendesk identity so bug reports have the user's name
        _ensureZendeskIdentitySet();
      }
    }, fireImmediately: true);

    ref.onDispose(_cleanupSubscriptions);

    return SocialState.initial;
  }

  /// Load following list from local cache
  Future<void> _loadFollowingListFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;

      if (currentUserPubkey != null) {
        final key = 'following_list_$currentUserPubkey';
        final cached = prefs.getString(key);
        if (cached != null) {
          final List<dynamic> decoded = jsonDecode(cached);
          final followingPubkeys = decoded.cast<String>();

          // Update state with cached data immediately
          state = state.copyWith(followingPubkeys: followingPubkeys);

          Log.info(
            '📋 Loaded cached following list: ${followingPubkeys.length} users (in background)',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to load following list from cache: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    }
  }

  /// Save following list to local cache
  Future<void> _saveFollowingListToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authService = ref.read(authServiceProvider);
      final currentUserPubkey = authService.currentPublicKeyHex;

      if (currentUserPubkey != null) {
        final key = 'following_list_$currentUserPubkey';
        await prefs.setString(key, jsonEncode(state.followingPubkeys));
        Log.debug(
          '💾 Saved following list to cache: ${state.followingPubkeys.length} users',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to save following list to cache: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    }
  }

  /// Step 3: Idempotent contact fetch - safe to call multiple times
  /// Handles auth race conditions by checking actual auth state, not boolean
  Future<void> _ensureContactsFetched() async {
    // CRITICAL: Load cache FIRST for instant UI, regardless of auth state
    // This ensures the UI shows cached followers immediately, even if auth is still checking
    await _loadFollowingListFromCache();

    // If already fetching, wait for that operation to complete
    if (_contactsFetchInFlight != null) {
      Log.info(
        '⏳ SocialNotifier: Contact fetch already in progress, waiting...',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return _contactsFetchInFlight!.future;
    }

    // If already initialized with contacts, nothing to do
    if (state.isInitialized && state.followingPubkeys.isNotEmpty) {
      Log.info(
        '✅ SocialNotifier: Contacts already fetched (${state.followingPubkeys.length} following)',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    final authService = ref.read(authServiceProvider);

    // Step 1: Treat checking as "unknown", not false
    // If auth is still checking, we don't know yet - return early
    if (authService.authState == AuthState.checking) {
      Log.info(
        '⏸️ SocialNotifier: Auth state is checking - will retry when authenticated',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    // Step 4: Fix misleading log - distinguish between checking and unauthenticated
    if (authService.authState != AuthState.authenticated) {
      Log.info(
        '❌ SocialNotifier: Not authenticated (state: ${authService.authState.name}) - skipping contact fetch',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    // Create completer to guard against concurrent calls
    _contactsFetchInFlight = Completer<void>();

    try {
      Log.info(
        '🚀 SocialNotifier: Starting contact fetch...',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      Log.info(
        '🤝 SocialNotifier: Fetching contact list for authenticated user (cached: ${state.followingPubkeys.length} users)',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      // Load follow list and user's own reposts in parallel
      await Future.wait([
        _fetchCurrentUserFollowList(),
        _fetchAllUserReposts(), // Bulk load user's own reposts
      ]);

      Log.info(
        '✅ SocialNotifier: Contact list fetch complete, following=${state.followingPubkeys.length}, reposted=${state.repostedEventIds.length}',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      _contactsFetchInFlight!.complete();
    } catch (e) {
      Log.error(
        '❌ SocialNotifier: Contact fetch failed: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      _contactsFetchInFlight!.completeError(e);
    } finally {
      _contactsFetchInFlight = null;
    }
  }

  /// Set up Zendesk user identity when authenticated
  /// This ensures bug reports and support tickets show the user's actual name
  Future<void> _ensureZendeskIdentitySet() async {
    final authService = ref.read(authServiceProvider);

    if (authService.authState != AuthState.authenticated) {
      return;
    }

    final pubkeyHex = authService.currentPublicKeyHex;
    final npub = authService.currentNpub;

    if (pubkeyHex == null || npub == null) {
      Log.warning(
        '⚠️ SocialNotifier: Cannot set Zendesk identity - missing pubkey',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    try {
      // Get user profile for display name and nip05
      final userProfileService = ref.read(userProfileServiceProvider);
      var profile = userProfileService.getCachedProfile(pubkeyHex);

      // If profile not cached, try to fetch it (with short timeout)
      if (profile == null) {
        Log.info(
          '🔍 SocialNotifier: Fetching user profile for Zendesk identity...',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        profile = await userProfileService
            .fetchProfile(pubkeyHex)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
      }

      // Set Zendesk identity with available info
      await ZendeskSupportService.setUserIdentity(
        displayName: profile?.bestDisplayName,
        nip05: profile?.nip05,
        npub: npub,
      );

      Log.info(
        '✅ SocialNotifier: Zendesk identity set - ${profile?.bestDisplayName ?? npub}',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        '⚠️ SocialNotifier: Failed to set Zendesk identity: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    }
  }

  /// Initialize the service
  /// NOTE: Contact fetching now handled by _ensureContactsFetched() called from auth listener
  Future<void> initialize() async {
    if (state.isInitialized) {
      Log.info(
        '🤝 SocialNotifier already initialized with ${state.followingPubkeys.length} following',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      '🤝 Initializing SocialNotifier',
      name: 'SocialNotifier',
      category: LogCategory.system,
    );

    state = state.copyWith(isLoading: true);

    try {
      final authService = ref.read(authServiceProvider);

      // Step 4: Fix misleading log to show actual auth state
      Log.info(
        '🤝 SocialNotifier: Auth state = ${authService.authState.name}, pubkey = ${authService.currentPublicKeyHex ?? 'null'}',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      // Step 1: Use _ensureContactsFetched() which properly handles auth state checking
      // The auth listener will also call this when auth transitions to authenticated
      await _ensureContactsFetched();

      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      Log.info(
        '✅ SocialNotifier initialized successfully with ${state.followingPubkeys.length} following',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        '❌ SocialNotifier initialization error: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Follow a user
  Future<void> followUser(String pubkeyToFollow) async {
    final authService = ref.read(authServiceProvider);

    if (!authService.isAuthenticated) {
      Log.error(
        'Cannot follow - user not authenticated',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    if (state.isFollowing(pubkeyToFollow)) {
      Log.debug(
        'Already following user: $pubkeyToFollow',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    if (state.isFollowInProgress(pubkeyToFollow)) {
      Log.debug(
        'Follow operation already in progress for $pubkeyToFollow',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
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

      // Check if provider was disposed during async operation
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during follow operation - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }

      // Update state
      state = state.copyWith(followingPubkeys: newFollowingList);

      // Save to cache
      _saveFollowingListToCache();

      Log.info(
        'Now following: $pubkeyToFollow',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      // Trigger home feed refresh to show videos from newly followed user
      _refreshHomeFeed();
    } catch (e) {
      Log.error(
        'Error following user: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      // Check if provider was disposed during error handling
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during follow error handling - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      // Check if provider was disposed before cleanup
      if (ref.mounted) {
        // Remove from in-progress set
        final newFollowsInProgress = {...state.followsInProgress}
          ..remove(pubkeyToFollow);
        state = state.copyWith(followsInProgress: newFollowsInProgress);
      }
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String pubkeyToUnfollow) async {
    final authService = ref.read(authServiceProvider);

    if (!authService.isAuthenticated) {
      Log.error(
        'Cannot unfollow - user not authenticated',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    if (!state.isFollowing(pubkeyToUnfollow)) {
      Log.debug(
        'Not following user: $pubkeyToUnfollow',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    if (state.isFollowInProgress(pubkeyToUnfollow)) {
      Log.debug(
        'Follow operation already in progress for $pubkeyToUnfollow',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    // Add to in-progress set
    state = state.copyWith(
      followsInProgress: {...state.followsInProgress, pubkeyToUnfollow},
    );

    try {
      final newFollowingList = state.followingPubkeys
          .where((p) => p != pubkeyToUnfollow)
          .toList();

      // Publish updated contact list
      await _publishContactList(newFollowingList);

      // Check if provider was disposed during async operation
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during unfollow operation - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }

      // Update state
      state = state.copyWith(followingPubkeys: newFollowingList);

      // Save to cache
      _saveFollowingListToCache();

      Log.info(
        'Unfollowed: $pubkeyToUnfollow',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      // Trigger home feed refresh to update feed
      _refreshHomeFeed();
    } catch (e) {
      Log.error(
        'Error unfollowing user: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      // Check if provider was disposed during error handling
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during unfollow error handling - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      // Check if provider was disposed before cleanup
      if (ref.mounted) {
        // Remove from in-progress set
        final newFollowsInProgress = {...state.followsInProgress}
          ..remove(pubkeyToUnfollow);
        state = state.copyWith(followsInProgress: newFollowsInProgress);
      }
    }
  }

  /// Toggle repost on/off for a video event (repost/unrepost)
  Future<void> toggleRepost(VideoEvent video) async {
    final authService = ref.read(authServiceProvider);

    if (!authService.isAuthenticated) {
      Log.error(
        'Cannot toggle repost - user not authenticated',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    final eventId = video.id;

    // Check if operation is already in progress
    if (state.isRepostInProgress(eventId)) {
      Log.debug(
        'Repost operation already in progress for $eventId',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    Log.debug(
      '🔄 Toggling repost for event: ${eventId}...',
      name: 'SocialNotifier',
      category: LogCategory.system,
    );

    // Add to in-progress set
    state = state.copyWith(
      repostsInProgress: {...state.repostsInProgress, eventId},
    );

    try {
      final wasReposted = state.hasReposted(eventId);

      if (!wasReposted) {
        // Repost the video
        final socialService = ref.read(socialServiceProvider);
        await socialService.toggleRepost(video);

        // Check if provider was disposed during async operation
        if (!ref.mounted) {
          Log.warning(
            'Provider disposed during repost operation - aborting',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );
          return;
        }

        // Update state - add to reposted set
        final addressableId =
            '${NIP71VideoKinds.addressableShortVideo}:${video.pubkey}:${video.rawTags['d']}';
        state = state.copyWith(
          repostedEventIds: {...state.repostedEventIds, addressableId},
        );

        Log.info(
          'Repost published for video: ${eventId}...',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
      } else {
        // Unrepost the video
        final socialService = ref.read(socialServiceProvider);
        await socialService.toggleRepost(video);

        // Check if provider was disposed during async operation
        if (!ref.mounted) {
          Log.warning(
            'Provider disposed during unrepost operation - aborting',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );
          return;
        }

        // Update state - remove from reposted set
        final addressableId =
            '${NIP71VideoKinds.addressableShortVideo}:${video.pubkey}:${video.rawTags['d']}';
        final newRepostedEventIds = {...state.repostedEventIds}
          ..remove(addressableId);

        state = state.copyWith(repostedEventIds: newRepostedEventIds);

        Log.info(
          'Unrepost published for video: ${eventId}...',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Error toggling repost: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      // Check if provider was disposed during error handling
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during repost error handling - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      // Check if provider was disposed before cleanup
      if (ref.mounted) {
        // Remove from in-progress set
        final newRepostsInProgress = {...state.repostsInProgress}
          ..remove(eventId);
        state = state.copyWith(repostsInProgress: newRepostsInProgress);
      }
    }
  }

  /// Fetch current user's follow list
  Future<void> _fetchCurrentUserFollowList() async {
    final authService = ref.read(authServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);

    if (!authService.isAuthenticated ||
        authService.currentPublicKeyHex == null) {
      Log.warning(
        'Cannot fetch follow list - user not authenticated',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    try {
      Log.info(
        '📋 Fetching current user follow list for: ${authService.currentPublicKeyHex!}...',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      // Query for Kind 3 events (contact lists) from current user
      final filter = Filter(
        kinds: const [3],
        authors: [authService.currentPublicKeyHex!],
        limit: 1,
      );

      // Use stream subscription to get events
      final completer = Completer<List<Event>>();
      final events = <Event>[];
      StreamSubscription<Event>? subscription;

      // Set up a timer to complete after getting at least one event or timeout
      Timer? timer;

      void completeAndCleanup() {
        timer?.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(events);
        }
      }

      final stream = nostrService.subscribe([filter]);
      subscription = stream.listen(
        (event) {
          // Check if provider was disposed before processing
          if (!ref.mounted) {
            Log.warning(
              'Provider disposed before contact list event processing - aborting',
              name: 'SocialNotifier',
              category: LogCategory.system,
            );
            completeAndCleanup();
            return;
          }

          Log.debug(
            '📋 Received contact list event: ${event.id}...',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );

          // Process contact list event immediately
          _processContactListEvent(event);

          // Add to events list for potential sorting
          events.add(event);

          Log.info(
            '✅ Processed contact list with ${state.followingPubkeys.length} following immediately',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );

          // Complete immediately after processing first contact list event
          completeAndCleanup();
        },
        onDone: () {
          Log.debug(
            '📋 Stream completed - contact list subscription remains open for real-time updates',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );
          // Don't complete here - let timeout handle it if no events received
          if (events.isEmpty) {
            completeAndCleanup();
          }
        },
        onError: (error) {
          Log.error(
            '📋 Stream error: $error',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Set timeout timer
      timer = Timer(const Duration(seconds: 10), () {
        Log.warning(
          '📋 Contact list fetch timeout after 10 seconds with ${events.length} events',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        completeAndCleanup();
      });

      // Wait for events
      final fetchedEvents = await completer.future;

      // Check if provider was disposed during async operation
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during contact list fetch - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }

      if (fetchedEvents.isNotEmpty) {
        // Get the most recent contact list event
        fetchedEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latestContactList = fetchedEvents.first;

        _processContactListEvent(latestContactList);

        Log.info(
          'Loaded ${state.followingPubkeys.length} following pubkeys',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );

        // Log first few pubkeys for debugging
        if (state.followingPubkeys.isNotEmpty) {
          final preview = state.followingPubkeys.take(3).join(', ');
          final suffix = state.followingPubkeys.length > 3 ? '...' : '';
          Log.debug(
            'Following pubkeys sample: $preview$suffix',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );
        }
      } else {
        Log.info(
          'No contact list found for current user',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Error fetching follow list: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      // Check if provider was disposed during async operation
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during error handling - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }
      state = state.copyWith(error: e.toString());
    }
  }

  /// Fetch all user's reposts in bulk on startup
  /// Note: Likes are now fetched by LikesProvider via LikesRepository
  Future<void> _fetchAllUserReposts() async {
    final authService = ref.read(authServiceProvider);
    final nostrService = ref.read(nostrServiceProvider);

    if (!authService.isAuthenticated ||
        authService.currentPublicKeyHex == null) {
      return;
    }

    try {
      Log.info(
        '📥 Fetching all user reposts',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );

      final repostFilter = Filter(
        kinds: const [16], // Generic reposts (NIP-18)
        authors: [authService.currentPublicKeyHex!],
        limit: 500, // Get last 500 reposts
      );

      final completer = Completer<void>();
      final repostEvents = <Event>[];

      final stream = nostrService.subscribe([repostFilter]);

      late final StreamSubscription<Event> subscription;

      // Set timeout for bulk fetch
      final timer = Timer(const Duration(seconds: 5), () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      subscription = stream.listen(
        (event) {
          if (event.kind == 16) {
            repostEvents.add(event);
          }
        },
        onDone: () {
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          Log.error(
            'Error fetching user reposts: $error',
            name: 'SocialNotifier',
            category: LogCategory.system,
          );
          timer.cancel();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      await completer.future;

      // Check if provider was disposed during async operation
      if (!ref.mounted) {
        Log.warning(
          'Provider disposed during reposts fetch - aborting',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }

      // Process reposts
      final repostedEventIds = <String>{};
      final repostEventIdToRepostId = <String, String>{};

      for (final event in repostEvents) {
        // Find the 'e' tag which references the reposted event
        final eTags = event.tags.where(
          (tag) => tag.length >= 2 && tag[0] == 'e',
        );
        if (eTags.isNotEmpty) {
          final repostedEventId = eTags.first[1];
          repostedEventIds.add(repostedEventId);
          repostEventIdToRepostId[repostedEventId] = event.id;
        }
      }

      // Update state with reposts
      state = state.copyWith(
        repostedEventIds: repostedEventIds,
        repostEventIdToRepostId: repostEventIdToRepostId,
      );

      Log.info(
        '✅ Loaded ${repostedEventIds.length} reposts',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error fetching user reposts: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    }
  }

  // Private helper methods

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

      // Publish the contact list event
      final sentEvent = await nostrService.publishEvent(event);

      if (sentEvent == null) {
        throw Exception('Failed to publish contact list to relays');
      }

      // Update current contact list event
      state = state.copyWith(currentUserContactListEvent: event);

      Log.debug(
        'Contact list published with ${followingPubkeys.length} contacts',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error publishing contact list: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  void _processContactListEvent(Event event) {
    if (event.kind != 3) {
      Log.warning(
        '📋 Received non-contact list event: kind=${event.kind}',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      '📋 Processing contact list event: ${event.id}... with ${event.tags.length} tags',
      name: 'SocialNotifier',
      category: LogCategory.system,
    );

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

    // Save to cache for next startup
    _saveFollowingListToCache();

    Log.info(
      '✅ Processed contact list with ${followingPubkeys.length} pubkeys',
      name: 'SocialNotifier',
      category: LogCategory.system,
    );

    // Log sample of following list
    if (followingPubkeys.isNotEmpty) {
      final sample = followingPubkeys.take(5).map((p) => p).join(', ');
      Log.info(
        '👥 Following sample: $sample${followingPubkeys.length > 5 ? "..." : ""}',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    }
  }

  /// Trigger home feed refresh after follow/unfollow
  void _refreshHomeFeed() {
    try {
      ref.invalidate(homeFeedProvider);
      Log.debug(
        '🔄 Home feed invalidated after follow change',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to refresh home feed: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    }
  }

  void _cleanupSubscriptions() {
    try {
      // Use saved subscription manager reference instead of ref.read()
      // CRITICAL: Never use ref.read() in disposal callbacks
      if (_subscriptionManager == null) {
        Log.warning(
          'Subscription manager not available for cleanup',
          name: 'SocialNotifier',
          category: LogCategory.system,
        );
        return;
      }

      if (_followSubscriptionId != null) {
        _subscriptionManager.cancelSubscription(_followSubscriptionId!);
      }
      if (_repostSubscriptionId != null) {
        _subscriptionManager.cancelSubscription(_repostSubscriptionId!);
      }
      if (_userRepostsSubscriptionId != null) {
        _subscriptionManager.cancelSubscription(_userRepostsSubscriptionId!);
      }
    } catch (e) {
      // Container might be disposed, ignore cleanup errors
      Log.debug(
        'Cleanup error during disposal: $e',
        name: 'SocialNotifier',
        category: LogCategory.system,
      );
    }
  }
}
