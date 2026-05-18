// ABOUTME: Notification-stack Riverpod providers split from app_providers.dart
// ABOUTME: FCM messaging, push registration, in-app prefs sync, dirty-state retry

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/notification_preferences_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/notification_service_enhanced.dart';
import 'package:openvine/services/push_notification_service.dart';
import 'package:openvine/services/push_notification_session_coordinator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'notifications_providers.g.dart';

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final firebaseOnMessageProvider = Provider<Stream<RemoteMessage>>(
  (ref) => FirebaseMessaging.onMessage,
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

final notificationPreferencesStoreProvider =
    Provider<NotificationPreferencesStore>((ref) {
      return const HiveNotificationPreferencesStore(
        openBox: HiveNotificationPreferencesStore.openBox,
      );
    });

final pushNotificationServiceProvider = Provider<PushNotificationService?>((
  ref,
) {
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient || readiness.client == null) {
    return null;
  }

  final authService = ref.watch(authServiceProvider);
  if (authService.currentIdentity?.pubkey != readiness.pubkey) {
    return null;
  }

  final notificationService = ref.watch(notificationServiceProvider);
  final envConfig = ref.watch(currentEnvironmentProvider);
  final firebaseMessaging = ref.watch(firebaseMessagingProvider);

  final pushService = PushNotificationService(
    authService: authService,
    nostrClient: readiness.client!,
    notificationService: notificationService,
    environmentConfig: envConfig,
    getToken: firebaseMessaging.getToken,
    isCurrent: () {
      final currentReadiness = ref.read(nostrSessionProvider);
      return currentReadiness.isReadyForActiveClient &&
          currentReadiness.pubkey == readiness.pubkey &&
          identical(currentReadiness.client, readiness.client) &&
          authService.currentIdentity?.pubkey == readiness.pubkey;
    },
  );

  ref.onDispose(pushService.dispose);
  return pushService;
});

Future<bool> _updateNotificationPreferencesSafely(
  PushNotificationService pushService,
  NotificationPreferences preferences,
) async {
  try {
    return await pushService.updatePreferences(preferences);
  } catch (e) {
    Log.warning(
      'Push notification preference publish failed: $e',
      name: 'PushNotificationSync',
      category: LogCategory.system,
    );
    return false;
  }
}

final Provider<void Function(String)>
notificationPreferencesDirtySyncBridgeProvider =
    Provider<void Function(String)>((ref) {
      const maxDirtySyncRetries = 3;
      var disposed = false;
      var drainGeneration = 0;
      final activeDrainPubkeys = <String>{};
      final retryCountsByPubkey = <String, int>{};

      ref.onDispose(() {
        disposed = true;
        drainGeneration += 1;
      });

      bool isReadyForPubkey(
        String pubkey, {
        PushNotificationService? pushService,
      }) {
        if (disposed) return false;

        final authService = ref.read(authServiceProvider);
        if (authService.currentIdentity?.pubkey != pubkey) return false;

        final readiness = ref.read(nostrSessionProvider);
        if (!readiness.isReadyForActiveClient || readiness.pubkey != pubkey) {
          return false;
        }

        return pushService == null ||
            identical(ref.read(pushNotificationServiceProvider), pushService);
      }

      Future<void> drainDirtyPreferences(String pubkey) async {
        if (!activeDrainPubkeys.add(pubkey)) return;
        final generation = ++drainGeneration;
        var shouldRetry = false;
        try {
          final preferencesService = ref.read(
            notificationPreferencesServiceProvider,
          );
          if (!isReadyForPubkey(pubkey)) return;
          final outcome = await preferencesService
              .syncDirtyPreferencesForPubkey(
                pubkey,
              );
          if (disposed || generation != drainGeneration) return;
          switch (outcome) {
            case NotificationPreferencesSyncOutcome.publishedAndCleared:
            case NotificationPreferencesSyncOutcome.nothingToDrain:
              retryCountsByPubkey.remove(pubkey);
            case NotificationPreferencesSyncOutcome.stillDirty:
              shouldRetry = isReadyForPubkey(pubkey);
          }
        } catch (e) {
          Log.warning(
            'Push notification preference drain failed: $e',
            name: 'PushNotificationSync',
            category: LogCategory.system,
          );
        } finally {
          activeDrainPubkeys.remove(pubkey);
        }

        if (!shouldRetry || disposed) return;
        final retryCount = retryCountsByPubkey[pubkey] ?? 0;
        if (retryCount >= maxDirtySyncRetries) return;
        retryCountsByPubkey[pubkey] = retryCount + 1;
        Future<void>.microtask(() {
          if (disposed || !isReadyForPubkey(pubkey)) return;
          unawaited(drainDirtyPreferences(pubkey));
        });
      }

      void scheduleDirtyPreferencesDrain(String pubkey) {
        if (disposed || !isReadyForPubkey(pubkey)) return;
        Future<void>.microtask(() {
          if (disposed || !isReadyForPubkey(pubkey)) return;
          unawaited(drainDirtyPreferences(pubkey));
        });
      }

      void handleReadiness(NostrSessionReadiness readiness) {
        final readinessPubkey = readiness.pubkey;
        if (readiness.isReadyForActiveClient && readinessPubkey != null) {
          unawaited(drainDirtyPreferences(readinessPubkey));
        }
      }

      ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, readiness) {
        handleReadiness(readiness);
      });

      Future.microtask(() => handleReadiness(ref.read(nostrSessionProvider)));
      return scheduleDirtyPreferencesDrain;
    });

final notificationPreferencesServiceProvider =
    Provider<NotificationPreferencesService>((ref) {
      final authService = ref.watch(authServiceProvider);

      return NotificationPreferencesService(
        store: ref.watch(notificationPreferencesStoreProvider),
        currentPubkey: () => authService.currentIdentity?.pubkey,
        onStillDirty: (pubkey) {
          if (!ref.mounted) return;
          ref.read(notificationPreferencesDirtySyncBridgeProvider)(pubkey);
        },
        publishPreferences: (pubkey, prefs) {
          if (authService.currentIdentity?.pubkey != pubkey) {
            return Future<bool>.value(false);
          }

          final pushService = ref.read(pushNotificationServiceProvider);
          final readiness = ref.read(nostrSessionProvider);
          if (pushService == null ||
              !readiness.isReadyForActiveClient ||
              readiness.pubkey != pubkey) {
            return Future<bool>.value(false);
          }

          return _updateNotificationPreferencesSafely(pushService, prefs);
        },
      );
    });

/// Bridges Nostr session readiness to push notification registration.
///
/// Registers FCM token only after the signer-backed Nostr client is ready.
/// Deregisters the last ready client through AuthService's pre-teardown hook so
/// outgoing-session cleanup runs before signers and callbacks are cleared.
@Riverpod(keepAlive: true)
void pushNotificationSync(Ref ref) {
  final authService = ref.watch(authServiceProvider);
  ref.watch(notificationPreferencesDirtySyncBridgeProvider);

  final coordinator = PushNotificationSessionCoordinator(
    authService: authService,
    firebaseMessaging: ref.read(firebaseMessagingProvider),
    readReadiness: () => ref.read(nostrSessionProvider),
    readPushService: () => ref.read(pushNotificationServiceProvider),
    createCleanupClient: (identity) {
      final factory = ref.read(nostrClientFactoryProvider);
      return factory(
        signer: identity,
        statisticsService: ref.read(relayStatisticsServiceProvider),
        environmentConfig: ref.read(currentEnvironmentProvider),
        dbClient: ref.read(appDbClientProvider),
      );
    },
  );

  final unregisterBeforeSessionTeardown = authService
      .registerBeforeSessionTeardownCallback(
        coordinator.deregisterLastReadyPubkey,
      );

  final authStateSubscription = authService.authStateStream.listen((_) {
    coordinator.handleAuthStateChange();
  });

  coordinator.handleReadiness(ref.read(nostrSessionProvider));

  ref.listen<NostrSessionReadiness>(nostrSessionProvider, (_, next) {
    coordinator.handleReadiness(next);
  });

  // Set up foreground message handler
  final onMessageSubscription = ref.read(firebaseOnMessageProvider).listen((
    message,
  ) {
    final pushService = ref.read(pushNotificationServiceProvider);
    pushService?.handleForegroundMessage(message.data);
  });

  ref.onDispose(() {
    coordinator.dispose();
    unregisterBeforeSessionTeardown();
    authStateSubscription.cancel();
    onMessageSubscription.cancel();
  });
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
        // Wait for the NostrClient to finish initialize() instead of polling
        // hasKeys every 500 ms (#3352). 15 s timeout matches the previous
        // budget (30 retries × 500 ms).
        try {
          await nostrService.ready.timeout(const Duration(seconds: 15));
        } on TimeoutException {
          Log.warning(
            'Notification service initialization skipped - no Nostr keys available after 15s',
            name: 'AppProviders',
            category: LogCategory.system,
          );
          return;
        }

        if (!nostrService.hasKeys) {
          Log.warning(
            'Notification service initialization skipped - ready completed but hasKeys is false',
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
