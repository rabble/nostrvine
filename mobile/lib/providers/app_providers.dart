// ABOUTME: Comprehensive Riverpod providers for all application services
// ABOUTME: Replaces Provider MultiProvider setup with pure Riverpod dependency injection

import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:categories_repository/categories_repository.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:curation_repository/curation_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart' show NostrClient;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/services/blocklist_content_filter.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/collaborator_invite_local_state_adapter.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/search_utils.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

export 'auth_providers.dart';
export 'moderation_providers.dart';
export 'nostr_apps_providers.dart';
export 'notifications_providers.dart';
export 'permissions_providers.dart';
export 'preferences_providers.dart';
export 'relay_providers.dart';
export 'upload_media_providers.dart';
export 'video_providers.dart';

part 'app_providers.g.dart';

BlockedVideoFilter createBlockedAuthorFilter(Ref ref) {
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final flagService = ref.watch(featureFlagServiceProvider);
  if (flagService.isEnabled(FeatureFlag.contentPolicyV2)) {
    final engine = ref.watch(contentPolicyEngineProvider);
    return createPolicyEngineFilter(
      engine,
      () => blocklistRepository.currentState,
    );
  }

  return createBlocklistFilter(blocklistRepository);
}

final collaboratorResponseServiceProvider =
    Provider<CollaboratorResponseService>((ref) {
      return CollaboratorResponseService(
        authService: ref.watch(authServiceProvider),
        nostrClient: ref.watch(nostrServiceProvider),
      );
    });

final collaboratorInviteStateStoreProvider =
    Provider<CollaboratorInviteStateStore>((ref) {
      return CollaboratorInviteStateStore(
        prefs: ref.watch(sharedPreferencesProvider),
      );
    });

/// Per-video collaborator confirmation status. Returns `null` until
/// [nostrSessionProvider] has a ready active client, so consumers render a safe
/// fallback instead of capturing a stale Nostr client.
final collaboratorConfirmationRepositoryProvider =
    Provider<CollaboratorConfirmationRepository?>((ref) {
      final authService = ref.watch(authServiceProvider);
      final readiness = ref.watch(nostrSessionProvider);
      final currentUserPubkey = readiness.pubkey;
      final nostrClient = readiness.client;
      if (!readiness.isReadyForActiveClient ||
          currentUserPubkey == null ||
          currentUserPubkey.isEmpty ||
          nostrClient == null ||
          authService.currentIdentity?.pubkey != currentUserPubkey) {
        return null;
      }

      final localStore = ref.watch(collaboratorInviteStateStoreProvider);
      final repo = CollaboratorConfirmationRepository(
        nostrClient: nostrClient,
        localStateReader: CollaboratorInviteLocalStateAdapter(localStore),
        currentUserPubkey: currentUserPubkey,
      );
      ref.onDispose(repo.close);
      return repo;
    });

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return BadgeRepository(
    nostrClient: ref.watch(nostrServiceProvider),
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    currentPubkey: () => authService.currentPublicKeyHex,
    signEvent: authService.createAndSignEvent,
  );
});

// =============================================================================
// FOUNDATIONAL SERVICES (No dependencies)
// =============================================================================

/// Pending action service for offline sync of social actions
/// Returns null when not authenticated (no userPubkey available)
@Riverpod(keepAlive: true)
PendingActionService? pendingActionService(Ref ref) {
  final connectionStatusService = ref.watch(connectionStatusServiceProvider);
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild when authentication changes
  ref.watch(currentAuthStateProvider);

  // Need authenticated user for DAO operations
  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) {
    return null;
  }

  final db = ref.watch(databaseProvider);

  final service = PendingActionService(
    connectionStatusService: connectionStatusService,
    pendingActionsDao: db.pendingActionsDao,
    userPubkey: userPubkey,
  );

  // Initialize asynchronously
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize PendingActionService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.onDispose(service.dispose);
  return service;
}

/// Auto-sweep service for the durable `outgoing_dms` queue.
///
/// Listens to app-foreground transitions and re-publishes the missing
/// self-wrap for any row in `recipient: sent / self: failed` state via
/// [DmRepository.recoverSelfWrap]. Closes the gap left by the
/// SnackBar-only manual retry from PR #4106 — see issue #4124.
///
/// The service is keepAlive but has no UI consumer, so it is read
/// eagerly at app shell startup (`main.dart`) so the foreground
/// subscription is wired up.
///
/// Returns null when the user is not authenticated or when the current Nostr
/// session is not ready — the underlying [DmRepository.recoverSelfWrap]
/// requires `setCredentials` to have run, and gating here is cleaner than
/// catching `StateError` in every sweep pass.
@Riverpod(keepAlive: true)
OutgoingDmRetryService? outgoingDmRetryService(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild on sign-in / sign-out / account switch.
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) return null;

  // Gate on matching Nostr readiness so DmRepository.setCredentials has run by
  // the time the service's first foreground sweep fires.
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  final dmRepository = ref.watch(dmRepositoryProvider);
  final db = ref.watch(databaseProvider);

  // Bridge the synchronous AppForeground notifier into a Stream<bool>
  // so the service's contract stays free of Riverpod types and is easy
  // to drive from unit tests.
  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  final service = OutgoingDmRetryService(
    dmRepository: dmRepository,
    outgoingDmsDao: db.outgoingDmsDao,
    userPubkey: userPubkey,
    appForegroundStream: foregroundController.stream,
  );

  // initialize() subscribes to the controller's stream synchronously
  // (no await before the .listen call), so it is safe to register the
  // ref.listen below afterwards — fireImmediately will reach the
  // service's subscriber.
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize OutgoingDmRetryService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (!foregroundController.isClosed) {
      foregroundController.add(next);
    }
  }, fireImmediately: true);

  ref.onDispose(service.dispose);
  return service;
}

/// Analytics service with opt-out support.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].
@Riverpod(keepAlive: true) // Keep alive to maintain singleton behavior
AnalyticsService analyticsService(Ref ref) {
  final viewPublisher = ref.watch(viewEventPublisherProvider);
  final service = AnalyticsService(viewEventPublisher: viewPublisher);

  // Ensure cleanup on disposal
  ref.onDispose(service.dispose);

  // Initialize asynchronously but don't block the provider
  Future.microtask(service.initialize);

  return service;
}

/// Hashtag cache service for persistent hashtag storage
@riverpod
HashtagCacheService hashtagCacheService(Ref ref) {
  final service = HashtagCacheService();
  // Initialize asynchronously to avoid blocking UI
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize HashtagCacheService',
      name: 'AppProviders',
      error: e,
    );
  });
  return service;
}

/// Draft storage service for persisting vine drafts
@riverpod
DraftStorageService draftStorageService(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Rebuild when account changes so ownerPubkey stays current
  ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  return DraftStorageService(
    draftsDao: db.draftsDao,
    clipsDao: db.clipsDao,
    ownerPubkey: authService.currentPublicKeyHex,
  );
}

/// Clip library service for persisting individual video clips
@riverpod
ClipLibraryService clipLibraryService(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Rebuild when account changes so ownerPubkey stays current
  ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  return ClipLibraryService(
    clipsDao: db.clipsDao,
    draftsDao: db.draftsDao,
    ownerPubkey: authService.currentPublicKeyHex,
  );
}

// (Removed duplicate legacy provider for StreamUploadService)

// =============================================================================
// DEPENDENT SERVICES (With dependencies)
// =============================================================================

/// User data cleanup service for handling identity changes
/// Prevents data leakage between different Nostr accounts
@riverpod
UserDataCleanupService userDataCleanupService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final db = ref.watch(databaseProvider);
  final service = UserDataCleanupService(prefs);

  // Wire database cleanup callback so signOut() clears DM and notification data.
  // Stop DM listening FIRST to prevent in-flight event handlers from writing
  // to tables that are being cleared (H3 race condition fix).
  //
  // When [deleteUserData] is true (destructive sign-out or identity change),
  // also deletes per-user DAO rows scoped by [userPubkey].
  // Non-destructive sign-out (account switch) skips per-user deletion since
  // those rows are already scoped by ownerPubkey.
  service.onDatabaseCleanup =
      ({String? userPubkey, bool deleteUserData = false}) async {
        try {
          await ref.read(dmRepositoryProvider).stopListening();
        } catch (_) {
          // DmRepository may not exist yet (e.g., first launch).
        }
        await db.directMessagesDao.clearAll();
        await db.conversationsDao.clearAll();
        await db.notificationsDao.clearAll();
        await NotificationServiceEnhanced.instance.clearAllData();
        // Clear DM sync cursors so the next login triggers a full re-fetch
        // from relays instead of using stale `since:` boundaries.
        await DmSyncState(prefs).clearAll();

        // Per-user data cleanup (#2999): only on destructive paths
        if (deleteUserData && userPubkey != null) {
          Future<void> safeDelete(
            String name,
            Future<int> Function() fn,
          ) async {
            try {
              await fn();
            } catch (e) {
              Log.warning(
                'Failed to clean $name for $userPubkey: $e',
                name: 'UserDataCleanup',
                category: LogCategory.auth,
              );
            }
          }

          await safeDelete(
            'drafts',
            () => db.draftsDao.deleteAllForUser(userPubkey),
          );
          await safeDelete(
            'clips',
            () => db.clipsDao.deleteAllForUser(userPubkey),
          );
          await safeDelete(
            'pendingUploads',
            () => db.pendingUploadsDao.deleteAllForUser(userPubkey),
          );
          await safeDelete(
            'personalReactions',
            () => db.personalReactionsDao.deleteAllForUser(userPubkey),
          );
          await safeDelete(
            'personalReposts',
            () => db.personalRepostsDao.deleteAllForUser(userPubkey),
          );
          await safeDelete(
            'pendingActions',
            () => db.pendingActionsDao.clearAll(userPubkey),
          );
          await safeDelete(
            'outgoingDms',
            () => db.outgoingDmsDao.clearAllForUser(userPubkey),
          );
        }
      };

  // Wire legacy row claim callback so session setup can attribute
  // pre-multi-account drafts/clips to the current user.
  service.onClaimLegacyRows = (String userPubkey) async {
    await db.draftsDao.claimLegacyRows(userPubkey);
    await db.clipsDao.claimLegacyRows(userPubkey);
  };

  return service;
}

/// Hashtag service depends on Video event service and cache service
@riverpod
HashtagService hashtagService(Ref ref) {
  final videoEventService = ref.watch(videoEventServiceProvider);
  final cacheService = ref.watch(hashtagCacheServiceProvider);
  return HashtagService(videoEventService, cacheService);
}

/// Social service for follow sets (NIP-51 Kind 30000).
///
/// Follower count stats have moved to [FollowRepository].
@Riverpod(keepAlive: true)
SocialService socialService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return SocialService(nostrService, authService);
}

/// Cached following list loaded directly from SharedPreferences.
///
/// Available immediately after authentication (no NostrClient needed).
/// This provides the follow list from the previous session for instant
/// feed display. The full FollowRepository will update this when ready.
@Riverpod(keepAlive: true)
List<String> cachedFollowingList(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final pubkey = authService.currentPublicKeyHex;
  if (pubkey == null || pubkey.isEmpty) return const [];

  final prefs = ref.watch(sharedPreferencesProvider);
  final key = 'following_list_$pubkey';
  final cached = prefs.getString(key);
  if (cached == null) return const [];

  try {
    final decoded = jsonDecode(cached) as List<dynamic>;
    return decoded.cast<String>();
  } catch (e) {
    return const [];
  }
}

/// Provider for FollowRepository instance
///
/// Creates a FollowRepository for managing follow relationships.
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalEventCacheService (for caching contact list events)
@Riverpod(keepAlive: true)
FollowRepository followRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);
  final authService = ref.watch(authServiceProvider);

  // Get FunnelcakeApiClient for direct API access
  final funnelcakeApiClient = ref.watch(funnelcakeApiClientProvider);

  final env = ref.watch(currentEnvironmentProvider);

  final profileStatsDao = ref.watch(databaseProvider).profileStatsDao;

  final repository = FollowRepository(
    nostrClient: nostrClient,
    isCacheInitialized: () => personalEventCache.isInitialized,
    getCachedEventsByKind: personalEventCache.getEventsByKind,
    cacheUserEvent: personalEventCache.cacheUserEvent,
    funnelcakeApiClient: funnelcakeApiClient,
    profileStatsDao: profileStatsDao,
    indexerRelayUrls: env.indexerRelays,
    queryContactList: ContactListCompletionHelper.queryContactList,
    isOnline: () =>
        connectionStatus.isOnline && authService.canPublishNostrWritesNow,
    queueOfflineAction: pendingActionService != null
        ? ({required bool isFollow, required String pubkey}) async {
            await pendingActionService.queueAction(
              type: isFollow
                  ? PendingActionType.follow
                  : PendingActionType.unfollow,
              targetId: pubkey,
            );
          }
        : null,
  );

  // Register executors with pending action service for sync
  if (pendingActionService != null) {
    pendingActionService.registerExecutor(
      PendingActionType.follow,
      (action) => repository.executeFollowAction(action.targetId),
    );
    pendingActionService.registerExecutor(
      PendingActionType.unfollow,
      (action) => repository.executeUnfollowAction(action.targetId),
    );
  }

  // Initialize asynchronously
  repository.initialize().catchError((e) {
    Log.error(
      'Failed to initialize FollowRepository',
      name: 'AppProviders',
      error: e,
    );
  });

  // Listen for Nostr session readiness changes to re-initialize when keys become
  // available. This handles the case where the provider was created before keys
  // were loaded.
  ref.listen<NostrSessionReadiness>(nostrSessionProvider, (previous, next) {
    if (!(previous?.isReadyForActiveClient ?? false) &&
        next.isReadyForActiveClient &&
        !repository.isInitialized) {
      Log.info(
        'NostrClient became ready, re-initializing FollowRepository',
        name: 'AppProviders',
        category: LogCategory.system,
      );
      repository.initialize().catchError((e) {
        Log.error(
          'Failed to re-initialize FollowRepository after keys ready',
          name: 'AppProviders',
          error: e,
        );
      });
    }
  });

  ref.onDispose(repository.dispose);

  return repository;
}

/// Provider for [CuratedListRepository] instance.
///
/// Creates a repository that exposes subscribed curated lists via a
/// [BehaviorSubject] stream for reactive BLoC subscription. Data is
/// bridged from the legacy [CuratedListService] via [setSubscribedLists]
/// until the repository owns its own persistence (Phase 1b).
@Riverpod(keepAlive: true)
CuratedListRepository curatedListRepository(Ref ref) {
  final repository = CuratedListRepository(
    nostrClient: ref.watch(nostrServiceProvider),
    funnelcakeApiClient: ref.watch(funnelcakeApiClientProvider),
    blockFilter: createBlockedAuthorFilter(ref),
  );

  // Bridge: push curated list updates from legacy service into repository
  ref.listen(curatedListsStateProvider, (_, next) {
    next.whenData((_) {
      final service = ref.read(curatedListsStateProvider.notifier).service;
      repository.setSubscribedLists(
        service == null ? const [] : subscribedListsForHomeBridge(service),
      );
    });
  });

  ref.onDispose(repository.dispose);
  return repository;
}

@visibleForTesting
List<CuratedList> subscribedListsForHomeBridge(CuratedListService service) =>
    service.subscribedLists;

/// Provider for HashtagRepository instance.
///
/// Creates a HashtagRepository for searching hashtags via the Funnelcake API.
@riverpod
HashtagRepository hashtagRepository(Ref ref) {
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
  final hashtagService = ref.watch(hashtagServiceProvider);

  // Ensure static hashtags are loaded before any local search callback runs.
  // loadTopHashtags is idempotent and no-ops if already loaded.
  TopHashtagsService.instance.loadTopHashtags();

  return HashtagRepository(
    funnelcakeApiClient: funnelcakeClient,
    localSearch: (query, limit) {
      final results = <String>[];

      void addMatches(Iterable<String> matches) {
        for (final hashtag in matches) {
          if (results.contains(hashtag)) continue;
          results.add(hashtag);
          if (results.length >= limit) break;
        }
      }

      addMatches(hashtagService.searchHashtags(query));
      if (results.length < limit) {
        addMatches(
          TopHashtagsService.instance.searchHashtags(query, limit: limit),
        );
      }

      return results;
    },
  );
}

/// Provider for CategoriesRepository instance.
///
/// Keep-alive so the categories cache survives tab and screen transitions.
@Riverpod(keepAlive: true)
CategoriesRepository categoriesRepository(Ref ref) {
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
  return CategoriesRepository(funnelcakeApiClient: funnelcakeClient);
}

/// Provider for ProfileRepository instance
///
/// Creates a ProfileRepository for managing user profiles (Kind 0 metadata).
/// Requires authentication.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - FunnelcakeApiClient for fast REST-based profile search
@Riverpod(keepAlive: true)
ProfileRepository? profileRepository(Ref ref) {
  // Return null until the signer-backed NostrClient is ready for the active
  // identity. This prevents races where auth state is authenticated before the
  // client has rebuilt with the new keys.
  if (!ref.watch(nostrSessionProvider).isReadyForActiveClient) {
    return null;
  }

  final nostrClient = ref.watch(nostrServiceProvider);
  final userProfilesDao = ref.watch(databaseProvider).userProfilesDao;
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);

  final env = ref.watch(currentEnvironmentProvider);

  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

  final featureFlagService = ref.watch(featureFlagServiceProvider);
  final BlockedProfileFilter blockFilter;
  if (featureFlagService.isEnabled(FeatureFlag.contentPolicyV2)) {
    final engine = ref.watch(contentPolicyEngineProvider);
    blockFilter = (pubkey) {
      final decision = engine.evaluate(
        PolicyInput(pubkey: pubkey),
        blocklistRepository.currentState,
      );
      return decision is Block;
    };
  } else {
    blockFilter = blocklistRepository.shouldFilterFromFeeds;
  }

  final repo = ProfileRepository(
    nostrClient: nostrClient,
    userProfilesDao: userProfilesDao,
    profileStatsDao: ref.watch(databaseProvider).profileStatsDao,
    httpClient: Client(),
    funnelcakeApiClient: funnelcakeClient,
    indexerRelays: env.indexerRelays,
    profileSearchFilter: (query, profiles) =>
        SearchUtils.searchProfiles(query, profiles, limit: 50),
    blockFilter: blockFilter,
  );

  // Pre-load known cached pubkeys and wire into SubscriptionManager
  // so Kind 0 relay requests skip already-cached authors.
  unawaited(
    repo.loadKnownCachedPubkeys().then((_) {
      ref
          .read(subscriptionManagerProvider)
          .setCacheLookup(hasProfileCached: repo.hasProfile);
    }),
  );

  return repo;
}

// VideoManagerService removed - using pure Riverpod VideoManager provider instead

/// Curation Service - manages NIP-51 video curation sets
@Riverpod(keepAlive: true)
CurationRepository curationRepository(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final likesRepository = ref.watch(likesRepositoryProvider);
  final authService = ref.watch(authServiceProvider);

  return CurationRepository(
    nostrService: nostrService,
    videoEventCache: videoEventService,
    likesRepository: likesRepository,
    signer: authService.requireIdentity,
    divineTeamPubkeys: AppConstants.divineTeamPubkeys,
  );
}

// Legacy ExploreVideoManager removed - functionality replaced by pure Riverpod video providers

/// Content reporting service for NIP-56 compliance
@riverpod
Future<ContentReportingService> contentReportingService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final env = ref.watch(currentEnvironmentProvider);
  final service = ContentReportingService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
    moderationRelayUrl: env.relayUrl,
  );

  // Initialize the service to enable reporting
  await service.initialize();

  return service;
}

// In app_providers.dart

/// Lists state notifier - manages curated lists state
@riverpod
class CuratedListsState extends _$CuratedListsState {
  CuratedListService? _service;

  CuratedListService? get service => _service;

  @override
  Future<List<CuratedList>> build() async {
    final nostrService = ref.watch(nostrServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final prefs = ref.watch(sharedPreferencesProvider);

    _service = CuratedListService(
      nostrService: nostrService,
      authService: authService,
      prefs: prefs,
    );

    // Register dispose callback BEFORE async gap to avoid "ref already disposed" error
    ref.onDispose(() => _service?.removeListener(_onServiceChanged));

    // Initialize the service to create default list and sync with relays
    await _service!.initialize();

    // Check if provider was disposed during initialization
    if (!ref.mounted) return [];

    // Listen to changes and update state
    _service!.addListener(_onServiceChanged);

    return _service!.lists;
  }

  void _onServiceChanged() {
    // When service calls notifyListeners(), update the state
    state = AsyncValue.data(_service!.lists);
  }
}

/// Name of the Hive box used for caching NIP-51 kind 30000 people lists.
const String _peopleListsBoxName = 'people_lists_v1';

/// Repository for NIP-51 kind 30000 people lists.
///
/// Wires the shared [NostrClient] (via [nostrServiceProvider]) into a
/// [PeopleListsRepositoryImpl] backed by a [LocalPeopleListsCache] that opens
/// a lazily-created `hive_ce` box named [_peopleListsBoxName]. The repository
/// itself has no Flutter dependencies; this provider owns all UI glue.
@Riverpod(keepAlive: true)
PeopleListsRepository peopleListsRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final cache = LocalPeopleListsCache(
    openBox: () => Hive.openBox<dynamic>(_peopleListsBoxName),
  );

  return PeopleListsRepositoryImpl(
    nostrClient: nostrClient,
    cache: cache,
    blockFilter: createBlockedAuthorFilter(ref),
  );
}

/// Bookmark service for NIP-51 bookmarks
@riverpod
Future<BookmarkService> bookmarkService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  return BookmarkService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
  );
}

/// Mute service for NIP-51 mute lists
@riverpod
Future<MuteService> muteService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  return MuteService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
  );
}

/// Content deletion service for NIP-09 delete events
@riverpod
Future<ContentDeletionService> contentDeletionService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = ContentDeletionService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
  );

  // Initialize the service to enable content deletion
  await service.initialize();

  return service;
}

/// Bug report service for collecting diagnostics and sending encrypted reports
@riverpod
BugReportService bugReportService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);

  final nip17Service = NIP17MessageService(
    signer: nostrService.signer,
    senderPublicKey: nostrService.publicKey,
    nostrService: nostrService,
  );

  final blossomService = ref.watch(blossomUploadServiceProvider);

  return BugReportService(
    nip17MessageService: nip17Service,
    blossomUploadService: blossomService,
  );
}

// =============================================================================
// DM REPOSITORY
// =============================================================================

/// Provider for NIP-17 DM repository.
///
/// Creates a [DmRepository] that handles receiving, decrypting, persisting,
/// and sending encrypted direct messages. Works with any [NostrSigner]
/// (local keys, Keycast RPC, Amber, etc.).
///
/// Sets auth credentials eagerly so read/send operations work immediately,
/// then starts the gift-wrap subscription so DMs are ingested for the whole
/// authenticated session — not just while [InboxPage] is mounted (#2931).
///
/// Cold-start cost is bounded by two existing mechanisms that landed with
/// the original lazy-inbox work (#2766):
/// - The `since: newestSyncedAt - 2d` filter in [DmRepository.startListening]
///   limits the relay backlog to recent events on every open after the first.
/// - Decryption is offloaded to a background isolate via
///   `dm_decryption_worker.dart`, keeping the UI thread responsive.
///
/// Uses `keepAlive: true` because the repository must survive transient
/// dependency rebuilds (e.g. `nostrSessionProvider` readiness changes,
/// `nostrServiceProvider` auth-state changes).
///
/// Non-nullable: the repository works without keys at construction time.
/// Read operations return cached/empty data; write operations check keys.
@Riverpod(keepAlive: true)
DmRepository dmRepository(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  final repository = DmRepository(
    nostrClient: nostrService,
    directMessagesDao: db.directMessagesDao,
    conversationsDao: db.conversationsDao,
    outgoingDmsDao: db.outgoingDmsDao,
    syncState: DmSyncState(prefs),
    errorReporter: (error, stackTrace, {required site}) {
      unawaited(
        CrashReportingService.instance.recordError(
          error,
          stackTrace,
          reason: 'DmRepository.$site',
        ),
      );
    },
  );

  ref.onDispose(repository.stopListening);

  // Set credentials and open the gift-wrap subscription as soon as the
  // signer is ready. The subscription is auth-session-scoped (not inbox-
  // scoped) so DMs are ingested even when the user never visits /inbox.
  // See docs/plans/2026-04-05-dm-scaling-fix-design.md and #2931.
  if (ref.watch(nostrSessionProvider).isReadyForActiveClient) {
    final publicKey = nostrService.publicKey;
    if (publicKey.isNotEmpty) {
      final signer = nostrService.signer;

      repository.setCredentials(
        userPubkey: publicKey,
        signer: signer,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: publicKey,
          nostrService: nostrService,
        ),
      );

      // Open the gift-wrap subscription for the whole authenticated
      // session. Bounded by `since: newestSyncedAt - 2d` and isolate
      // decrypt so cold start stays cheap regardless of lifetime DM count.
      unawaited(repository.startListening());
    }
  }

  return repository;
}

// =============================================================================
// COMMENTS REPOSITORY
// =============================================================================

/// Provider for CommentsRepository instance
///
/// Creates a CommentsRepository for managing comments on events.
/// Viewing comments works without authentication.
/// Posting comments requires authentication (handled by AuthService in BLoC).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
@Riverpod(keepAlive: true)
CommentsRepository commentsRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
  final flagService = ref.watch(featureFlagServiceProvider);
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

  final BlockedCommentFilter blockFilter;
  if (flagService.isEnabled(FeatureFlag.contentPolicyV2)) {
    final engine = ref.watch(contentPolicyEngineProvider);
    blockFilter = (pubkey) {
      final decision = engine.evaluate(
        PolicyInput(pubkey: pubkey),
        blocklistRepository.currentState,
      );
      return decision is Block;
    };
  } else {
    blockFilter = blocklistRepository.shouldFilterFromFeeds;
  }

  final repository = CommentsRepository(
    nostrClient: nostrClient,
    funnelcakeApiClient: funnelcakeClient,
    blockFilter: blockFilter,
  );
  ref.onDispose(repository.clearCommentCountCache);
  return repository;
}
