// ABOUTME: Comprehensive Riverpod providers for all application services
// ABOUTME: Replaces Provider MultiProvider setup with pure Riverpod dependency injection

import 'dart:async';
import 'dart:core';

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:nostr_client/nostr_client.dart'
    show RelayConnectionStatus, RelayState;
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/providers/video_repository_provider.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/audio_playback_service.dart';
import 'package:openvine/services/audio_device_preference_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/blocklist_content_filter.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/event_router.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:openvine/services/hashtag_cache_service.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/utils/search_utils.dart';
import 'package:openvine/services/media_auth_interceptor.dart';
import 'package:openvine/services/mute_service.dart';
import 'package:openvine/services/nip05_service.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/nsfw_content_filter.dart';
import 'package:openvine/services/email_verification_listener.dart';
import 'package:openvine/services/password_reset_listener.dart';
import 'package:openvine/services/pending_action_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/profile_cache_service.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscribed_list_video_cache.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/services/video_visibility_manager.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:videos_repository/videos_repository.dart';

part 'app_providers.g.dart';

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

/// Relay capability service for detecting NIP-11 divine extensions
@Riverpod(keepAlive: true)
RelayCapabilityService relayCapabilityService(Ref ref) {
  final service = RelayCapabilityService();
  ref.onDispose(() => service.dispose());
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
  ref.onDispose(() => service.dispose());
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

/// Bridge provider that connects NostrClient relay status updates to RelayStatisticsService
/// Must be watched at app level to activate the bridge
@Riverpod(keepAlive: true)
void relayStatisticsBridge(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final statsService = ref.watch(relayStatisticsServiceProvider);

  // Track previous states to detect changes
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

    // Prune entries for relays no longer in the status map to prevent memory leak
    previousStates.removeWhere((url, _) => !statuses.containsKey(url));
  }

  // Process current state immediately (relays may have connected before bridge started)
  processStatuses(nostrService.relayStatuses);

  // Listen to relay status stream for future updates
  final subscription = nostrService.relayStatusStream.listen(processStatuses);

  ref.onDispose(() {
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

/// Analytics service with opt-out support
@Riverpod(keepAlive: true) // Keep alive to maintain singleton behavior
AnalyticsService analyticsService(Ref ref) {
  final service = AnalyticsService();

  // Ensure cleanup on disposal
  ref.onDispose(() {
    service.dispose();
  });

  // Initialize asynchronously but don't block the provider
  // Use a microtask to avoid blocking the provider creation
  Future.microtask(() => service.initialize());

  return service;
}

/// Age verification service for content creation restrictions
/// keepAlive ensures the service persists and maintains in-memory verification state
/// even when widgets that watch it dispose and rebuild
@Riverpod(keepAlive: true)
AgeVerificationService ageVerificationService(Ref ref) {
  final service = AgeVerificationService();
  service.initialize(); // Initialize asynchronously
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

/// Audio device preference service for managing the preferred input device
/// for recording on macOS. keepAlive ensures preference persists.
@Riverpod(keepAlive: true)
AudioDevicePreferenceService audioDevicePreferenceService(Ref ref) {
  final service = AudioDevicePreferenceService();
  service.initialize(); // Initialize asynchronously
  return service;
}

/// Geo-blocking service for regional compliance
@riverpod
GeoBlockingService geoBlockingService(Ref ref) {
  return GeoBlockingService();
}

/// Secure key storage service (foundational service)
@Riverpod(keepAlive: true)
SecureKeyStorage secureKeyStorage(Ref ref) {
  return SecureKeyStorage();
}

// =============================================================================
// OAUTH SERVICES
// =============================================================================

/// OAuth configuration for our login.divine.video server
@Riverpod(keepAlive: true)
OAuthConfig oauthConfig(Ref ref) {
  return const OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'divine-mobile',
    redirectUri: 'https://divine.video/app/callback',
  );
}

@Riverpod(keepAlive: true)
FlutterSecureStorage flutterSecureStorage(Ref ref) => FlutterSecureStorage(
  aOptions: const AndroidOptions(
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

  ref.onDispose(() => oauth.close());

  return oauth;
}

@Riverpod(keepAlive: true)
PasswordResetListener passwordResetListener(Ref ref) {
  final listener = PasswordResetListener(ref);
  ref.onDispose(() => listener.dispose());
  return listener;
}

@Riverpod(keepAlive: true)
EmailVerificationListener emailVerificationListener(Ref ref) {
  final listener = EmailVerificationListener(ref);
  ref.onDispose(() => listener.dispose());
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

/// Profile cache service for persistent profile storage
/// keepAlive to avoid expensive Hive reinitialization on auth state changes
@Riverpod(keepAlive: true)
ProfileCacheService profileCacheService(Ref ref) {
  final service = ProfileCacheService();
  // Initialize asynchronously to avoid blocking UI
  service.initialize().catchError((e) {
    Log.error(
      'Failed to initialize ProfileCacheService',
      name: 'AppProviders',
      error: e,
    );
  });

  ref.onDispose(() => service.dispose());

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

/// Content blocklist service for filtering unwanted content from feeds
@riverpod
ContentBlocklistService contentBlocklistService(Ref ref) {
  return ContentBlocklistService();
}

/// Version counter to trigger rebuilds when blocklist changes.
/// Widgets watching this will rebuild when block/unblock actions occur.
@riverpod
class BlocklistVersion extends _$BlocklistVersion {
  @override
  int build() => 0;

  void increment() => state++;
}

/// NIP-05 service for username availability checking
@riverpod
Nip05Service nip05Service(Ref ref) {
  return Nip05Service();
}

/// Username repository for availability checking
@riverpod
UsernameRepository usernameRepository(Ref ref) {
  final nip05Service = ref.watch(nip05ServiceProvider);
  return UsernameRepository(nip05Service);
}

/// Draft storage service for persisting vine drafts
@riverpod
Future<DraftStorageService> draftStorageService(Ref ref) async {
  return DraftStorageService();
}

/// Clip library service for persisting individual video clips
@riverpod
ClipLibraryService clipLibraryService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ClipLibraryService(prefs);
}

// (Removed duplicate legacy provider for StreamUploadService)

// =============================================================================
// DEPENDENT SERVICES (With dependencies)
// =============================================================================

/// Authentication service
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final keyStorage = ref.watch(secureKeyStorageProvider);
  final userDataCleanupService = ref.watch(userDataCleanupServiceProvider);
  final oauthClient = ref.watch(oauthClientProvider);
  final flutterSecureStorage = ref.watch(flutterSecureStorageProvider);
  final oauthConfig = ref.watch(oauthConfigProvider);
  final pendingVerificationService = ref.watch(
    pendingVerificationServiceProvider,
  );
  return AuthService(
    userDataCleanupService: userDataCleanupService,
    keyStorage: keyStorage,
    oauthClient: oauthClient,
    flutterSecureStorage: flutterSecureStorage,
    oauthConfig: oauthConfig,
    pendingVerificationService: pendingVerificationService,
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

/// Provider that returns true only when NostrClient is fully ready for operations.
/// Combines auth state check AND nostrClient.hasKeys verification.
/// Use this to guard providers that require authenticated NostrClient access.
///
/// This prevents race conditions where auth state is 'authenticated' but
/// the NostrClient hasn't yet rebuilt with the new keys.
@Riverpod(keepAlive: true)
bool isNostrReady(Ref ref) {
  final authService = ref.watch(authServiceProvider);

  // Watch auth state to rebuild when auth changes
  ref.watch(currentAuthStateProvider);

  if (!authService.isAuthenticated) return false;

  final nostrClient = ref.watch(nostrServiceProvider);
  return nostrClient.hasKeys;
}

/// Provider that sets Zendesk user identity when auth state changes
/// Watch this provider at app startup to keep Zendesk identity in sync with auth
@Riverpod(keepAlive: true)
void zendeskIdentitySync(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  final userProfileService = ref.watch(userProfileServiceProvider);

  // Set initial identity if already authenticated
  if (authService.isAuthenticated && authService.currentPublicKeyHex != null) {
    _setZendeskIdentity(authService.currentPublicKeyHex!, userProfileService);
  }

  // Listen to auth state changes
  final subscription = authService.authStateStream.listen((authState) async {
    if (authState == AuthState.authenticated) {
      final pubkeyHex = authService.currentPublicKeyHex;
      if (pubkeyHex != null) {
        await _setZendeskIdentity(pubkeyHex, userProfileService);
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

  ref.onDispose(() {
    subscription.cancel();
  });
}

/// Helper to set Zendesk identity from pubkey
Future<void> _setZendeskIdentity(
  String pubkeyHex,
  UserProfileService userProfileService,
) async {
  try {
    final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
    final profile = userProfileService.getCachedProfile(pubkeyHex);

    await ZendeskSupportService.setUserIdentity(
      displayName: profile?.bestDisplayName,
      nip05: profile?.nip05,
      npub: npub,
    );

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
  return UserDataCleanupService(prefs);
}

/// Subscription manager for centralized subscription management
@Riverpod(keepAlive: true)
SubscriptionManager subscriptionManager(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  return SubscriptionManager(nostrService);
}

/// Video event service depends on Nostr, SeenVideos, Blocklist, AgeVerification, SubscriptionManager, and VideoRepository
@Riverpod(keepAlive: true)
VideoEventService videoEventService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final subscriptionManager = ref.watch(subscriptionManagerProvider);
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final userProfileService = ref.watch(userProfileServiceProvider);
  final videoFilterBuilder = ref.watch(videoFilterBuilderProvider);
  final videoRepository = ref.watch(videoRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final eventRouter = EventRouter(db);

  final likesRepository = ref.watch(likesRepositoryProvider);

  final service = VideoEventService(
    nostrService,
    subscriptionManager: subscriptionManager,
    videoRepository: videoRepository,
    userProfileService: userProfileService,
    eventRouter: eventRouter,
    videoFilterBuilder: videoFilterBuilder,
  );
  service.setBlocklistService(blocklistService);
  service.setAgeVerificationService(ageVerificationService);
  service.setLikesRepository(likesRepository);
  return service;
}

/// Hashtag service depends on Video event service and cache service
@riverpod
HashtagService hashtagService(Ref ref) {
  final videoEventService = ref.watch(videoEventServiceProvider);
  final cacheService = ref.watch(hashtagCacheServiceProvider);
  return HashtagService(videoEventService, cacheService);
}

/// User profile service depends on Nostr service, SubscriptionManager, and ProfileCacheService
@Riverpod(keepAlive: true)
UserProfileService userProfileService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final subscriptionManager = ref.watch(subscriptionManagerProvider);
  final profileCache = ref.watch(profileCacheServiceProvider);
  final analyticsService = ref.watch(analyticsApiServiceProvider);

  // Use centralized funnelcake availability check (capability detection)
  final funnelcakeAvailable =
      ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;

  final service = UserProfileService(
    nostrService,
    subscriptionManager: subscriptionManager,
    analyticsApiService: analyticsService,
    funnelcakeAvailable: funnelcakeAvailable,
  );
  service.setPersistentCache(profileCache);

  // Inject profile cache lookup into SubscriptionManager to avoid redundant relay requests
  subscriptionManager.setCacheLookup(hasProfileCached: service.hasProfile);

  // Listen for funnelcake availability changes
  ref.listen<AsyncValue<bool>>(funnelcakeAvailableProvider, (previous, next) {
    service.setFunnelcakeAvailable(next.asData?.value ?? false);
  });

  // Ensure cleanup on disposal
  ref.onDispose(() {
    service.dispose();
  });

  return service;
}

/// Social service depends on Nostr service and Auth service
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

/// Provider for FollowRepository instance
///
/// Creates a FollowRepository for managing follow relationships.
/// Requires authentication.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - PersonalEventCacheService (for caching contact list events)
@Riverpod(keepAlive: true)
FollowRepository? followRepository(Ref ref) {
  // Return null if NostrClient is not ready yet
  // This prevents race conditions during auth where auth state is 'authenticated'
  // but NostrClient hasn't yet rebuilt with the new keys.
  // The provider will rebuild when isNostrReady becomes true.
  if (!ref.watch(isNostrReadyProvider)) {
    return null;
  }

  final nostrClient = ref.watch(nostrServiceProvider);
  final personalEventCache = ref.watch(personalEventCacheServiceProvider);

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);

  final repository = FollowRepository(
    nostrClient: nostrClient,
    personalEventCache: personalEventCache,
    isOnline: () => connectionStatus.isOnline,
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

  ref.onDispose(repository.dispose);

  return repository;
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
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final funnelcakeClient = ref.watch(funnelcakeApiClientProvider);

  return ProfileRepository(
    nostrClient: nostrClient,
    userProfilesDao: userProfilesDao,
    httpClient: Client(),
    funnelcakeApiClient: funnelcakeClient,
    userBlockFilter: blocklistService.shouldFilterFromFeeds,
    profileSearchFilter: (query, profiles) =>
        SearchUtils.searchProfiles(query, profiles, minScore: 0.3, limit: 50),
  );
}

// ProfileStatsProvider is now handled by profile_stats_provider.dart with pure Riverpod

/// Enhanced notification service with Nostr integration (lazy loaded)
@riverpod
NotificationServiceEnhanced notificationServiceEnhanced(Ref ref) {
  final service = NotificationServiceEnhanced();

  // Delay initialization until after critical path is loaded
  if (!kIsWeb) {
    // Initialize on mobile - wait for keys to be available
    final nostrService = ref.watch(nostrServiceProvider);
    final profileService = ref.watch(userProfileServiceProvider);
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

        await service.initialize(
          nostrService: nostrService,
          profileService: profileService,
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
        final profileService = ref.read(userProfileServiceProvider);
        final videoService = ref.read(videoEventServiceProvider);

        await service.initialize(
          nostrService: nostrService,
          profileService: profileService,
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
  return BlossomAuthService(authService: authService);
}

/// Media authentication interceptor for handling 401 unauthorized responses
@riverpod
MediaAuthInterceptor mediaAuthInterceptor(Ref ref) {
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);
  final blossomAuthService = ref.watch(blossomAuthServiceProvider);
  return MediaAuthInterceptor(
    ageVerificationService: ageVerificationService,
    blossomAuthService: blossomAuthService,
  );
}

/// Blossom upload service (uses user-configured Blossom server)
@riverpod
BlossomUploadService blossomUploadService(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  return BlossomUploadService(authService: authService);
}

/// Upload manager uses only Blossom upload service
@Riverpod(keepAlive: true)
UploadManager uploadManager(Ref ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  return UploadManager(blossomService: blossomService);
}

/// API service depends on auth service
@riverpod
ApiService apiService(Ref ref) {
  final authService = ref.watch(nip98AuthServiceProvider);
  return ApiService(authService: authService);
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
  final userProfileService = ref.watch(userProfileServiceProvider);

  return VideoEventPublisher(
    uploadManager: uploadManager,
    nostrService: nostrService,
    authService: authService,
    personalEventCache: personalEventCache,
    videoEventService: videoEventService,
    blossomUploadService: blossomUploadService,
    userProfileService: userProfileService,
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
    videoEventService: videoEventService,
    likesRepository: likesRepository,
    authService: authService,
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
@riverpod
VideoSharingService videoSharingService(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final authService = ref.watch(authServiceProvider);
  final userProfileService = ref.watch(userProfileServiceProvider);

  return VideoSharingService(
    nostrService: nostrService,
    authService: authService,
    userProfileService: userProfileService,
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
  final keyManager = ref.watch(nostrKeyManagerProvider);
  final nostrService = ref.watch(nostrServiceProvider);

  final nip17Service = NIP17MessageService(
    keyManager: keyManager,
    nostrService: nostrService,
  );

  return BugReportService(nip17MessageService: nip17Service);
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
  return CommentsRepository(nostrClient: nostrClient);
}

// =============================================================================
// VIDEOS REPOSITORY
// =============================================================================

/// Provider for VideosRepository instance
///
/// Creates a VideosRepository for loading video feeds with pagination.
/// Works without authentication for public feeds.
///
/// Uses:
/// - NostrClient from nostrServiceProvider (for relay communication)
/// - ContentBlocklistService for filtering blocked/muted users
/// - AgeVerificationService for filtering NSFW content based on user preference
@Riverpod(keepAlive: true)
VideosRepository videosRepository(Ref ref) {
  final nostrClient = ref.watch(nostrServiceProvider);
  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  final ageVerificationService = ref.watch(ageVerificationServiceProvider);

  return VideosRepository(
    nostrClient: nostrClient,
    blockFilter: createBlocklistFilter(blocklistService),
    contentFilter: createNsfwFilter(ageVerificationService),
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

  final isAuthenticated = authService.isAuthenticated;
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

  // Map AuthState stream to bool stream for repository
  final authBoolStream = authService.authStateStream.map(
    (state) => state == AuthState.authenticated,
  );

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);

  final repository = LikesRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    authStateStream: authBoolStream,
    isAuthenticated: isAuthenticated,
    isOnline: () => connectionStatus.isOnline,
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

  final isAuthenticated = authService.isAuthenticated;
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

  // Map AuthState stream to bool stream for repository
  final authBoolStream = authService.authStateStream.map(
    (state) => state == AuthState.authenticated,
  );

  // Get connection status and pending action service for offline support
  final connectionStatus = ref.watch(connectionStatusServiceProvider);
  final pendingActionService = ref.watch(pendingActionServiceProvider);

  final repository = RepostsRepository(
    nostrClient: nostrClient,
    localStorage: localStorage,
    authStateStream: authBoolStream,
    isAuthenticated: isAuthenticated,
    isOnline: () => connectionStatus.isOnline,
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

  ref.onDispose(repository.dispose);

  return repository;
}
