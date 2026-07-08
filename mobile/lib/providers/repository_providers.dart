// ABOUTME: Repository Riverpod providers split from app_providers.dart
// ABOUTME: Badge, follow, profile, categories, hashtag, curated, people-lists,
// ABOUTME: bookmark, mute, dm, comments — plus CuratedListsState notifier

import 'dart:async';
import 'dart:convert';

import 'package:categories_repository/categories_repository.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:curation_repository/curation_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/utils/search_utils.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'repository_providers.g.dart';

final badgeRepositoryProvider = Provider<BadgeRepository>((ref) {
  final authService = ref.watch(authServiceProvider);
  return BadgeRepository(
    nostrClient: ref.watch(nostrServiceProvider),
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    currentPubkey: () => authService.currentPublicKeyHex,
    signEvent: authService.createAndSignEvent,
  );
});

final FutureProviderFamily<List<ProfileBadgeViewData>, String>
profileAcceptedBadgesProvider = FutureProvider.autoDispose
    .family<List<ProfileBadgeViewData>, String>((
      ref,
      pubkey,
    ) {
      if (pubkey.isEmpty) return const [];
      return ref
          .watch(badgeRepositoryProvider)
          .loadAcceptedBadgesForProfile(pubkey);
    });

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
  final topHashtags = ref.watch(topHashtagsServiceProvider);

  // Ensure static hashtags are loaded before any local search callback runs.
  // loadTopHashtags is idempotent and no-ops if already loaded.
  topHashtags.loadTopHashtags();

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
          topHashtags.searchHashtags(query, limit: limit),
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
  return CategoriesRepository(
    funnelcakeApiClient: funnelcakeClient,
    blockFilter: createBlockedAuthorFilter(ref),
  );
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

  return _buildProfileRepository(ref, warmCache: true);
}

/// Lightweight ProfileRepository gated on **identity-known** (a pubkey is
/// available) rather than the full `nostrReady` relay-connect settle.
///
/// The follower/following/video COUNTS are populated by a PUBLIC funnelcake
/// REST call (`getUserProfile` → `_cacheProfileStatsFromResult`, no signer,
/// no relay) and read back from Drift via `watchProfileStats`. None of that
/// needs the relay-ready client, so gating those counts behind `nostrReady`
/// is what left them stuck on "—" for the ~4s relay-connect window at cold
/// start (#5863). This provider hands over the same repository as soon as the
/// user's identity is known, so the counts render as soon as REST returns.
///
/// It does NOT warm the Kind-0 cache — that side effect belongs to the
/// relay-backed [profileRepository]. Only [userProfileStatsReactiveProvider]
/// consumes this; everything relay-dependent must keep using
/// [profileRepository].
@Riverpod(keepAlive: true)
ProfileRepository? profileStatsRepository(Ref ref) {
  final identityPubkey = ref.watch(
    nostrSessionProvider.select((readiness) {
      if (readiness.phase == NostrSessionPhase.identityKnown ||
          readiness.phase == NostrSessionPhase.nostrReady) {
        return readiness.pubkey;
      }
      return null;
    }),
  );
  if (identityPubkey == null || identityPubkey.isEmpty) {
    return null;
  }

  return _buildProfileRepository(ref, warmCache: false);
}

/// Shared construction for [profileRepository] and [profileStatsRepository].
/// When [warmCache] is true, pre-loads known cached pubkeys into the
/// SubscriptionManager so Kind-0 relay requests skip already-cached authors.
ProfileRepository _buildProfileRepository(Ref ref, {required bool warmCache}) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final userProfilesDao = ref.watch(databaseProvider).userProfilesDao;
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);

  final env = ref.watch(currentEnvironmentProvider);

  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

  final engine = ref.watch(contentPolicyEngineProvider);
  bool blockFilter(String pubkey) {
    final decision = engine.evaluate(
      PolicyInput(pubkey: pubkey),
      blocklistRepository.currentState,
    );
    return decision is Block;
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

  if (warmCache) {
    // Pre-load known cached pubkeys and wire into SubscriptionManager
    // so Kind 0 relay requests skip already-cached authors.
    unawaited(
      repo.loadKnownCachedPubkeys().then((_) {
        ref
            .read(subscriptionManagerProvider)
            .setCacheLookup(hasProfileCached: repo.hasProfile);
      }),
    );
  }

  return repo;
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
DmReactionsRepository dmReactionsRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final repository = DmReactionsRepository(
    reactionsDao: db.dmReactionsDao,
    conversationsDao: db.conversationsDao,
    directMessagesDao: db.directMessagesDao,
    errorReporter: (error, stackTrace, {required site}) {
      unawaited(
        CrashReportingService.instance.recordError(
          error,
          stackTrace,
          reason: 'DmReactionsRepository.$site',
        ),
      );
    },
  );
  ref.onDispose(repository.clearCredentials);

  final nostrService = ref.watch(nostrServiceProvider);
  final isReady = ref.watch(nostrSessionProvider).isReadyForActiveClient;
  if (!isReady) {
    repository.clearCredentials();
    return repository;
  }

  final publicKey = nostrService.publicKey;
  if (publicKey.isEmpty) {
    repository.clearCredentials();
    return repository;
  }

  repository.setCredentials(
    userPubkey: publicKey,
    messageService: NIP17MessageService(
      signer: nostrService.signer,
      senderPublicKey: publicKey,
      nostrService: nostrService,
      sendPolicy: ref.read(dmSendPolicyProvider),
    ),
  );
  return repository;
}

/// Provider for [FeedTuningRepository] — publishes swipe "more/less like this"
/// feed-tuning signals.
///
/// Watches only [nostrServiceProvider] (a stable, keepAlive client). The
/// repository reads `publicKey` live at publish time, so it stays correct
/// across auth/signer changes without rebuilding — no `ValueKey` guard is
/// needed at the consumer (rule exception: genuinely stable + reads live
/// state).
@Riverpod(keepAlive: true)
FeedTuningRepository feedTuningRepository(Ref ref) {
  return FeedTuningRepository(
    nostrClient: ref.watch(nostrServiceProvider),
    errorReporter: (error, stackTrace, {required site}) {
      unawaited(
        CrashReportingService.instance.recordError(
          error,
          stackTrace,
          reason: 'FeedTuningRepository.$site',
        ),
      );
    },
  );
}

@Riverpod(keepAlive: true)
DmRepository dmRepository(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final reactionsRepository = ref.watch(dmReactionsRepositoryProvider);

  // #4974 RC3: gate self-publishing the user's kind-10050 behind the feature
  // flag (default OFF until the backend relay accepts the kind), and advertise
  // the environment's stable DM relay (same source as the kind-10002
  // bootstrap), not the volatile connected-relay getter. Read, not watch, so a
  // flag flip doesn't churn the live DM subscription — the provider body
  // re-runs (and re-reads the flag) on each auth change.
  final publishDmRelayListEnabled = ref.read(
    isFeatureEnabledProvider(FeatureFlag.publishDmRelayList),
  );
  final dmInboxRelayUrl = ref.read(currentEnvironmentProvider).relayUrl;

  final repository = DmRepository(
    nostrClient: nostrService,
    directMessagesDao: db.directMessagesDao,
    conversationsDao: db.conversationsDao,
    outgoingDmsDao: db.outgoingDmsDao,
    pendingGiftWrapsDao: db.pendingGiftWrapsDao,
    processedGiftWrapsDao: db.processedGiftWrapsDao,
    syncState: DmSyncState(prefs),
    reactionsRepository: reactionsRepository,
    publishDmRelayListEnabled: publishDmRelayListEnabled,
    dmInboxRelayUrl: dmInboxRelayUrl,
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
      final messageService = NIP17MessageService(
        signer: signer,
        senderPublicKey: publicKey,
        nostrService: nostrService,
        sendPolicy: ref.read(dmSendPolicyProvider),
      );

      repository.setCredentials(
        userPubkey: publicKey,
        signer: signer,
        messageService: messageService,
      );
      // Open the gift-wrap subscription for the whole authenticated
      // session. Bounded by `since: newestSyncedAt - 2d` and isolate
      // decrypt so cold start stays cheap regardless of lifetime DM count.
      unawaited(repository.startListening());
      // Self-advertise the user's NIP-17 kind-10050 DM inbox relay list once
      // per (device, pubkey) when absent, so compliant senders deliver where
      // divine reads. Flag-on-OK, so it no-ops + retries until the relay
      // accepts the kind — never blocks login. See #4974.
      unawaited(repository.ensureDmRelayListPublished());
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
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

  final engine = ref.watch(contentPolicyEngineProvider);
  bool blockFilter(String pubkey) {
    final decision = engine.evaluate(
      PolicyInput(pubkey: pubkey),
      blocklistRepository.currentState,
    );
    return decision is Block;
  }

  final repository = CommentsRepository(
    nostrClient: nostrClient,
    funnelcakeApiClient: funnelcakeClient,
    blockFilter: blockFilter,
  );
  ref.onDispose(repository.clearCommentCountCache);
  return repository;
}
