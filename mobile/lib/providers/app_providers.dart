// ABOUTME: Comprehensive Riverpod providers for all application services
// ABOUTME: Replaces Provider MultiProvider setup with pure Riverpod dependency injection

import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:categories_repository/categories_repository.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:curation_repository/curation_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart' show NostrClient;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/services/blocklist_content_filter.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/collaborator_invite_local_state_adapter.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscribed_list_video_cache.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/services/video_visibility_manager.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/search_utils.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

export 'auth_providers.dart';
export 'moderation_providers.dart';
export 'nostr_apps_providers.dart';
export 'notifications_providers.dart';
export 'permissions_providers.dart';
export 'preferences_providers.dart';
export 'relay_providers.dart';

part 'app_providers.g.dart';

BlockedVideoFilter _createBlockedAuthorFilter(Ref ref) {
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

/// Video filter builder for constructing relay-aware filters with server-side sorting
@riverpod
VideoFilterBuilder videoFilterBuilder(Ref ref) {
  final capabilityService = ref.watch(relayCapabilityServiceProvider);
  return VideoFilterBuilder(capabilityService);
}

/// Video visibility manager for controlling video playback based on visibility
@riverpod
VideoVisibilityManager videoVisibilityManager(Ref ref) {
  return VideoVisibilityManager();
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

/// Personal event cache service for ALL user's own events
@riverpod
PersonalEventCacheService personalEventCacheService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final service = PersonalEventCacheService();

  // Initialize with current user's pubkey when authenticated
  if (authService.isAuthenticated && authService.currentPublicKeyHex != null) {
    service.initialize(authService.currentPublicKeyHex!).catchError((e) {
      Log.error(
        'Failed to initialize PersonalEventCacheService',
        name: 'AppProviders',
        error: e,
      );
    });
  }

  return service;
}

/// Seen videos service for tracking viewed content
@riverpod
SeenVideosService seenVideosService(Ref ref) {
  return SeenVideosService();
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

/// Subscription manager for centralized subscription management
@Riverpod(keepAlive: true)
SubscriptionManager subscriptionManager(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  return SubscriptionManager(nostrService);
}

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, and SubscriptionManager
@Riverpod(keepAlive: true)
VideoEventService videoEventService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final subscriptionManager = ref.watch(subscriptionManagerProvider);
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);
  final videoFilterBuilder = ref.watch(videoFilterBuilderProvider);
  final db = ref.watch(databaseProvider);
  final eventRouter = EventRouter(db);

  final likesRepository = ref.watch(likesRepositoryProvider);
  final moderationLabelService = ref.watch(moderationLabelServiceProvider);
  final divineHostFilterService = ref.read(divineHostFilterServiceProvider);

  final service = VideoEventService(
    nostrService,
    subscriptionManager: subscriptionManager,
    profileRepository: profileRepository,
    eventRouter: eventRouter,
    videoFilterBuilder: videoFilterBuilder,
  );
  service.setBlocklistRepository(blocklistRepository);
  service.setLikesRepository(likesRepository);
  service.setContentFilterService(ref.watch(contentFilterServiceProvider));
  service.setModerationLabelService(moderationLabelService);
  service.setDivineHostFilterService(divineHostFilterService);

  // Teach the OG Viner badge cache from every video that flows through the
  // service. The cache filters internally (only `isOriginalVine` videos
  // contribute pubkeys), so it's safe to feed it every batch — popular,
  // new, classics, profile, hashtag, search, anything.
  final ogVinerCache = ref.read(ogVinerCacheServiceProvider);
  final disposeObserver = service.addVideoObserver(
    (videos) => unawaited(ogVinerCache.learnFromVideos(videos)),
  );
  ref.onDispose(disposeObserver);

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
    blockFilter: _createBlockedAuthorFilter(ref),
  );

  // Bridge: push curated list updates from legacy service into repository
  ref.listen(curatedListsStateProvider, (_, next) {
    next.whenData(repository.setSubscribedLists);
  });

  ref.onDispose(repository.dispose);
  return repository;
}

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

/// Blossom BUD-01 authentication service for age-restricted content
@riverpod
BlossomAuthService blossomAuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return BlossomAuthService(authProvider: _BlossomAuthAdapter(authService));
}

/// Shared viewer auth service for media GET requests.
final mediaViewerAuthServiceProvider = Provider<MediaViewerAuthService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final blossomAuthService = ref.watch(blossomAuthServiceProvider);
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  return MediaViewerAuthService(
    authService: authService,
    blossomAuthService: blossomAuthService,
    nip98AuthService: nip98AuthService,
  );
});

/// Media authentication interceptor for handling 401 unauthorized responses
@riverpod
MediaAuthInterceptor mediaAuthInterceptor(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final contentFilterService = ref.watch(contentFilterServiceProvider);
  final mediaViewerAuthService = ref.watch(mediaViewerAuthServiceProvider);
  return MediaAuthInterceptor(
    ageVerificationService: ageVerificationService,
    contentFilterService: contentFilterService,
    mediaViewerAuthService: mediaViewerAuthService,
  );
}

/// Blossom upload service (uses user-configured Blossom server)
@riverpod
BlossomUploadService blossomUploadService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final env = ref.read(currentEnvironmentProvider);
  return BlossomUploadService(
    authProvider: _BlossomAuthAdapter(authService),
    performanceMonitor: _FirebasePerformanceAdapter(),
    defaultServerUrl: env.blossomUrl,
  );
}

/// Upload manager uses only Blossom upload service
@Riverpod(keepAlive: true)
UploadManager uploadManager(Ref ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  final env = ref.read(currentEnvironmentProvider);
  return UploadManager(
    blossomService: blossomService,
    defaultBlossomUrl: env.blossomUrl,
  );
}

/// API service depends on auth service
@riverpod
ApiService apiService(Ref ref) {
  final authService = ref.watch(nip98AuthServiceProvider);
  return ApiService(authService: authService);
}

/// Crosspost API client for Bluesky toggle settings
@riverpod
CrosspostApiClient crosspostApiClient(Ref ref) {
  final oauthClient = ref.watch(oauthClientProvider);
  final config = ref.watch(oauthConfigProvider);
  return CrosspostApiClient(
    oauthClient: oauthClient,
    serverUrl: config.serverUrl,
  );
}

/// Video event publisher depends on multiple services
@Riverpod(keepAlive: true)
VideoEventPublisher videoEventPublisher(Ref ref) {
  final uploadManager = ref.watch(uploadManagerProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final blossomUploadService = ref.watch(blossomUploadServiceProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);
  final profileStatsDao = ref.watch(databaseProvider).profileStatsDao;
  final savedSoundsService = ref.watch(savedSoundsServiceProvider);

  return VideoEventPublisher(
    uploadManager: uploadManager,
    nostrService: nostrService,
    authService: authService,
    personalEventCache: personalEventCache,
    videoEventService: videoEventService,
    blossomUploadService: blossomUploadService,
    profileRepository: profileRepository,
    profileStatsDao: profileStatsDao,
    savedSoundsService: savedSoundsService,
  );
}

/// View event publisher for kind 22236 ephemeral analytics events
///
/// Publishes video view events to track watch time, traffic sources,
/// and enable creator analytics and recommendation systems.
@riverpod
ViewEventPublisher viewEventPublisher(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return ViewEventPublisher(
    nostrService: nostrService,
    authService: authService,
  );
}

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

/// Subscribed list video cache for merging subscribed list videos into home feed
/// Depends on CuratedListService which is async, so watch the state provider
@Riverpod(keepAlive: true)
SubscribedListVideoCache? subscribedListVideoCache(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);

  // Watch the curated lists state to get the service when ready
  final curatedListState = ref.watch(curatedListsStateProvider);

  // Only create cache when CuratedListService is available
  final curatedListService = curatedListState.whenOrNull(
    data: (_) => ref.read(curatedListsStateProvider.notifier).service,
  );

  // Return null if CuratedListService isn't ready yet
  if (curatedListService == null) {
    return null;
  }

  final cache = SubscribedListVideoCache(
    nostrService: nostrService,
    videoEventService: videoEventService,
    curatedListService: curatedListService,
  );

  // Wire up the sync triggers: when lists are subscribed/unsubscribed,
  // sync/remove videos from the cache automatically
  curatedListService.setOnListSubscribed((listId, videoIds) async {
    Log.debug(
      'Syncing subscribed list videos: $listId (${videoIds.length} videos)',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );
    await cache.syncList(listId, videoIds);
  });

  curatedListService.setOnListUnsubscribed((listId) {
    Log.debug(
      'Removing unsubscribed list from cache: $listId',
      name: 'SubscribedListVideoCache',
      category: LogCategory.video,
    );
    cache.removeList(listId);
  });

  // Sync all subscribed lists on initialization
  Future.microtask(() async {
    await cache.syncAllSubscribedLists();
  });

  ref.onDispose(() {
    // Clear callbacks when cache is disposed
    curatedListService.setOnListSubscribed(null);
    curatedListService.setOnListUnsubscribed(null);
    cache.dispose();
  });

  return cache;
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
    blockFilter: _createBlockedAuthorFilter(ref),
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

/// Video sharing service
///
/// When a [DmRepository] is available the service sends videos via NIP-17
/// encrypted DMs (NIP-17). Otherwise falls back to NIP-04 kind 4.
@riverpod
VideoSharingService? videoSharingService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);
  final dmRepository = ref.watch(dmRepositoryProvider);

  if (profileRepository == null) {
    return null;
  }

  return VideoSharingService(
    nostrService: nostrService,
    authService: authService,
    profileRepository: profileRepository,
    dmRepository: dmRepository,
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

/// Service that orchestrates the video-metadata-edit republish flow.
@riverpod
VideoMetadataUpdateService videoMetadataUpdateService(Ref ref) {
  return VideoMetadataUpdateService(
    authService: ref.watch(authServiceProvider),
    blossomService: ref.watch(blossomUploadServiceProvider),
    nostrService: ref.watch(nostrServiceProvider),
    personalEventCache: ref.watch(personalEventCacheServiceProvider),
    videoEventService: ref.watch(videoEventServiceProvider),
    collaboratorInviteService: CollaboratorInviteService(
      dmRepository: ref.watch(dmRepositoryProvider),
      l10n: currentAppL10n(ref.read(sharedPreferencesProvider)),
    ),
  );
}

/// Broken video tracker service for filtering non-functional videos
@riverpod
Future<BrokenVideoTracker> brokenVideoTracker(Ref ref) async {
  final tracker = BrokenVideoTracker();
  await tracker.initialize();
  return tracker;
}

/// Audio playback service for sound playback during recording and preview
///
/// Used by SoundsScreen to preview sounds and by camera screen
/// for lip-sync recording. Handles audio loading, play/pause, and cleanup.
/// Uses keepAlive to persist across the session (not auto-disposed).
@Riverpod(keepAlive: true)
AudioPlaybackService audioPlaybackService(Ref ref) {
  final service = AudioPlaybackService();

  ref.onDispose(() async {
    await service.dispose();
  });

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

// =============================================================================
// VIDEOS REPOSITORY
// =============================================================================

/// Provider for VideoLocalStorage instance (SQLite-backed)
///
/// Creates a DbVideoLocalStorage for caching video events locally.
/// Used by VideosRepository for cache-first lookups.
///
/// Uses:
/// - NostrEventsDao from databaseProvider (for SQLite storage)
@Riverpod(keepAlive: true)
VideoLocalStorage videoLocalStorage(Ref ref) {
  final db = ref.watch(databaseProvider);
  return DbVideoLocalStorage(dao: db.nostrEventsDao);
}

/// Provider for VideosRepository instance
///
/// Creates a VideosRepository for loading video feeds with pagination.
/// Works without authentication for public feeds.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - VideoLocalStorage for cache-first lookups and caching results
/// - ContentBlocklistRepository for filtering blocked/muted users
/// - ContentFilterService for filtering NSFW content based on user preferences
/// - FunnelcakeApiClient for trending/popular video sorting
@Riverpod(keepAlive: true)
VideosRepository videosRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final localStorage = ref.watch(videoLocalStorageProvider);
  final contentFilterService = ref.watch(contentFilterServiceProvider);
  final moderationLabelService = ref.watch(moderationLabelServiceProvider);
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
  final divineHostFilterService = ref.read(divineHostFilterServiceProvider);
  final feedAspectRatioPreference = ref.watch(
    feedAspectRatioPreferenceServiceProvider,
  );

  final nsfwFilter = createNsfwFilter(
    contentFilterService,
    moderationLabelService: moderationLabelService,
  );

  return VideosRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    blockFilter: _createBlockedAuthorFilter(ref),
    contentFilter: (video) =>
        nsfwFilter(video) ||
        (divineHostFilterService.showDivineHostedOnly &&
            !video.isFromDivineServer) ||
        feedAspectRatioPreference.shouldHideVideo(video),
    warningLabelsResolver: createNsfwWarnLabels(
      contentFilterService,
      moderationLabelService: moderationLabelService,
    ),
    funnelcakeApiClient: funnelcakeClient,
    inMemoryFeedCache: InMemoryFeedCache(),
  );
}

// =============================================================================
// LIKES REPOSITORY
// =============================================================================

/// Provider for LikesRepository instance
///
/// Creates a LikesRepository when the user is authenticated.
/// Returns null when user is not authenticated.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalReactionsDao from databaseProvider (for local storage)
@Riverpod(keepAlive: true)
LikesRepository likesRepository(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to react to auth changes (login/logout)
  // This ensures the provider rebuilds when authentication completes
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;

  final nostrClient = ref.watch(nostrServiceProvider);

  // Only create localStorage if we have a valid user pubkey
  // The provider will rebuild when auth state changes
  DbLikesLocalStorage? localStorage;
  if (userPubkey != null) {
    final db = ref.watch(databaseProvider);
    localStorage = DbLikesLocalStorage(
      dao: db.personalReactionsDao,
      userPubkey: userPubkey,
    );
  }

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);

  final repository = LikesRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    isOnline: () =>
        connectionStatus.isOnline && authService.canPublishNostrWritesNow,
    queueOfflineAction: pendingActionService != null
        ? ({
            required bool isLike,
            required String eventId,
            required String authorPubkey,
            String? addressableId,
            int? targetKind,
          }) async {
            await pendingActionService.queueAction(
              type: isLike ? PendingActionType.like : PendingActionType.unlike,
              targetId: eventId,
              authorPubkey: authorPubkey,
              addressableId: addressableId,
              targetKind: targetKind,
            );
          }
        : null,
  );

  // Register executors with pending action service for sync
  if (pendingActionService != null) {
    pendingActionService.registerExecutor(
      PendingActionType.like,
      (action) => repository.executeLikeAction(
        eventId: action.targetId,
        authorPubkey: action.authorPubkey ?? '',
        addressableId: action.addressableId,
        targetKind: action.targetKind,
      ),
    );
    pendingActionService.registerExecutor(
      PendingActionType.unlike,
      (action) => repository.executeUnlikeAction(action.targetId),
    );
  }

  // Initialize: load from local storage + set up persistent subscription
  repository.initialize().catchError((Object e) {
    Log.error(
      'Failed to initialize LikesRepository',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.onDispose(repository.dispose);

  return repository;
}

/// Provider for RepostsRepository instance
///
/// Creates a RepostsRepository for managing user reposts (Kind 16 generic
/// reposts).
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalRepostsDao from databaseProvider (for local storage)
@Riverpod(keepAlive: true)
RepostsRepository repostsRepository(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to react to auth changes (login/logout)
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;

  final nostrClient = ref.watch(nostrServiceProvider);

  // Only create localStorage if we have a valid user pubkey
  // The provider will rebuild when auth state changes
  DbRepostsLocalStorage? localStorage;
  if (userPubkey != null) {
    final db = ref.watch(databaseProvider);
    localStorage = DbRepostsLocalStorage(
      dao: db.personalRepostsDao,
      userPubkey: userPubkey,
    );
  }

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);

  final repository = RepostsRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    isOnline: () =>
        connectionStatus.isOnline && authService.canPublishNostrWritesNow,
    queueOfflineAction: pendingActionService != null
        ? ({
            required bool isRepost,
            required String addressableId,
            required String originalAuthorPubkey,
            String? eventId,
          }) async {
            await pendingActionService.queueAction(
              type: isRepost
                  ? PendingActionType.repost
                  : PendingActionType.unrepost,
              targetId: addressableId,
              authorPubkey: originalAuthorPubkey,
              addressableId: addressableId,
            );
          }
        : null,
  );

  // Register executors with pending action service for sync
  if (pendingActionService != null) {
    pendingActionService.registerExecutor(
      PendingActionType.repost,
      (action) => repository.executeRepostAction(
        addressableId: action.addressableId ?? action.targetId,
        originalAuthorPubkey: action.authorPubkey ?? '',
      ),
    );
    pendingActionService.registerExecutor(
      PendingActionType.unrepost,
      (action) => repository.executeUnrepostAction(
        action.addressableId ?? action.targetId,
      ),
    );
  }

  // Initialize: load from local storage + set up persistent subscription
  repository.initialize().catchError((Object e) {
    Log.error(
      'Failed to initialize RepostsRepository',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.onDispose(repository.dispose);

  return repository;
}

/// Adapts the app-level [AuthService] to the package-level
/// [BlossomAuthProvider] interface.
class _BlossomAuthAdapter implements BlossomAuthProvider {
  const _BlossomAuthAdapter(this._authService);

  final AuthService _authService;

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  Future<BlossomSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
  }) async {
    final event = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
    );
    if (event == null) return null;
    return BlossomSignedEvent(json: event.toJson());
  }
}

/// Adapts [PerformanceMonitoringService] to the package-level
/// [BlossomPerformanceMonitor] interface.
class _FirebasePerformanceAdapter implements BlossomPerformanceMonitor {
  @override
  Future<void> startTrace(String traceName) =>
      PerformanceMonitoringService.instance.startTrace(traceName);

  @override
  Future<void> stopTrace(String traceName) =>
      PerformanceMonitoringService.instance.stopTrace(traceName);

  @override
  void setMetric(String traceName, String metricName, int value) =>
      PerformanceMonitoringService.instance.setMetric(
        traceName,
        metricName,
        value,
      );
}
