// ABOUTME: Video & feed Riverpod providers split from app_providers.dart
// ABOUTME: VideoEventService keystone + filters, publishers, repositories, sharing

import 'dart:async';

import 'package:likes_repository/likes_repository.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/subscribed_list_video_cache.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_resolver.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/services/video_metadata_update_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/services/video_visibility_manager.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'video_providers.g.dart';

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

/// Personal event cache service for ALL user's own events
@riverpod
PersonalEventCacheService personalEventCacheService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final service = PersonalEventCacheService();

  // Initialize with current user's pubkey when authenticated
  if (authService.isAuthenticated && authService.currentPublicKeyHex != null) {
    service.initialize(authService.currentPublicKeyHex!).catchError((e) {
      Log.warning(
        'Failed to initialize PersonalEventCacheService: $e',
        name: 'PersonalEventCacheService',
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

/// Video event publisher for publishing video events to Nostr relays
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

/// Unified resolver for fetching a [VideoEvent] by its event id, with
/// in-memory → personal cache → relay fallback. See [VideoEventResolver].
@Riverpod(keepAlive: true)
VideoEventResolver videoEventResolver(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);
  final authService = ref.watch(authServiceProvider);

  return VideoEventResolver(
    videoEventService: videoEventService,
    personalEventCache: personalEventCache,
    subscribe: nostrService.subscribe,
    viewerPubkeyHex: () => authService.currentPublicKeyHex,
  );
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
/// Rebuilds (yielding a fresh in-memory cache) when content filter, aspect
/// ratio, or Divine-host filter preferences change. The version providers
/// act as rebuild triggers since the underlying services are long-lived
/// ChangeNotifiers that don't themselves cause provider invalidation.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - VideoLocalStorage for cache-first lookups and caching results
/// - ContentBlocklistRepository for filtering blocked/muted users
/// - ContentFilterService for filtering NSFW content based on user preferences
/// - FunnelcakeApiClient for trending/popular video sorting
@Riverpod(keepAlive: true)
VideosRepository videosRepository(Ref ref) {
  // Watch version providers to trigger rebuild on preference changes.
  // These increment when ContentFilterService or FeedAspectRatioPreference
  // notifies, ensuring a fresh repository (with empty InMemoryFeedCache)
  // is created after any filter toggle.
  ref.watch(contentFilterVersionProvider);
  ref.watch(divineHostFilterVersionProvider);

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

  final repository = VideosRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    blockFilter: createBlockedAuthorFilter(ref),
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

  // Clear the in-memory feed cache (home + per-author) on logout/account
  // switch — the repository owns its cache. Replaces the deleted
  // profile_feed_session_cache auth-flip clear. Filter toggles already rebuild
  // this provider with a fresh cache, so this listener covers only the auth path.
  ref.listen<AuthState>(currentAuthStateProvider, (previous, next) {
    if (next == AuthState.unauthenticated) {
      repository.clearInMemoryFeedCache();
    }
  });

  return repository;
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
    Log.warning(
      'Failed to initialize LikesRepository: $e',
      name: 'LikesRepository',
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
    Log.warning(
      'Failed to initialize RepostsRepository: $e',
      name: 'RepostsRepository',
    );
  });

  ref.onDispose(repository.dispose);

  return repository;
}
