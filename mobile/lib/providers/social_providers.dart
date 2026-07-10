// ABOUTME: Social, foundation, and collaborator Riverpod providers split from app_providers.dart
// ABOUTME: Final batch (9c) — pendingAction, outgoingDmRetry, analytics, hashtag, draft, clip,
// ABOUTME: userDataCleanup, social, contentReporting, contentDeletion, bugReport, collaborator-3

import 'dart:async';

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/config/app_config.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/collaborator_invite_local_state_adapter.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/dm_reaction_retry_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/product_event_queue.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/view_event_retry_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'social_providers.g.dart';

/// Reconnect trigger for the DM retry sweeps (messages, reactions, removals):
/// emits once each time `connectivity_plus` reports any non-`none` result, so
/// work queued during a brief network drop is re-driven the moment
/// connectivity returns — without waiting for an app-foreground transition.
/// The sweeps short-circuit when nothing is retryable. Shared by the message
/// and reaction retry providers so the trigger shape stays in one place.
Stream<void> _dmRetryConnectivityTriggerStream() => Connectivity()
    .onConnectivityChanged
    .where((results) => results.any((r) => r != ConnectivityResult.none))
    .map<void>((_) {});

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

final collaboratorInviteRecoveryRepositoryProvider = Provider<DmRepository?>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  ref.watch(currentAuthStateProvider);
  final readiness = ref.watch(nostrSessionProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null || userPubkey.isEmpty) return null;
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  return ref.watch(dmRepositoryProvider);
});

final pendingCollaboratorInviteGroupsProvider =
    StreamProvider<List<PendingCollaboratorInviteGroup>>((ref) {
      final repository = ref.watch(
        collaboratorInviteRecoveryRepositoryProvider,
      );
      if (repository == null) {
        return Stream.value(const <PendingCollaboratorInviteGroup>[]);
      }
      return repository.watchPendingCollaboratorInviteGroups();
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

  // Re-drive undelivered messages the moment connectivity returns, not only on
  // app-foreground transitions — a message queued during a brief network drop
  // would otherwise sit undelivered until the app is backgrounded and
  // re-foregrounded.
  final retryTriggerStream = _dmRetryConnectivityTriggerStream();

  final service = OutgoingDmRetryService(
    dmRepository: dmRepository,
    outgoingDmsDao: db.outgoingDmsDao,
    userPubkey: userPubkey,
    appForegroundStream: foregroundController.stream,
    retryTriggerStream: retryTriggerStream,
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

/// Auto-sweep service that re-drives undelivered DM reactions (publish failed
/// or interrupted mid-send) on app-foreground transitions via
/// [DmReactionsRepository.retry].
///
/// Gives reactions the durable delivery that DM messages already get from
/// [OutgoingDmRetryService] + the `outgoing_dms` queue: a reaction whose
/// recipient gift wrap failed to land (common on a flaky relay) is otherwise
/// lost with no automatic recovery. keepAlive with no UI consumer, so it is
/// read eagerly at app shell startup (`main.dart`) to wire the foreground
/// subscription.
///
/// Returns null until the user is authenticated and the Nostr session is
/// ready — the same readiness the reaction repository's `setCredentials`
/// needs before a retry can publish.
@Riverpod(keepAlive: true)
DmReactionRetryService? dmReactionRetryService(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild on sign-in / sign-out / account switch.
  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) return null;

  // Gate on matching Nostr readiness so the reaction repository's
  // setCredentials has run by the time the first foreground sweep fires.
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  final reactionsRepository = ref.watch(dmReactionsRepositoryProvider);

  // Bridge the synchronous AppForeground notifier into a Stream<bool> so the
  // service's contract stays free of Riverpod types and is easy to drive from
  // unit tests.
  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  // Re-drive undelivered reactions/removals the moment connectivity returns,
  // not only on app-foreground transitions — a reaction left during a brief
  // network drop would otherwise sit undelivered until the app is backgrounded
  // and re-foregrounded.
  final retryTriggerStream = _dmRetryConnectivityTriggerStream();

  final service = DmReactionRetryService(
    reactionsRepository: reactionsRepository,
    appForegroundStream: foregroundController.stream,
    retryTriggerStream: retryTriggerStream,
  );

  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize DmReactionRetryService',
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

/// Auto-sweep service for the durable `pending_view_events` queue.
@Riverpod(keepAlive: true)
ViewEventRetryService? viewEventRetryService(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  ref.watch(currentAuthStateProvider);

  final userPubkey = authService.currentPublicKeyHex;
  if (userPubkey == null) return null;

  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.pubkey != userPubkey) {
    return null;
  }

  final db = ref.watch(databaseProvider);
  final viewPublisher = ref.watch(viewEventPublisherProvider);
  final foregroundController = StreamController<bool>();
  ref.onDispose(foregroundController.close);

  final service = ViewEventRetryService(
    viewEventPublisher: viewPublisher,
    pendingViewEventsDao: db.pendingViewEventsDao,
    userPubkey: userPubkey,
    appForegroundStream: foregroundController.stream,
  );

  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize ViewEventRetryService',
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

/// Durable queue for first-party product analytics events.
@Riverpod(keepAlive: true)
ProductEventQueue productEventQueue(Ref ref) {
  final db = ref.watch(databaseProvider);
  final env = ref.watch(currentEnvironmentProvider);
  final client = http.Client();
  ref.onDispose(client.close);

  final ingestClient = AnalyticsIngestClient(
    httpClient: client,
    nip98AuthService: ref.watch(nip98AuthServiceProvider),
    apiBaseUrl: () => env.apiBaseUrl,
  );
  final queue = ProductEventQueue(
    dao: db.pendingProductEventsDao,
    ingestClient: ingestClient,
  );

  queue.recoverPublishingAndFlush().catchError((Object e) {
    Log.debug(
      'Initial ProductEventQueue recovery/flush failed: $e',
      name: 'AppProviders',
      category: LogCategory.system,
    );
  });

  ref.listen<bool>(appForegroundProvider, (_, next) {
    if (next) {
      queue.flush().catchError((Object e) {
        Log.debug(
          'Foreground ProductEventQueue flush failed: $e',
          name: 'AppProviders',
          category: LogCategory.system,
        );
      });
    }
  }, fireImmediately: true);

  return queue;
}

/// Analytics service with opt-out support.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].
@Riverpod(keepAlive: true) // Keep alive to maintain singleton behavior
AnalyticsService analyticsService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  final viewPublisher = ref.watch(viewEventPublisherProvider);
  final retryService = ref.watch(viewEventRetryServiceProvider);
  final productQueue = ref.watch(productEventQueueProvider);
  final service = AnalyticsService(
    viewEventPublisher: viewPublisher,
    pendingViewEventsDao: db.pendingViewEventsDao,
    flushPendingViewEvents: retryService?.sweep,
    productEventQueue: productQueue,
    currentUserPubkey: () => authService.currentPublicKeyHex,
    appVersion: () => AppConfig.appVersion,
  );

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
  final ownerPubkey =
      authService.currentPublicKeyHex ??
      DraftStorageService.anonymousOwnerPubkey;
  return DraftStorageService(
    draftsDao: db.draftsDao,
    clipsDao: db.clipsDao,
    ownerPubkey: ownerPubkey,
  );
}

/// Clip library service for persisting individual video clips
@riverpod
ClipLibraryService clipLibraryService(Ref ref) {
  final db = ref.watch(databaseProvider);
  // Rebuild when account changes so ownerPubkey stays current
  ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  final ownerPubkey =
      authService.currentPublicKeyHex ??
      DraftStorageService.anonymousOwnerPubkey;
  return ClipLibraryService(
    clipsDao: db.clipsDao,
    draftsDao: db.draftsDao,
    ownerPubkey: ownerPubkey,
  );
}

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
        // Raw failed-decrypt gift wraps are encrypted DM data of the same
        // class as direct_messages — wipe them on the same path so they never
        // outlive the account's decrypted DMs. See #5202.
        await db.pendingGiftWrapsDao.clearAll();
        // Wipe the processed-wrap dedup ledger on the same path: a stale ledger
        // must never suppress re-population of an account's reactions/deletions
        // after its DM data is cleared. See #5452.
        await db.processedGiftWrapsDao.clearAll();
        await db.notificationsDao.clearAll();
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
    await db.draftsDao.claimLegacyRows(
      userPubkey,
      sourceOwnerPubkey: DraftStorageService.anonymousOwnerPubkey,
    );
    await db.clipsDao.claimLegacyRows(
      userPubkey,
      sourceOwnerPubkey: DraftStorageService.anonymousOwnerPubkey,
    );
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

/// Content deletion service for NIP-09 delete events
@riverpod
Future<ContentDeletionService> contentDeletionService(Ref ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final profileStatsDao = ref.watch(databaseProvider).profileStatsDao;
  final service = ContentDeletionService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
    profileStatsDao: profileStatsDao,
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
    errorTracker: ref.watch(errorAnalyticsTrackerProvider),
  );
}
