// ABOUTME: Social, foundation, and collaborator Riverpod providers split from app_providers.dart
// ABOUTME: Final batch (9c) — pendingAction, outgoingDmRetry, analytics, hashtag, draft, clip,
// ABOUTME: userDataCleanup, social, contentReporting, contentDeletion, bugReport, collaborator-3

import 'dart:async';

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/collaborator_invite_local_state_adapter.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/view_event_retry_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'social_providers.g.dart';

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

/// Analytics service with opt-out support.
///
/// Publishes Kind 22236 ephemeral Nostr view events via [ViewEventPublisher].
@Riverpod(keepAlive: true) // Keep alive to maintain singleton behavior
AnalyticsService analyticsService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final viewPublisher = ref.watch(viewEventPublisherProvider);
  final retryService = ref.watch(viewEventRetryServiceProvider);
  final service = AnalyticsService(
    viewEventPublisher: viewPublisher,
    pendingViewEventsDao: db.pendingViewEventsDao,
    flushPendingViewEvents: retryService?.sweep,
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
