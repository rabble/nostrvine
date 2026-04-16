// ABOUTME: Comprehensive Riverpod providers for all application services
// ABOUTME: Replaces Provider MultiProvider setup with pure Riverpod dependency injection

import 'dart:async';
import 'dart:convert';
import 'dart:core';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:categories_repository/categories_repository.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:curation_service/curation_service.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:http/http.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:nostr_client/nostr_client.dart'
    show RelayConnectionStatus, RelayState;
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/ai_training_preference_service.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/audio_device_preference_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/blocklist_content_filter.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/cawg_verifier_client.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/email_verification_listener.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/immediate_completion_helper.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/media_viewer_auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:openvine/services/password_reset_listener.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscribed_list_video_cache.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/services/video_visibility_manager.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/search_utils.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'app_providers.g.dart';

final nostrAppDirectoryServiceProvider = Provider<NostrAppDirectoryService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final client = Client();
  ref.onDispose(client.close);
  return NostrAppDirectoryService(
    sharedPreferences: prefs,
    client: client,
    baseUrl: AppConfig.appsDirectoryBaseUrl,
  );
});

final nostrAppGrantStoreProvider = Provider<NostrAppGrantStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NostrAppGrantStore(sharedPreferences: prefs);
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final firebaseOnMessageProvider = Provider<Stream<RemoteMessage>>(
  (ref) => FirebaseMessaging.onMessage,
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  final nostrClient = ref.watch(nostrServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final envConfig = ref.watch(currentEnvironmentProvider);
  final firebaseMessaging = ref.watch(firebaseMessagingProvider);

  final pushService = PushNotificationService(
    authService: authService,
    nostrClient: nostrClient,
    notificationService: notificationService,
    environmentConfig: envConfig,
    getToken: firebaseMessaging.getToken,
    onTokenRefresh: firebaseMessaging.onTokenRefresh,
  );

  ref.onDispose(pushService.dispose);
  return pushService;
});

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) {
      return NotificationPreferencesService(
        openBox: NotificationPreferencesService.openBox,
        publishPreferences: (prefs) {
          return ref
              .read(pushNotificationServiceProvider)
              .updatePreferences(prefs);
        },
      );
    });

final nostrAppBridgePolicyProvider = Provider<NostrAppBridgePolicy>((ref) {
  final authService = ref.watch(authServiceProvider);
  final grantStore = ref.watch(nostrAppGrantStoreProvider);
  return NostrAppBridgePolicy(
    grantStore: grantStore,
    currentUserPubkey: authService.currentPublicKeyHex,
  );
});

final nostrAppAuditServiceProvider = Provider<NostrAppAuditService>((ref) {
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  final client = Client();
  ref.onDispose(client.close);
  return NostrAppAuditService(
    workerBaseUri: Uri.parse(AppConfig.appsDirectoryBaseUrl),
    authTokenProvider:
        ({required url, required method, required payload}) async {
          final token = await nip98AuthService.createAuthToken(
            url: url,
            method: HttpMethod.post,
            payload: payload,
          );
          if (token == null) return null;
          return AuditAuthToken(authorizationHeader: token.authorizationHeader);
        },
    httpClient: client,
  );
});

final nostrAppBridgeServiceProvider = Provider<NostrAppBridgeService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final policy = ref.watch(nostrAppBridgePolicyProvider);
  final auditService = ref.watch(nostrAppAuditServiceProvider);
  return NostrAppBridgeService(
    authProvider: _AuthServiceBridgeAdapter(authService),
    policy: policy,
    signerFactory: () => authService.requireIdentity,
    auditService: auditService,
  );
});

// =============================================================================
// FOUNDATIONAL SERVICES (No dependencies)
// =============================================================================

/// Connection status service for monitoring network connectivity
@Riverpod(keepAlive: true)
ConnectionStatusService connectionStatusService(Ref ref) {
  final service = ConnectionStatusService();
  ref.onDispose(service.dispose);
  return service;
}

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

/// Relay capability service for detecting NIP-11 Divine extensions
@Riverpod(keepAlive: true)
RelayCapabilityService relayCapabilityService(Ref ref) {
  final service = RelayCapabilityService();
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

/// Background activity manager singleton for tracking app foreground/background state
@Riverpod(keepAlive: true)
BackgroundActivityManager backgroundActivityManager(Ref ref) {
  return BackgroundActivityManager();
}

/// Relay statistics service for tracking per-relay metrics
@Riverpod(keepAlive: true)
RelayStatisticsService relayStatisticsService(Ref ref) {
  final service = RelayStatisticsService();
  ref.onDispose(service.dispose);
  return service;
}

/// Stream provider for reactive relay statistics updates
/// Use this provider when you need UI to rebuild when statistics change
@riverpod
Stream<Map<String, RelayStatistics>> relayStatisticsStream(Ref ref) async* {
  final service = ref.watch(relayStatisticsServiceProvider);

  // Emit current state immediately
  yield service.getAllStatistics();

  // Create a stream controller to emit updates on notifyListeners
  final controller = StreamController<Map<String, RelayStatistics>>();

  void listener() {
    if (!controller.isClosed) {
      controller.add(service.getAllStatistics());
    }
  }

  service.addListener(listener);
  ref.onDispose(() {
    service.removeListener(listener);
    controller.close();
  });

  yield* controller.stream;
}

/// Bridge provider that connects NostrClient relay status updates to
/// RelayStatisticsService.
///
/// Tracks connection/disconnection events via the relay status stream and
/// periodically syncs per-relay SDK counters (events received, queries sent,
/// errors) so each relay displays its own real statistics.
///
/// Must be watched at app level to activate the bridge.
@Riverpod(keepAlive: true)
void relayStatisticsBridge(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final statsService = ref.watch(relayStatisticsServiceProvider);

  // Track previous states to detect connection changes
  final Map<String, bool> previousStates = {};

  // Helper to process status updates (used for both initial state and stream)
  void processStatuses(Map<String, RelayConnectionStatus> statuses) {
    for (final entry in statuses.entries) {
      final url = entry.key;
      final status = entry.value;
      final wasConnected = previousStates[url] ?? false;
      final isConnected =
          status.isConnected || status.state == RelayState.authenticated;

      // Only record changes to avoid excessive updates
      if (isConnected && !wasConnected) {
        statsService.recordConnection(url);
      } else if (!isConnected && wasConnected) {
        statsService.recordDisconnection(url, reason: status.errorMessage);
      }

      previousStates[url] = isConnected;
    }

    // Prune entries for relays no longer in the status map
    previousStates.removeWhere((url, _) => !statuses.containsKey(url));
  }

  // Process current state immediately (relays may have connected before
  // the bridge started)
  processStatuses(nostrService.relayStatuses);

  // Listen to relay status stream for future connection changes
  final subscription = nostrService.relayStatusStream.listen(processStatuses);

  // Periodically sync per-relay SDK counters so each relay shows its own
  // real statistics (not identical values distributed from app-level totals).
  final syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
    final counters = nostrService.getRelayPoolCounters();
    for (final entry in counters.entries) {
      statsService.syncSdkCounters(
        entry.key,
        eventsReceived: entry.value.eventsReceived,
        queriesSent: entry.value.queriesSent,
        errors: entry.value.errors,
      );
    }
  });

  ref.onDispose(() {
    syncTimer.cancel();
    subscription.cancel();
  });
}

/// Bridge provider that detects when the configured relay set changes
/// (relays added or removed) and triggers a full feed reset+resubscribe.
/// Debounces for 2 seconds to collapse rapid add/remove operations.
/// Only reacts to set membership changes, not connection state flapping.
@Riverpod(keepAlive: true)
void relaySetChangeBridge(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);

  Set<String> previousRelaySet = nostrService.relayStatuses.keys.toSet();
  Timer? debounceTimer;

  void processStatuses(Map<String, RelayConnectionStatus> statuses) {
    final currentRelaySet = statuses.keys.toSet();

    // Only trigger if the set of relay URLs has changed (not just status)
    if (!_setsEqual(currentRelaySet, previousRelaySet)) {
      Log.info(
        'Relay set changed: '
        '${previousRelaySet.length} -> ${currentRelaySet.length} relays',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );

      previousRelaySet = currentRelaySet;

      // Debounce: collapse rapid changes into a single reset
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(seconds: 2), () async {
        Log.info(
          'Debounce elapsed - forcing WebSocket reconnection and feed reset',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );

        // CRITICAL FIX: Force reconnect all WebSocket connections
        // When relays are added/removed, the existing WebSocket connections
        // can become stale/zombie - showing as "connected" but not responding
        // to subscription requests. Force disconnect and reconnect all relays
        // to establish fresh connections.
        try {
          await nostrService.forceReconnectAll();
          Log.info(
            'Successfully reconnected all relay WebSockets',
            name: 'RelaySetChangeBridge',
            category: LogCategory.relay,
          );
        } catch (e) {
          Log.error(
            'Failed to reconnect relays: $e',
            name: 'RelaySetChangeBridge',
            category: LogCategory.relay,
          );
        }

        // Now reset and resubscribe all feeds with fresh connections
        videoEventService.resetAndResubscribeAll();
      });
    }
  }

  // Process current state immediately to establish baseline
  processStatuses(nostrService.relayStatuses);

  // Listen to relay status stream for future updates
  final subscription = nostrService.relayStatusStream.listen(processStatuses);

  ref.onDispose(() {
    debounceTimer?.cancel();
    subscription.cancel();
  });
}

/// Helper to compare two sets for equality
bool _setsEqual<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
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

/// Divine-hosted-only filter preference service.
final divineHostFilterServiceProvider = Provider<DivineHostFilterService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final service = DivineHostFilterService(prefs);
  ref.onDispose(service.dispose);
  return service;
});

/// Rebuild trigger for consumers that need to react to Divine-host filter
/// preference changes.
final divineHostFilterVersionProvider = Provider<int>((ref) {
  final service = ref.watch(divineHostFilterServiceProvider);
  var version = 0;

  void listener() {
    version++;
    ref.invalidateSelf();
  }

  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));
  return version;
});

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild
@Riverpod(keepAlive: true)
AgeVerificationService ageVerificationService(Ref ref) {
  final service = AgeVerificationService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Content filter service for per-category Show/Warn/Hide preferences.
/// keepAlive ensures preferences persist and are consistent across the app.
@Riverpod(keepAlive: true)
ContentFilterService contentFilterService(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final service = ContentFilterService(
    ageVerificationService: ageVerificationService,
  );
  service.initialize(); // Initialize asynchronously
  ref.onDispose(service.dispose);
  return service;
}

/// Tracks content filter preference changes. Feed providers watch this
/// to rebuild when the user changes a Show/Warn/Hide setting.
@Riverpod(keepAlive: true)
int contentFilterVersion(Ref ref) {
  final service = ref.watch(contentFilterServiceProvider);
  var version = 0;
  void listener() {
    version++;
    ref.invalidateSelf();
  }

  service.addListener(listener);
  ref.onDispose(() => service.removeListener(listener));
  return version;
}

/// Account label service for self-labeling content (NIP-32 Kind 1985).
@Riverpod(keepAlive: true)
AccountLabelService accountLabelService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final nostrClient = ref.watch(nostrServiceProvider);
  final service = AccountLabelService(
    authService: authService,
    nostrClient: nostrClient,
  );
  service.initialize();
  return service;
}

/// Moderation label service for subscribing to Kind 1985 labeler events.
@Riverpod(keepAlive: true)
ModerationLabelService moderationLabelService(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final followRepository = ref.watch(followRepositoryProvider);
  final service = ModerationLabelService(
    nostrClient: nostrClient,
    authService: authService,
    sharedPreferences: prefs,
  );
  unawaited(
    service.initialize().then((_) {
      return service.syncFollowedLabelers(followRepository.followingPubkeys);
    }),
  );
  final followingSubscription = followRepository.followingStream.listen((
    pubkeys,
  ) {
    unawaited(service.syncFollowedLabelers(pubkeys));
  });
  ref.onDispose(() {
    followingSubscription.cancel();
    service.dispose();
  });
  return service;
}

/// Audio sharing preference service for managing whether audio is available
/// for reuse by default. keepAlive ensures setting persists across widget rebuilds.
@Riverpod(keepAlive: true)
AudioSharingPreferenceService audioSharingPreferenceService(Ref ref) {
  final service = AudioSharingPreferenceService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// AI training opt-out preference service. Controls whether the
/// CAWG training-mining assertion is embedded in C2PA manifests.
/// keepAlive ensures setting persists across widget rebuilds.
@Riverpod(keepAlive: true)
AiTrainingPreferenceService aiTrainingPreferenceService(Ref ref) {
  final service = AiTrainingPreferenceService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Audio device preference service for managing the preferred input device
/// for recording on macOS. keepAlive ensures preference persists.
@Riverpod(keepAlive: true)
AudioDevicePreferenceService audioDevicePreferenceService(Ref ref) {
  final service = AudioDevicePreferenceService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Language preference service for managing the user's preferred content
/// language. Used for NIP-32 self-labeling on published video events.
/// keepAlive ensures setting persists across widget rebuilds.
@Riverpod(keepAlive: true)
LanguagePreferenceService languagePreferenceService(Ref ref) {
  final service = LanguagePreferenceService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Geo-blocking service for regional compliance
@riverpod
GeoBlockingService geoBlockingService(Ref ref) {
  return GeoBlockingService();
}

/// Permissions service for checking and requesting OS permissions
@riverpod
PermissionsService permissionsService(Ref ref) {
  return const PermissionHandlerPermissionsService();
}

/// Gallery save service for saving videos to device camera roll
@riverpod
GallerySaveService gallerySaveService(Ref ref) {
  return GallerySaveService(
    permissionsService: ref.watch(permissionsServiceProvider),
  );
}

/// Secure key storage service (foundational service)
@Riverpod(keepAlive: true)
SecureKeyStorage secureKeyStorage(Ref ref) {
  return SecureKeyStorage();
}

// =============================================================================
// OAUTH SERVICES
// =============================================================================

/// OAuth configuration — uses local keycast when running in local environment
const _productionLoginOrigin = 'https://login.divine.video';

@Riverpod(keepAlive: true)
OAuthConfig oauthConfig(Ref ref) {
  final env = ref.watch(currentEnvironmentProvider);
  if (env.environment == AppEnvironment.local) {
    return const OAuthConfig(
      serverUrl: 'http://$localHost:$localKeycastPort',
      clientId: 'divine-mobile',
      redirectUri: 'http://localhost:$localKeycastPort/app/callback',
    );
  }
  return const OAuthConfig(
    serverUrl: _productionLoginOrigin,
    clientId: 'divine-mobile',
    redirectUri: 'https://divine.video/app/callback',
  );
}

@Riverpod(keepAlive: true)
FlutterSecureStorage flutterSecureStorage(Ref ref) =>
    const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
      mOptions: MacOsOptions(useDataProtectionKeyChain: false),
    );

@Riverpod(keepAlive: true)
SecureKeycastStorage secureKeycastStorage(Ref ref) =>
    SecureKeycastStorage(ref.watch(flutterSecureStorageProvider));

@Riverpod(keepAlive: true)
PendingVerificationService pendingVerificationService(Ref ref) =>
    PendingVerificationService(ref.watch(flutterSecureStorageProvider));

@Riverpod(keepAlive: true)
KeycastOAuth oauthClient(Ref ref) {
  final config = ref.watch(oauthConfigProvider);
  final storage = ref.watch(secureKeycastStorageProvider);

  final oauth = KeycastOAuth(config: config, storage: storage);

  ref.onDispose(oauth.close);

  return oauth;
}

@Riverpod(keepAlive: true)
PasswordResetListener passwordResetListener(Ref ref) {
  final listener = PasswordResetListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
}

@Riverpod(keepAlive: true)
EmailVerificationListener emailVerificationListener(Ref ref) {
  final listener = EmailVerificationListener(ref);
  ref.onDispose(listener.dispose);
  return listener;
}

/// Web authentication service (for web platform only)
@riverpod
WebAuthService webAuthService(Ref ref) {
  return WebAuthService();
}

/// Nostr key manager for cryptographic operations
@Riverpod(keepAlive: true)
NostrKeyManager nostrKeyManager(Ref ref) {
  return NostrKeyManager();
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

/// Content blocklist service for filtering unwanted content from feeds
///
/// Injects SharedPreferences for local block persistence across restarts.
/// Nostr publishing (kind 30000) is initialized via [syncBlockListsInBackground]
/// during app startup in main.dart.
///
/// keepAlive ensures the relay subscription created by
/// [syncBlockListsInBackground] survives widget rebuilds. Without it the
/// provider auto-disposes, the subscription is lost, and blocks restored
/// from the relay are never delivered to new instances.
@Riverpod(keepAlive: true)
ContentBlocklistService contentBlocklistService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ContentBlocklistService(
    prefs: prefs,
    onChanged: () {
      if (!ref.mounted) return;
      ref.read(blocklistVersionProvider.notifier).increment();
    },
  );
}

/// Version counter to trigger rebuilds when blocklist changes.
/// Widgets watching this will rebuild when block/unblock actions occur.
@riverpod
class BlocklistVersion extends _$BlocklistVersion {
  @override
  int build() => 0;

  void increment() => state++;
}

/// Bridge that starts blocklist sync when the user becomes authenticated.
///
/// Watch this at app shell level. It listens to [authStateStream] and
/// triggers [syncMuteListsInBackground] + [syncBlockListsInBackground]
/// the first time the user is authenticated. This covers:
/// - Already-authenticated startup (iOS keychain persists across reinstalls)
/// - Post-login authentication (Android wipes credentials on uninstall)
///
/// Both sync methods have internal guards (`_mutualMuteSyncStarted`,
/// `_blockListSyncStarted`) so duplicate calls are no-ops.
@Riverpod(keepAlive: true)
void blocklistSyncBridge(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final blocklistService = ref.watch(contentBlocklistServiceProvider);

  Future<void> startSync() async {
    // Use authService.currentPublicKeyHex — it is available immediately
    // after authentication, unlike nostrKeyManagerProvider which loads
    // its keys asynchronously via RPC and may not be ready yet.
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null) return;

    try {
      await Future.wait([
        blocklistService.syncMuteListsInBackground(nostrService, pubkey),
        blocklistService.syncBlockListsInBackground(
          nostrService,
          authService,
          pubkey,
        ),
      ]);
      Log.info(
        '[BRIDGE] Block/mute list sync started',
        name: 'BlocklistSyncBridge',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        '[BRIDGE] Block/mute list sync failed (non-critical): $e',
        name: 'BlocklistSyncBridge',
        category: LogCategory.system,
      );
    }
  }

  // Sync immediately if already authenticated
  if (authService.isAuthenticated && authService.currentPublicKeyHex != null) {
    unawaited(startSync());
  }

  // Also listen for future auth transitions (e.g. post-reinstall login)
  final subscription = authService.authStateStream.listen((authState) {
    if (authState == AuthState.authenticated) {
      unawaited(startSync());
    }
  });

  ref.onDispose(subscription.cancel);
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

/// Authentication service
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final keyStorage = ref.watch(secureKeyStorageProvider);
  final nostrKeyManager = ref.watch(nostrKeyManagerProvider);
  final userDataCleanupService = ref.watch(userDataCleanupServiceProvider);
  final oauthClient = ref.watch(oauthClientProvider);
  final flutterSecureStorage = ref.watch(flutterSecureStorageProvider);
  final oauthConfig = ref.watch(oauthConfigProvider);
  final pendingVerificationService = ref.watch(
    pendingVerificationServiceProvider,
  );
  // NOTE: We construct FunnelcakeApiClient directly here instead of using
  // funnelcakeApiClientProvider to avoid a circular dependency:
  //   authService → funnelcakeApiClient → nostrService → authService
  // Using currentEnvironmentProvider is safe (no auth/nostr dependency).
  final authEnv = ref.read(currentEnvironmentProvider);
  return AuthService(
    userDataCleanupService: userDataCleanupService,
    keyStorage: keyStorage,
    nostrKeyManager: nostrKeyManager,
    oauthClient: oauthClient,
    flutterSecureStorage: flutterSecureStorage,
    oauthConfig: oauthConfig,
    pendingVerificationService: pendingVerificationService,
    profileCheckIndexerUrl: authEnv.indexerRelays.first,
    indexerRelays: authEnv.indexerRelays,
    preFetchFollowing: (pubkeyHex) async {
      // Pre-fetch following list from funnelcake REST API during login
      // setup. This populates SharedPreferences BEFORE auth state is
      // set, so the router redirect has accurate cache data and sends
      // user to /home not /explore.
      final environmentConfig = ref.read(currentEnvironmentProvider);
      final client = FunnelcakeApiClient(baseUrl: environmentConfig.apiBaseUrl);
      final prefs = ref.read(sharedPreferencesProvider);
      final result = await client.getFollowing(pubkey: pubkeyHex, limit: 5000);
      if (result.pubkeys.isNotEmpty) {
        final key = 'following_list_$pubkeyHex';
        await prefs.setString(key, jsonEncode(result.pubkeys));
        Log.info(
          'Pre-fetched ${result.pubkeys.length} following for '
          'router redirect cache',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    },
  );
}

/// Provider that returns current auth state and rebuilds when it changes.
/// Widgets should watch this instead of authService.authState directly
/// to get automatic rebuilds when authentication state changes.
@Riverpod(keepAlive: true)
AuthState currentAuthState(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Listen to auth state changes and invalidate this provider when they occur
  final subscription = authService.authStateStream.listen((_) {
    // Invalidate to trigger rebuild with new state
    ref.invalidateSelf();
  });

  // Clean up subscription when provider is disposed
  ref.onDispose(subscription.cancel);

  // Return current state
  return authService.authState;
}

/// Provider that returns current RPC capability and rebuilds on changes.
///
/// Widgets and repositories should watch this instead of polling
/// [AuthService.authRpcCapability] directly.
@Riverpod(keepAlive: true)
AuthRpcCapability currentAuthRpcCapability(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  final subscription = authService.authRpcCapabilityStream.listen((_) {
    ref.invalidateSelf();
  });

  ref.onDispose(subscription.cancel);

  return authService.authRpcCapability;
}

/// Provider that fetches the list of known accounts from the auth service.
///
/// Invalidate this provider after sign-in or sign-out to refresh the list.
@riverpod
Future<List<KnownAccount>> knownAccounts(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  // Rebuild when auth state changes so the list stays current.
  ref.watch(currentAuthStateProvider);
  return authService.getKnownAccounts();
}

/// Provider for user-signed creator-binding assertions.
final nostrCreatorBindingServiceProvider = Provider<NostrCreatorBindingService>(
  (ref) {
    ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);
    return NostrCreatorBindingService(identity: authService.currentIdentity);
  },
);

/// Provider for the CAWG verifier base URI.
final cawgVerifierBaseUriProvider = Provider<Uri>((ref) {
  return Uri.parse(
    const String.fromEnvironment(
      'CAWG_VERIFIER_BASE_URL',
      defaultValue: 'https://verifier.divine.video',
    ),
  );
});

/// Provider for the optional CAWG identity verifier client.
final cawgVerifierClientProvider = Provider<CawgVerifierClient>((ref) {
  final baseUri = ref.watch(cawgVerifierBaseUriProvider);
  final client = CawgVerifierClient(baseUri: baseUri);
  ref.onDispose(client.dispose);
  return client;
});

/// Provider that returns true only when NostrClient is fully ready for operations.
/// Combines auth state check AND nostrClient.hasKeys verification.
/// Use this to guard providers that require authenticated NostrClient access.
///
/// This prevents race conditions where auth state is 'authenticated' but
/// the NostrClient hasn't yet rebuilt with the new keys.
///
/// NostrClient.initialize() runs asynchronously in a Future.microtask after
/// NostrService.build() returns. Riverpod can't detect when hasKeys transitions
/// because it's the same object reference. When not ready but authenticated,
/// we schedule brief retries to catch the async initialization.
@Riverpod(keepAlive: true)
bool isNostrReady(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild when auth changes
  ref.watch(currentAuthStateProvider);

  if (!authService.isAuthenticated) {
    return false;
  }

  final nostrClient = ref.watch(nostrServiceProvider);
  final ready = nostrClient.hasKeys;

  if (!ready) {
    // NostrClient.initialize() runs asynchronously in a Future.microtask
    // after NostrService.build() returns. Riverpod can't detect when
    // hasKeys transitions because it's the same object reference.
    // Poll with a periodic timer until hasKeys becomes true.
    const pollInterval = Duration(milliseconds: 50);
    final timer = Timer.periodic(pollInterval, (timer) {
      if (nostrClient.hasKeys) {
        timer.cancel();
        Log.info(
          'isNostrReady: NostrClient.hasKeys became true after '
          '${timer.tick * pollInterval.inMilliseconds}ms, invalidating',
          name: 'isNostrReadyProvider',
          category: LogCategory.system,
        );
        ref.invalidateSelf();
      }
    });
    ref.onDispose(timer.cancel);
  }

  return ready;
}

/// Provider that sets Zendesk user identity when auth state changes
/// Watch this provider at app startup to keep Zendesk identity in sync with auth
@Riverpod(keepAlive: true)
void zendeskIdentitySync(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);

  // Set initial identity if already authenticated
  if (authService.isAuthenticated && authService.currentPublicKeyHex != null) {
    _setZendeskIdentity(
      authService.currentPublicKeyHex!,
      profileRepository,
      ref,
    );
  }

  // Listen to auth state changes
  final subscription = authService.authStateStream.listen((authState) async {
    if (authState == AuthState.authenticated) {
      final pubkeyHex = authService.currentPublicKeyHex;
      if (pubkeyHex != null) {
        await _setZendeskIdentity(pubkeyHex, profileRepository, ref);
      }
    } else if (authState == AuthState.unauthenticated) {
      await ZendeskSupportService.clearUserIdentity();
      Log.info(
        'Zendesk identity cleared on logout',
        name: 'ZendeskIdentitySync',
        category: LogCategory.system,
      );
    }
  });

  ref.onDispose(subscription.cancel);
}

/// Bridges auth state changes to push notification registration.
///
/// Registers FCM token on login, deregisters on logout.
/// Same pattern as [zendeskIdentitySync].
@Riverpod(keepAlive: true)
void pushNotificationSync(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  Future<void> requestPermissionAndRegister(String pubkey) async {
    try {
      final firebaseMessaging = ref.read(firebaseMessagingProvider);
      final pushService = ref.read(pushNotificationServiceProvider);

      // Only prompt the user if permission has never been decided. Rapid
      // auth state changes (account switching, E2E tests) otherwise cause
      // concurrent `requestPermission` calls, and Firebase throws
      // `PlatformException([firebase_messaging/unknown] A request for
      // permissions is already running)` — silently losing FCM registration
      // in production and failing E2E tests via unhandled async errors.
      final current = await firebaseMessaging.getNotificationSettings();
      final settings =
          current.authorizationStatus == AuthorizationStatus.notDetermined
          ? await firebaseMessaging.requestPermission()
          : current;

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        Log.info(
          'Push notification permission denied by user',
          name: 'PushNotificationSync',
          category: LogCategory.system,
        );
        return;
      }

      await pushService.register(pubkey);
    } catch (e) {
      // Push registration is non-critical — a failure must not propagate
      // out of this async stream listener. If it did, the uncaught error
      // would reach the test binding's `handleUncaughtError` and fail the
      // surrounding integration test.
      Log.warning(
        'Push notification registration failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  }

  String? lastAuthenticatedPubkey = authService.currentPublicKeyHex;
  if (authService.authState == AuthState.authenticated &&
      lastAuthenticatedPubkey != null) {
    unawaited(requestPermissionAndRegister(lastAuthenticatedPubkey));
  }

  // React to auth state changes
  final subscription = authService.authStateStream.listen((authState) async {
    try {
      final currentPubkey = authService.currentPublicKeyHex;
      if (authState == AuthState.authenticated && currentPubkey != null) {
        lastAuthenticatedPubkey = currentPubkey;
        await requestPermissionAndRegister(currentPubkey);
      } else if (authState == AuthState.unauthenticated &&
          lastAuthenticatedPubkey != null) {
        await ref
            .read(pushNotificationServiceProvider)
            .deregister(lastAuthenticatedPubkey!);
      }
    } catch (e) {
      // Never let push/deregister errors escape the listener — see
      // `requestPermissionAndRegister` for context.
      Log.warning(
        'Push notification sync listener failed: $e',
        name: 'PushNotificationSync',
        category: LogCategory.system,
      );
    }
  });

  // Set up foreground message handler
  final onMessageSubscription = ref.read(firebaseOnMessageProvider).listen((
    message,
  ) {
    final pushService = ref.read(pushNotificationServiceProvider);
    pushService.handleForegroundMessage(message.data);
  });

  ref.onDispose(() {
    subscription.cancel();
    onMessageSubscription.cancel();
  });
}

/// Helper to set Zendesk identity from pubkey
Future<void> _setZendeskIdentity(
  String pubkeyHex,
  ProfileRepository? profileRepository,
  Ref ref,
) async {
  try {
    final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
    final profile = await profileRepository?.getCachedProfile(
      pubkey: pubkeyHex,
    );

    // 1. Store user info locally (for REST API fallback)
    ZendeskSupportService.setUserIdentity(
      displayName: profile?.bestDisplayName,
      nip05: profile?.nip05,
      npub: npub,
    );

    // 2. Set anonymous identity on native SDK immediately (no network call)
    // This ensures createTicket() works for content reports right away
    await ZendeskSupportService.setAnonymousIdentityWithUserInfo();

    // 3. Upgrade to JWT identity asynchronously (network call)
    // If this fails, anonymous identity remains and tickets still work
    try {
      final nip98Service = ref.read(nip98AuthServiceProvider);
      final relayManagerUrl = ref
          .read(currentEnvironmentProvider)
          .relayManagerApiUrl;

      // Store auth context so the service can refresh JWT before each SDK action.
      // The pre-auth token has a 5-minute TTL, so any delay between login and
      // ticket creation would fail without a refresh.
      ZendeskSupportService.storeAuthContext(
        nip98Service: nip98Service,
        relayManagerUrl: relayManagerUrl,
      );

      final jwtSet = await ZendeskSupportService.setJwtIdentity(
        nip98Service: nip98Service,
        relayManagerUrl: relayManagerUrl,
      );

      if (jwtSet) {
        Log.info(
          'Zendesk JWT identity set for user',
          name: 'ZendeskIdentitySync',
          category: LogCategory.system,
        );
      } else {
        Log.info(
          'Zendesk JWT upgrade failed, anonymous identity active',
          name: 'ZendeskIdentitySync',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.info(
        'Zendesk JWT upgrade failed ($e), anonymous identity active',
        name: 'ZendeskIdentitySync',
        category: LogCategory.system,
      );
    }

    Log.info(
      'Zendesk identity set for user: ${profile?.bestDisplayName ?? npub}',
      name: 'ZendeskIdentitySync',
      category: LogCategory.system,
    );
  } catch (e) {
    Log.warning(
      'Failed to set Zendesk identity: $e',
      name: 'ZendeskIdentitySync',
      category: LogCategory.system,
    );
  }
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
  service.onDatabaseCleanup = () async {
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
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
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
  service.setBlocklistService(blocklistService);
  service.setAgeVerificationService(ageVerificationService);
  service.setLikesRepository(likesRepository);
  service.setContentFilterService(ref.watch(contentFilterServiceProvider));
  service.setModerationLabelService(moderationLabelService);
  service.setDivineHostFilterService(divineHostFilterService);
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
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);

  return SocialService(
    nostrService,
    authService,
    personalEventCache: personalEventCache,
  );
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

  // Listen for isNostrReady changes to re-initialize when keys become available.
  // This handles the case where the provider was created before keys were loaded.
  ref.listen<bool>(isNostrReadyProvider, (previous, next) {
    if (previous == false && next && !repository.isInitialized) {
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
  // Return null if NostrClient is not ready yet
  // This prevents race conditions during auth where auth state is 'authenticated'
  // but NostrClient hasn't yet rebuilt with the new keys.
  // The provider will rebuild when isNostrReady becomes true.
  if (!ref.watch(isNostrReadyProvider)) {
    return null;
  }

  final nostrClient = ref.watch(nostrServiceProvider);
  final userProfilesDao = ref.watch(databaseProvider).userProfilesDao;
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);

  final env = ref.watch(currentEnvironmentProvider);

  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final repo = ProfileRepository(
    nostrClient: nostrClient,
    userProfilesDao: userProfilesDao,
    profileStatsDao: ref.watch(databaseProvider).profileStatsDao,
    httpClient: Client(),
    funnelcakeApiClient: funnelcakeClient,
    indexerRelays: env.indexerRelays,
    profileSearchFilter: (query, profiles) =>
        SearchUtils.searchProfiles(query, profiles, limit: 50),
    blockFilter: blocklistService.shouldFilterFromFeeds,
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

/// Enhanced notification service with Nostr integration (lazy loaded)
@riverpod
NotificationServiceEnhanced notificationServiceEnhanced(Ref ref) {
  final service = NotificationServiceEnhanced();

  // Delay initialization until after critical path is loaded
  if (!kIsWeb) {
    // Initialize on mobile - wait for keys to be available
    final nostrService = ref.watch(nostrServiceProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);
    final videoService = ref.watch(videoEventServiceProvider);

    Future.microtask(() async {
      try {
        // Wait for Nostr keys to be loaded before initializing notifications
        // Keys may take a moment to load from secure storage
        var retries = 0;
        while (!nostrService.hasKeys && retries < 30) {
          // Wait 500ms between checks, up to 15 seconds total
          await Future.delayed(const Duration(milliseconds: 500));
          retries++;
        }

        if (!nostrService.hasKeys) {
          Log.warning(
            'Notification service initialization skipped - no Nostr keys available after 15s',
            name: 'AppProviders',
            category: LogCategory.system,
          );
          return;
        }

        if (profileRepository == null) {
          Log.warning(
            'Notification service initialization skipped - ProfileRepository not ready',
            name: 'AppProviders',
            category: LogCategory.system,
          );
          return;
        }

        await service.initialize(
          nostrService: nostrService,
          profileRepository: profileRepository,
          videoService: videoService,
        );
      } catch (e) {
        Log.error(
          'Failed to initialize enhanced notification service: $e',
          name: 'AppProviders',
          category: LogCategory.system,
        );
      }
    });
  } else {
    // On web, delay initialization by 3 seconds to allow main UI to load first
    Timer(const Duration(seconds: 3), () async {
      try {
        final nostrService = ref.read(nostrServiceProvider);
        final profileRepository = ref.read(profileRepositoryProvider);
        final videoService = ref.read(videoEventServiceProvider);

        if (profileRepository == null) return;

        await service.initialize(
          nostrService: nostrService,
          profileRepository: profileRepository,
          videoService: videoService,
        );
      } catch (e) {
        Log.error(
          'Failed to initialize enhanced notification service: $e',
          name: 'AppProviders',
          category: LogCategory.system,
        );
      }
    });
  }

  return service;
}

// VideoManagerService removed - using pure Riverpod VideoManager provider instead

/// NIP-98 authentication service
@riverpod
Nip98AuthService nip98AuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return Nip98AuthService(authService: authService);
}

/// Blossom BUD-01 authentication service for age-restricted content
@riverpod
BlossomAuthService blossomAuthService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return BlossomAuthService(
    authProvider: _BlossomAuthAdapter(authService),
  );
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
  final mediaViewerAuthService = ref.watch(mediaViewerAuthServiceProvider);
  return MediaAuthInterceptor(
    ageVerificationService: ageVerificationService,
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

  return VideoEventPublisher(
    uploadManager: uploadManager,
    nostrService: nostrService,
    authService: authService,
    personalEventCache: personalEventCache,
    videoEventService: videoEventService,
    blossomUploadService: blossomUploadService,
    profileRepository: profileRepository,
    profileStatsDao: profileStatsDao,
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
CurationService curationService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final likesRepository = ref.watch(likesRepositoryProvider);
  final authService = ref.watch(authServiceProvider);

  return CurationService(
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
  final service = ContentReportingService(
    nostrService: nostrService,
    authService: authService,
    prefs: prefs,
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

/// User list service for NIP-51 kind 30000 people lists
@riverpod
Future<UserListService> userListService(Ref ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);

  final service = UserListService(prefs: prefs);

  // Initialize the service to load lists
  await service.initialize();

  return service;
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
VideoSharingService videoSharingService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final profileRepository = ref.watch(profileRepositoryProvider);
  final dmRepository = ref.watch(dmRepositoryProvider);

  return VideoSharingService(
    nostrService: nostrService,
    authService: authService,
    profileRepository: profileRepository!,
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

/// Account Deletion Service for NIP-62 Request to Vanish
@riverpod
AccountDeletionService accountDeletionService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  return AccountDeletionService(
    nostrService: nostrService,
    authService: authService,
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
/// dependency rebuilds (e.g. `isNostrReadyProvider` polling,
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
    syncState: DmSyncState(prefs),
  );

  ref.onDispose(repository.stopListening);

  // Set credentials and open the gift-wrap subscription as soon as the
  // signer is ready. The subscription is auth-session-scoped (not inbox-
  // scoped) so DMs are ingested even when the user never visits /inbox.
  // See docs/plans/2026-04-05-dm-scaling-fix-design.md and #2931.
  if (ref.watch(isNostrReadyProvider)) {
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
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final repository = CommentsRepository(
    nostrClient: nostrClient,
    funnelcakeApiClient: funnelcakeClient,
    blockFilter: blocklistService.shouldFilterFromFeeds,
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
/// - ContentBlocklistService for filtering blocked/muted users
/// - ContentFilterService for filtering NSFW content based on user preferences
/// - FunnelcakeApiClient for trending/popular video sorting
@Riverpod(keepAlive: true)
VideosRepository videosRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final localStorage = ref.watch(videoLocalStorageProvider);
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final contentFilterService = ref.watch(contentFilterServiceProvider);
  final moderationLabelService = ref.watch(moderationLabelServiceProvider);
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);
  final divineHostFilterService = ref.read(divineHostFilterServiceProvider);

  final nsfwFilter = createNsfwFilter(
    contentFilterService,
    moderationLabelService: moderationLabelService,
  );

  return VideosRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    blockFilter: createBlocklistFilter(blocklistService),
    contentFilter: (video) =>
        nsfwFilter(video) ||
        (divineHostFilterService.showDivineHostedOnly &&
            !video.isFromDivineServer),
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
/// [BridgeAuthProvider] interface.
class _AuthServiceBridgeAdapter implements BridgeAuthProvider {
  const _AuthServiceBridgeAdapter(this._authService);

  final AuthService _authService;

  @override
  String? get currentPublicKeyHex => _authService.currentPublicKeyHex;

  @override
  List<BridgeRelay> get userRelays => _authService.userRelays
      .map((r) => BridgeRelay(url: r.url, read: r.read, write: r.write))
      .toList();

  @override
  Future<BridgeSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  }) async {
    final event = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
      createdAt: createdAt,
    );
    if (event == null) return null;
    return BridgeSignedEvent(json: event.toJson());
  }
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
