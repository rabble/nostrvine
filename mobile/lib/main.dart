import 'dart:async';
import 'dart:convert';
import 'dart:io'
    if (dart.library.html) 'package:openvine/utils/platform_io_web.dart'
    as io;

import 'package:app_update_repository/app_update_repository.dart';
import 'package:audio_session/audio_session.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:dm_repository/dm_repository.dart' show DmSyncState;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/bootstrap/font_licenses.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/observability/divine_bloc_observer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/deep_link_provider.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/shorebird_patch_repository.dart';
import 'package:openvine/router/deep_link_coordinator.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/app_engagement_store.dart';
import 'package:openvine/services/back_button_handler.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/build_provenance_service.dart';
import 'package:openvine/services/c2pa_debris_janitor.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/classic_viner_seed_preload_service.dart';
import 'package:openvine/services/corrupted_video_repair_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/firebase_initialization.dart';
import 'package:openvine/services/hive_storage_service.dart';
import 'package:openvine/services/install_source_service.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:openvine/services/memory_pressure_handler.dart';
import 'package:openvine/services/memory_telemetry_service.dart';
import 'package:openvine/services/notification_helpers.dart'
    show localNotificationTapPayload, parseFcmPayload;
import 'package:openvine/services/notification_service.dart'
    show NotificationTapEvent;
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/pro_video_editor_log_forwarder.dart';
import 'package:openvine/services/quick_actions_coordinator.dart';
import 'package:openvine/services/screenshot_mode_service.dart';
import 'package:openvine/services/secure_storage_options.dart';
import 'package:openvine/services/seed_data_preload_service.dart';
import 'package:openvine/services/seed_media_cleanup_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/startup/app_composition_root.dart';
import 'package:openvine/startup/app_side_effects.dart';
import 'package:openvine/startup/database_bootstrap_failure_app.dart';
import 'package:openvine/startup/divine_material_app.dart';
import 'package:openvine/startup/startup_splash_release_controller.dart';
import 'package:openvine/utils/app_uptime.dart';
import 'package:openvine/utils/expected_network_error.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:openvine/utils/recoverable_flutter_error.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:window_manager/window_manager.dart';

/// Whether the background isolate should render a local notification for
/// [message].
///
/// iOS alert pushes (the push service sets `aps.alert` + `content_available`)
/// are presented by the OS *and* wake this handler — building our own local
/// notification on top would double-render (#4731). FlutterFire surfaces the
/// OS-presented alert as [RemoteMessage.notification], so we render only when
/// the OS has not already presented it: a data-only message that carries a
/// body. Today that is Android (the service stays data-only there); the
/// data-only iOS branch is defensive, for a future silent push the OS would
/// not surface.
@visibleForTesting
bool shouldRenderLocalPushNotification(RemoteMessage message) {
  if (message.notification != null) return false;
  final body = message.data['body'];
  return body is String && body.isNotEmpty;
}

typedef BackgroundFirebaseInitializer = Future<void> Function();
typedef ShorebirdTrackUpdate =
    Future<void> Function({
      required ShorebirdUpdater updater,
      required SharedPreferences preferences,
    });
typedef UnexpectedShorebirdErrorReporter =
    Future<void> Function(Object error, StackTrace stackTrace);
typedef BackgroundLocalPushRenderer =
    Future<void> Function({
      required int id,
      required String? title,
      required String body,
      required Map<String, dynamic> data,
    });

/// Top-level background message handler required by Firebase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await handleFirebaseMessagingBackgroundMessage(message);
}

@visibleForTesting
Future<void> handleFirebaseMessagingBackgroundMessage(
  RemoteMessage message, {
  BackgroundFirebaseInitializer initializeFirebase =
      ensureDefaultFirebaseInitialized,
  BackgroundLocalPushRenderer renderLocalPush = _renderBackgroundLocalPush,
}) async {
  try {
    await initializeFirebase();
  } catch (error) {
    Log.warning(
      'Firebase init failed in background push handler; attempting local '
      'notification render: $error',
      name: 'PushNotifications',
    );
  }

  // The OS already presents iOS alert pushes (aps.alert); only render a local
  // notification for data-only messages so we don't double-render (#4731).
  if (!shouldRenderLocalPushNotification(message)) return;

  final data = message.data;
  final title = data['title'] as String? ?? 'Divine';
  final body = data['body'] as String? ?? '';

  await renderLocalPush(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    data: data,
  );
}

Future<void> _renderBackgroundLocalPush({
  required int id,
  required String? title,
  required String body,
  required Map<String, dynamic> data,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings(
    requestBadgePermission: false,
  );
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
    macOS: darwinInit,
  );
  await plugin.initialize(settings: initSettings);

  const androidDetails = AndroidNotificationDetails(
    'openvine_push',
    'Push Notifications',
    channelDescription: 'Notifications from Divine',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(presentBadge: false),
    macOS: DarwinNotificationDetails(presentBadge: false),
  );

  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
    // Carry the normalized tap payload (shared with the foreground path via
    // localNotificationTapPayload) so a tap on this background-built
    // notification routes identically to a system push tap.
    payload: jsonEncode(localNotificationTapPayload(data)),
  );
}

@visibleForTesting
Future<void> configureVideoPlayerCacheForStartup({
  required bool skip,
  required Future<void> Function() configureCache,
}) async {
  if (skip) {
    return;
  }
  await configureCache();
}

@visibleForTesting
Future<void> disposeVideoPlayersForStartup({
  required bool skip,
  required Future<void> Function() disposeAll,
}) async {
  if (skip) {
    return;
  }
  await disposeAll();
}

Future<void> _runTimedStartupTask({
  required String phaseName,
  required String initializationStep,
  required Future<void> Function() task,
}) async {
  StartupPerformanceService.instance.startPhase(phaseName);
  CrashReportingService.instance.logInitializationStep(initializationStep);
  try {
    await task();
  } finally {
    StartupPerformanceService.instance.completePhase(phaseName);
  }
}

/// Resolves a push/local payload to a [NotificationTapTarget], the event id to
/// navigate to, and the authoritative video coordinate, via the shared
/// [resolveNotificationTapTarget] contract.
///
/// `referencedAddress` (the signed NIP-33 coordinate of the referenced video)
/// is the authoritative target: when it is a usable video coordinate
/// ([videoAddressableTarget]) it is returned as `videoCoordinate` and the
/// executor routes to it directly. Otherwise the video target is
/// `referencedEventId` (the event acted upon), falling back to `eventId` (the
/// source event) for follow/mention, which the executor walks to a root video.
///
/// At most one of `videoCoordinate` / `targetEventId` is non-null: a usable
/// coordinate suppresses the event-id walk entirely, encoding the
/// coordinate-over-walk precedence in the returned value rather than leaving
/// it to the executor's branch order.
///
/// Extracted and `@visibleForTesting` so the push-side per-kind routing can be
/// asserted without a navigator — mirrors [resolveVideoDeepLinkNavAction].
@visibleForTesting
({NotificationTapTarget target, String? targetEventId, String? videoCoordinate})
pushNotificationTapTarget({
  required String? referencedAddress,
  required String? referencedEventId,
  required String? eventId,
  required String? notificationType,
  required String? senderPubkey,
}) {
  final videoCoordinate = videoAddressableTarget(referencedAddress);
  final targetEventId = videoCoordinate != null
      ? null
      : (referencedEventId != null && referencedEventId.isNotEmpty)
      ? referencedEventId
      : eventId;
  final hasVideoTarget =
      videoCoordinate != null ||
      (targetEventId != null && targetEventId.isNotEmpty);
  return (
    target: resolveNotificationTapTarget(
      kind: notificationKindFromPushType(notificationType),
      hasVideoTarget: hasVideoTarget,
      actorPubkey: senderPubkey,
    ),
    targetEventId: targetEventId,
    videoCoordinate: videoCoordinate,
  );
}

/// Routes a notification tap (FCM system push, local notification, or
/// cold-start) to a destination using the shared [resolveNotificationTapTarget]
/// contract — the same contract the in-app notification rows use, so the three
/// entry points share one target-selection policy even though each executor
/// keeps its own navigation mechanics.
///
/// [referencedEventId] is the event acted upon (present for like/comment/
/// repost). [eventId] is the source event itself, used as the target for
/// mentions, which carry no `referencedEventId`. [senderPubkey] is the actor —
/// it opens a profile for follows and is the safe fallback when a video target
/// cannot be resolved.
///
/// Failure UX contract (decided in #5079): the profile/inbox fallback applies
/// only to the event-id walk, where resolution happens *before* a route exists
/// and can fail. A valid video coordinate is pushed without a pre-fetch; if
/// the video is then unfetchable (deleted, moderated, offline), the user
/// intentionally lands on [VideoDetailScreen]'s error state — same
/// trust-the-coordinate contract as the in-app rows, which push immediately on
/// an addressable id and surface fetch failure in place. Redirecting a "they
/// interacted with your video" tap to the actor's profile would be
/// misdirection, and a pre-push fetch would reintroduce the relay round-trip
/// this path exists to avoid. Transient failures are already mitigated
/// downstream: the route lookup tries cache → Funnelcake REST → relays, and
/// the screen retries once when relays become ready on cold start.
Future<void> _routeNotificationTap({
  required String? referencedAddress,
  required String? referencedEventId,
  required String? eventId,
  required String? notificationType,
  required String? senderPubkey,
  required ProviderContainer container,
}) async {
  final (:target, :targetEventId, :videoCoordinate) = pushNotificationTapTarget(
    referencedAddress: referencedAddress,
    referencedEventId: referencedEventId,
    eventId: eventId,
    notificationType: notificationType,
    senderPubkey: senderPubkey,
  );

  switch (target) {
    case OpenListTarget(:final pubkey, :final listId):
      container
          .read(goRouterProvider)
          .push(
            CuratedListByAuthorScreen.pathFor(pubkey: pubkey, listId: listId),
          );
    case OpenProfileTarget(:final actorPubkey):
      _navigateToNotificationProfile(container, actorPubkey);
    case OpenInboxTarget():
      _navigateToNotificationInbox(container);
    case OpenVideoTarget(:final autoOpenComments):
      if (videoCoordinate != null) {
        // Authoritative path: the signed NIP-33 coordinate is stable across
        // metadata replacements and resolves without a relay round-trip, so
        // push it straight to the video route.
        _pushVideoDeepLink(
          container,
          videoRef: videoCoordinate,
          autoOpenComments: autoOpenComments,
        );
      } else {
        await _resolveAndPushVideoLink(
          container: container,
          targetEventId: targetEventId!,
          autoOpenComments: autoOpenComments,
          fallbackPubkey: senderPubkey,
        );
      }
  }
}

/// Resolves [targetEventId] to a root video and pushes a video [DeepLink].
///
/// For comment/reply targets [targetEventId] is a Kind 1111 comment event, not
/// a video; [NotificationTargetResolver] walks its NIP-22 `E` / NIP-10 `e`
/// tags to the root video. When resolution fails the tap falls back to the
/// actor's profile (or the inbox if no pubkey is known) instead of silently
/// doing nothing.
Future<void> _resolveAndPushVideoLink({
  required ProviderContainer container,
  required String targetEventId,
  required bool autoOpenComments,
  required String? fallbackPubkey,
}) async {
  String? videoEventId;
  try {
    videoEventId = await NotificationTargetResolver(
      videoEventService: container.read(videoEventServiceProvider),
      nostrService: container.read(nostrServiceProvider),
    ).resolveVideoEventIdFromNotificationTarget(targetEventId);
  } catch (e) {
    Log.error(
      'Failed to resolve notification target: $e',
      name: 'main',
      category: LogCategory.system,
    );
  }

  if (videoEventId == null) {
    Log.warning(
      'Could not resolve notification target to a video '
      '(targetEventId=$targetEventId) — falling back',
      name: 'main',
      category: LogCategory.system,
    );
    if (fallbackPubkey != null && fallbackPubkey.isNotEmpty) {
      _navigateToNotificationProfile(container, fallbackPubkey);
    } else {
      _navigateToNotificationInbox(container);
    }
    return;
  }

  _pushVideoDeepLink(
    container,
    videoRef: videoEventId,
    autoOpenComments: autoOpenComments,
  );
}

/// Pushes a video [DeepLink] for [videoRef] (an event id or a NIP-33
/// `kind:pubkey:d-tag` coordinate) through the shared deep-link stream.
void _pushVideoDeepLink(
  ProviderContainer container, {
  required String videoRef,
  required bool autoOpenComments,
}) {
  container
      .read(deepLinkServiceProvider)
      .pushLink(
        DeepLink(
          type: DeepLinkType.video,
          videoRef: videoRef,
          autoOpenComments: autoOpenComments,
        ),
      );
}

/// Opens the actor's profile. Used for follow taps and as the fallback when a
/// video target cannot be resolved.
void _navigateToNotificationProfile(
  ProviderContainer container,
  String actorPubkeyHex,
) {
  final npub = NostrKeyUtils.encodePubKey(actorPubkeyHex);
  container.read(goRouterProvider).push(OtherProfileScreen.pathForNpub(npub));
}

/// Opens the notifications inbox — the deterministic safe fallback when a tap
/// carries no resolvable target and no actor pubkey.
void _navigateToNotificationInbox(ProviderContainer container) {
  container.read(goRouterProvider).go(NotificationsPage.pathForIndex());
}

class _AppQuickActionsNavigator implements QuickActionsNavigator {
  const _AppQuickActionsNavigator(this.container);

  final ProviderContainer container;

  GoRouter get _router => container.read(goRouterProvider);

  @override
  String get currentPath => _router.routeInformationProvider.value.uri.path;

  @override
  void openCamera() {
    _router.go(
      VideoRecorderScreen.pathForEntryPoint(CreationEntryPoint.quickAction),
    );
  }

  @override
  void openNotifications() {
    _router.go(InboxPage.path);
  }

  @override
  void suppressAuthenticatedAuthRouteRedirect() {
    suppressNextAuthenticatedAuthRouteRedirect();
  }

  @override
  void clearAuthRouteRedirectSuppression() {
    clearAuthenticatedAuthRouteRedirectSuppression();
  }
}

StartupCoordinator _createStartupCoordinator(ProviderContainer container) {
  final coordinator = StartupCoordinator();

  coordinator.registerService(
    name: 'EnvironmentService',
    phase: StartupPhase.critical,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'environment_service',
        initializationStep: 'Initializing environment service',
        task: () async {
          await container
              .read(environmentServiceProvider)
              .initialize(
                sharedPreferences: container.read(sharedPreferencesProvider),
              );
          Log.info(
            '[INIT] EnvironmentService initialized: '
            '${container.read(currentEnvironmentProvider).displayName}',
            name: 'Main',
            category: LogCategory.system,
          );
        },
      );
    },
  );

  coordinator.registerService(
    name: 'CoreServices',
    phase: StartupPhase.essential,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'core_services',
        initializationStep: 'Initializing core services',
        task: () => _initializeCoreServices(container),
      );
    },
  );

  coordinator.registerService(
    name: 'PlaybackAudioSession',
    phase: StartupPhase.essential,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'audio_session',
        initializationStep: 'Configuring playback audio session',
        task: _configurePlaybackAudioSession,
      );
    },
    optional: true,
  );

  coordinator.registerService(
    name: 'HiveStorage',
    phase: StartupPhase.critical,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'hive_storage',
        initializationStep: 'Initializing Hive storage',
        task: _initializeHiveStorage,
      );
    },
  );
  // Critical phase (best-effort): first-frame BLoCs can subscribe to
  // disk-backed caches.
  coordinator.registerService(
    name: 'CacheSync',
    phase: StartupPhase.critical,
    initialize: CacheSync.init,
    optional: true,
  );

  coordinator.registerService(
    name: 'SeenVideosService',
    phase: StartupPhase.standard,
    initialize: () => container.read(seenVideosServiceProvider).initialize(),
    optional: true,
  );

  coordinator.registerService(
    name: 'BandwidthTracker',
    phase: StartupPhase.standard,
    initialize: bandwidthTracker.initialize,
    optional: true,
  );

  coordinator.registerService(
    name: 'VideoFormatPreference',
    phase: StartupPhase.standard,
    initialize: videoFormatPreference.initialize,
    optional: true,
  );

  coordinator.registerService(
    name: 'UploadManager',
    phase: StartupPhase.standard,
    dependencies: const ['HiveStorage'],
    initialize: () => container.read(uploadManagerProvider).initialize(),
    optional: true,
  );

  // Critical phase: traces started before this completes are dropped on the
  // floor — `startOperationTrace` hands back a no-op handle. In `deferred`
  // that silently cost every cold-start
  // measurement, including the `feed_load_homeFeed` and `feed_load_discovery`
  // traces, which mount while the later phases are still working through their
  // queue (#7118). Cost here is a single platform round-trip that runs in
  // parallel with the disk-backed services above, so it does not extend the
  // phase.
  coordinator.registerService(
    name: 'PerformanceMonitoring',
    phase: StartupPhase.critical,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'performance_monitoring',
        initializationStep: 'Initializing performance monitoring',
        task: container.read(performanceMonitoringServiceProvider).initialize,
      );
    },
    optional: true,
  );

  coordinator.registerService(
    name: 'LoggingConfig',
    phase: StartupPhase.deferred,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'logging_config',
        initializationStep: 'Initializing logging configuration',
        task: () async {
          await container.read(loggingConfigServiceProvider).initialize();
          LogMessageBatcher.instance.initialize();
        },
      );
    },
    optional: true,
  );

  // Intentionally essential (not deferred): the manifest must be ready before
  // the first frame so getCachedFileSync() can serve already-cached videos
  // instantly on cold launch without falling through to the slower async path.
  // The I/O cost (aliases.json read + existsSync per entry) is accepted as
  // the price for zero-latency cache hits from frame 1. If this ever regresses
  // cold-start on low-end devices, profile first before moving back to deferred.
  coordinator.registerService(
    name: 'VideoCacheManifest',
    phase: StartupPhase.essential,
    initialize: _initializeVideoCacheManifest,
    optional: true,
  );

  coordinator.registerService(
    name: 'SeedDataPreload',
    phase: StartupPhase.deferred,
    initialize: () => _initializeSeedDataPreload(container),
    optional: true,
  );

  if (!kIsWeb) {
    coordinator.registerService(
      name: 'C2paDebrisSweep',
      phase: StartupPhase.deferred,
      initialize: _sweepC2paDebris,
      optional: true,
    );

    coordinator.registerService(
      name: 'SeedMediaMaintenance',
      phase: StartupPhase.deferred,
      initialize: _initializeSeedMediaMaintenance,
      optional: true,
    );
  }

  coordinator.registerService(
    name: 'ZendeskSupport',
    phase: StartupPhase.deferred,
    initialize: _initializeZendeskSupport,
    optional: true,
  );

  // firebase_messaging only supports Android, iOS, and macOS.
  // firebase_options.dart throws UnsupportedError for Linux/Windows.
  if (isFirebaseSupported && !kIsWeb) {
    coordinator.registerService(
      name: 'PushNotifications',
      phase: StartupPhase.deferred,
      initialize: () async {
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // Check if app was launched from a push notification tap (cold start)
        final initialMessage = await FirebaseMessaging.instance
            .getInitialMessage();
        if (initialMessage != null) {
          final parsed = parseFcmPayload(initialMessage.data);
          if (parsed != null) {
            Log.info(
              'App launched from push notification (type: '
              '${parsed.notificationType})',
              name: 'main',
              category: LogCategory.system,
            );
            unawaited(
              _routeNotificationTap(
                referencedAddress: parsed.referencedAddress,
                referencedEventId: parsed.referencedEventId,
                eventId: parsed.eventId,
                notificationType: parsed.notificationType,
                senderPubkey: parsed.senderPubkey,
                container: container,
              ),
            );
          }
        }

        // Local-notification cold-start: Android pushes are data-only and
        // rendered by flutter_local_notifications, so a tap that launches the
        // app from a terminated state arrives here — not via getInitialMessage,
        // which only covers OS-rendered pushes (iOS).
        final launchTap = await container
            .read(notificationServiceProvider)
            .takeLaunchNotificationTap();
        if (launchTap != null) {
          Log.info(
            'App launched from local notification (type: '
            '${launchTap.notificationType})',
            name: 'main',
            category: LogCategory.system,
          );
          unawaited(
            _routeNotificationTap(
              referencedAddress: launchTap.referencedAddress,
              referencedEventId: launchTap.referencedEventId,
              eventId: launchTap.eventId,
              notificationType: launchTap.notificationType,
              senderPubkey: launchTap.senderPubkey,
              container: container,
            ),
          );
        }

        // Handle taps on notifications while app is in background
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final parsed = parseFcmPayload(message.data);
          if (parsed != null) {
            Log.info(
              'Push notification tapped (background) (type: '
              '${parsed.notificationType})',
              name: 'main',
              category: LogCategory.system,
            );
            unawaited(
              _routeNotificationTap(
                referencedAddress: parsed.referencedAddress,
                referencedEventId: parsed.referencedEventId,
                eventId: parsed.eventId,
                notificationType: parsed.notificationType,
                senderPubkey: parsed.senderPubkey,
                container: container,
              ),
            );
          }
        });
      },
      optional: true,
    );
  }

  return coordinator;
}

@visibleForTesting
StartupCoordinator createStartupCoordinatorForTesting(
  ProviderContainer container,
) {
  return _createStartupCoordinator(container);
}

/// Starts the Dart updater before startup can render either the normal app or
/// the database-bootstrap failure app.
///
/// The work begins here rather than on the first frame, so a Dart-side startup
/// failure anywhere between this call and `runApp` still gets its patch — which
/// is the launch a patch most often exists to repair. The cost is the updater's
/// synchronous FFI availability probe: upstream defers it because a concurrent
/// caller can block on the Rust config lock, and the only such caller is
/// Shorebird's native auto-update thread, which `shorebird.yaml` disables.
///
/// A crash before this line, or a native crash before Dart runs, is still
/// uncovered; nothing in Dart can reach those.
@visibleForTesting
void startShorebirdStartupUpdate({
  required SharedPreferences preferences,
  ShorebirdUpdater Function() updaterFactory = ShorebirdUpdater.new,
  ShorebirdTrackUpdate updateSubscribedTrack =
      updateShorebirdFromSubscribedTrack,
}) {
  final updater = updaterFactory();
  unawaited(updateSubscribedTrack(updater: updater, preferences: preferences));
}

Future<void> _startOpenVineApp() async {
  // Add timing logs for startup diagnostics
  final startTime = DateTime.now();
  AppUptime.markStarted();

  // Ensure bindings are initialized first (required for everything)
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Fail the launch on a malformed C2PA signing endpoint rather than letting it
  // surface mid-capture as an opaque "Signature: internal error", which reads
  // as a server outage and sends users to debug their own connection.
  C2paSigningService.assertSigningEndpointValid();

  // Register bundled OFL font licenses so they surface on the in-app
  // Open Source Licenses page (Settings → Legal). See #3659.
  registerBundledFontLicenses();

  // Give the in-memory image cache a larger byte budget than Flutter's 100 MB
  // default so thumbnails survive fast scrolling instead of being evicted and
  // reloaded. Per-thumbnail memory is bounded by decoding at display size.
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      AppConstants.imageCacheMaxBytes;

  // Keep the native splash visible until startup auth reaches a terminal
  // state. The release watcher is installed after the ProviderContainer exists
  // so the UI/native concern stays in app startup instead of AuthService.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Lock app to portrait mode only (portrait up and portrait down)
  // Skip on desktop platforms where orientation lock doesn't apply
  if (!kIsWeb &&
      defaultTargetPlatform != TargetPlatform.macOS &&
      defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux) {
    // CRITICAL: Lock to portraitUp ONLY for proper camera orientation
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  // Initialize startup performance monitoring FIRST
  await StartupPerformanceService.instance.initialize();
  StartupPerformanceService.instance.startPhase('bindings');

  // NOTE: Native video players (AVPlayer on iOS/macOS, ExoPlayer on Android)
  // do not require explicit player-wide initialization.
  // They initialize automatically when a DivineVideoPlayerController is
  // first created.

  // Configure the native video player disk cache (500 MB, LRU eviction).
  // Skip on web/Linux/Windows — divine_video_player has no native plugin
  // on those targets and `configureCache` is a bare method-channel call.
  await configureVideoPlayerCacheForStartup(
    skip: !hasNativeVideoPlayer,
    configureCache: DivineVideoPlayerController.configureCache,
  );

  // Dispose any zombie native players from a previous Dart VM
  // (e.g. hot restart). Must happen after configureCache so the
  // global method channel is already registered.
  await disposeVideoPlayersForStartup(
    skip: !hasNativeVideoPlayer,
    disposeAll: DivineVideoPlayerController.disposeAll,
  );

  StartupPerformanceService.instance.completePhase('bindings');

  // Initialize crash reporting ASAP so we can use it for logging
  StartupPerformanceService.instance.startPhase('crash_reporting');
  await CrashReportingService.instance.initialize();
  StartupPerformanceService.instance.completePhase('crash_reporting');

  // Now we can start logging
  Log.info(
    '[STARTUP] App initialization started at $startTime',
    name: 'Main',
    category: LogCategory.system,
  );
  CrashReportingService.instance.logInitializationStep('Bindings initialized');
  StartupPerformanceService.instance.checkpoint('crash_reporting_ready');

  // DEFER window manager initialization until after UI is ready to avoid blocking
  if (defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    // Defer window manager setup to not block main thread during critical startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        StartupPerformanceService.instance.startPhase('window_manager');
        CrashReportingService.instance.logInitializationStep(
          'Initializing window manager',
        );
        await windowManager.ensureInitialized();

        // Set initial window size for desktop vine experience
        const initialWindowOptions = WindowOptions(
          size: Size(750, 950), // Wider, better proportioned for desktop
          minimumSize: Size(
            WindowSizeConstants.baseWidth,
            WindowSizeConstants.baseHeight,
          ),
          center: true,
          backgroundColor: VineTheme.backgroundColor,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
        );

        await windowManager.waitUntilReadyToShow(
          initialWindowOptions,
          () async {
            await windowManager.show();
            await windowManager.focus();
          },
        );

        StartupPerformanceService.instance.completePhase('window_manager');
      } catch (e) {
        // If window_manager fails, continue without it - app will still work
        Log.error('Window manager initialization failed: $e', name: 'main');
        StartupPerformanceService.instance.completePhase('window_manager');
      }
    });
  }

  // Set default log level based on build mode if not already configured
  if (const String.fromEnvironment('LOG_LEVEL').isEmpty) {
    if (kDebugMode) {
      // Debug builds: enable debug logging for development visibility
      // RELAY category temporarily enabled for web debugging
      UnifiedLogger.setLogLevel(LogLevel.debug);
      UnifiedLogger.enableCategories({
        LogCategory.system,
        LogCategory.auth,
        LogCategory.video,
        LogCategory.relay,
        LogCategory.ui,
      });
    } else {
      // Release builds: minimal logging to reduce performance impact
      UnifiedLogger.setLogLevel(LogLevel.warning);
      UnifiedLogger.enableCategories({LogCategory.system, LogCategory.auth});
    }
  }

  // Forward pro_video_editor native diagnostics (renderer, thumbnail, audio)
  // into the unified log so video-editor/render problems land in bug reports
  // (#4801). Gated per call by the nativeLogLevel passed to each operation.
  ProVideoEditorLogForwarder.start();

  // Store original debugPrint to avoid recursion
  final originalDebugPrint = debugPrint;

  // Override debugPrint to respect logging levels and batch repetitive messages
  debugPrint = (message, {wrapWidth}) {
    if (message != null && UnifiedLogger.isLevelEnabled(LogLevel.debug)) {
      // Try to batch repetitive EXTERNAL-EVENT messages from native code
      if (message.contains('[EXTERNAL-EVENT]') &&
          message.contains('already exists in database or was rejected')) {
        // Use our batcher for these specific messages
        LogMessageBatcher.instance.tryBatchMessage(
          message,
          category: LogCategory.relay,
        );
        return; // Don't print the individual message
      } else if (message.contains('[EXTERNAL-EVENT]') &&
          message.contains('matches subscription')) {
        LogMessageBatcher.instance.tryBatchMessage(
          message,
          level: LogLevel.debug,
          category: LogCategory.relay,
        );
        return; // Don't print the individual message
      } else if (message.contains('[EXTERNAL-EVENT]') &&
          message.contains('Received event') &&
          message.contains('from')) {
        LogMessageBatcher.instance.tryBatchMessage(
          message,
          level: LogLevel.debug,
          category: LogCategory.relay,
        );
        return; // Don't print the individual message
      }

      originalDebugPrint(message, wrapWidth: wrapWidth);
    }
  };

  // Configure global error widget builder for user-friendly error display
  // Wrap in Directionality to enable Text widgets even before MaterialApp is ready
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // On web, log error details for debugging
    if (kIsWeb) {
      Log.error(
        'ErrorWidget: ${details.exception}\n${details.stack}',
        name: 'ErrorWidget',
        category: LogCategory.system,
      );
    }
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: VineTheme.backgroundColor,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DivineIcon(
                  icon: DivineIconName.warningCircle,
                  color: VineTheme.accentOrange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Oops, something went wrong',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '${details.exception}',
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  };

  // Handle Flutter framework errors more gracefully
  final previousOnError = FlutterError.onError; // Preserve Crashlytics handler
  FlutterError.onError = (details) {
    // Log all errors for debugging
    Log.error(
      'Flutter Error: ${details.exception}',
      name: 'Main',
      category: LogCategory.system,
    );

    // Downgrade cache manager errors from FATAL to non-fatal.
    // The flutter_cache_manager library reports corrupted JSON via
    // FlutterError.reportError, which Crashlytics records as fatal. The app
    // can function fine without cached thumbnails — it will re-download them.
    // SafeJsonCacheInfoRepository handles recovery, but this is a safety net.
    if (details.library == 'flutter cache manager') {
      Log.warning(
        'Cache manager error (non-fatal): ${details.exception}',
        name: 'Main',
      );
      unawaited(
        CrashReportingService.instance.recordError(
          details.exception,
          details.stack,
          reason: 'Cache manager JSON corruption',
        ),
      );
      return;
    }

    // Downgrade "No active player with ID" errors from FATAL to non-fatal.
    // This is a known race condition where the native video player
    // (AVFoundation/ExoPlayer) is disposed during tab switches or feed
    // scrolling, but the Flutter VideoPlayer widget still tries to rebuild
    // with the stale player ID. The primary defense is _SafeVideoPlayer
    // in video_feed_item.dart, but this catch handles any cases that slip
    // through (e.g. timing gaps).
    final errorStr = details.exception.toString();
    if (errorStr.contains('No active player with ID') ||
        (errorStr.contains('Bad state') && errorStr.contains('player'))) {
      Log.warning(
        'Video player disposed race condition (non-fatal): '
        '${details.exception}',
        name: 'Main',
      );
      // Record as non-fatal in Crashlytics (if available) instead of
      // letting it propagate as a fatal crash.
      unawaited(
        CrashReportingService.instance.recordError(
          details.exception,
          details.stack,
          reason: 'Video player disposed race condition',
        ),
      );
      // Still show the error widget (dark placeholder) but don't report
      // as fatal.
      FlutterError.presentError(details);
      return;
    }

    final recoverable = classifyRecoverableFlutterError(details);
    if (recoverable != null) {
      Log.warning(
        '${recoverable.reason} (non-fatal): ${details.exception}',
        name: 'Main',
      );
      if (recoverable.report) {
        unawaited(
          CrashReportingService.instance.recordError(
            details.exception,
            details.stack,
            reason: recoverable.reason,
          ),
        );
      }
      FlutterError.presentError(details);
      return;
    }

    // For other errors, forward to any existing handler (e.g., Crashlytics),
    // then use default presentation which will now use our ErrorWidget.builder
    try {
      if (previousOnError != null) {
        previousOnError(details);
      }
    } catch (_) {
      // No-op: a foreign FlutterError handler (e.g. Crashlytics') threw while
      // we forwarded to it. Rethrowing here would re-enter FlutterError.onError,
      // so swallow and fall through to presentError below.
    }
    FlutterError.presentError(details);
  };

  // Initialize SharedPreferences for feature flags
  StartupPerformanceService.instance.startPhase('shared_preferences');
  final sharedPreferences = await SharedPreferences.getInstance();
  StartupPerformanceService.instance.completePhase('shared_preferences');

  // Load package info for version checking (non-blocking, fast).
  final packageInfo = await PackageInfo.fromPlatform();

  // This must precede database bootstrap. That bootstrap can render its own
  // failure app and return early; the failure app still needs the updater so a
  // broken patch can receive a rollback or replacement.
  ShorebirdUpdater? startupShorebirdUpdater;
  startShorebirdStartupUpdate(
    preferences: sharedPreferences,
    updaterFactory: () => startupShorebirdUpdater ??= ShorebirdUpdater(),
  );

  // Resolve the at-rest database cipher key before the container so the
  // database provider opens an encrypted SQLite3MultipleCiphers connection on
  // first use. This also verifies package:sqlite3 loaded the sqlite3mc hook
  // build and runs the one-time plaintext→encrypted migration, both of which
  // must happen before any Drift database open. (#570, finding C2)
  final dbCipherSecureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    mOptions: appMacOsSecureStorageOptions(),
  );
  var didRecordDatabaseBootstrapFailure = false;
  Future<void> recordDatabaseBootstrapFailure(
    Object error,
    StackTrace stack,
  ) async {
    if (didRecordDatabaseBootstrapFailure) return;
    didRecordDatabaseBootstrapFailure = true;
    await CrashReportingService.instance.recordError(
      error,
      stack,
      reason: 'DatabaseEncryptionBootstrap.resolveCipherKey failed',
    );
  }

  // Sink for the runtime corruption the startup probe cannot see: it persists
  // the flag this bootstrap reads below, and drives the in-session restart
  // prompt (DatabaseCorruptionGate). Created before the bootstrap so both
  // halves — detection and recovery — share one instance. (#570)
  final databaseCorruptionService = DatabaseCorruptionService(
    preferences: sharedPreferences,
    recordError: (error, stack) => CrashReportingService.instance.recordError(
      error,
      stack,
      reason: 'Runtime database corruption',
    ),
  );

  // Resets preserve a backup by default because encrypted backups stay readable
  // under the retained cipher key. The db-unreadable diagnosis is different:
  // it proves the current file is plaintext-shaped corruption, so preserving it
  // would leave plaintext at rest after the reset.
  Future<void> resetLocalDatabaseCache({required bool deleteCipherKey}) =>
      resetEncryptedDatabaseCache(
        secureStorage: dbCipherSecureStorage,
        deleteCipherKey: deleteCipherKey,
        // On the recreate the Drift DB is wiped but SharedPreferences survives;
        // clear the DM sync state so the next inbox open runs a full re-drain
        // instead of skipping it as "already complete" (which had left
        // recovered chats stranded under "Message requests"). See #5304.
        onDatabaseReset: () => DmSyncState(sharedPreferences).clearAll(),
      );

  // The fail-closed screen below renders before the app's own MaterialApp
  // exists, so it cannot inherit a locale — pass the user's language override
  // through. Null falls back to the device locales, same as the running app.
  final savedUiLocale = LocalePreferenceService(
    sharedPreferences: sharedPreferences,
  ).getLocale();

  final dbCipherKeyResult = await resolveDatabaseBootstrapForAppStart(
    locale: savedUiLocale == null ? null : Locale(savedUiLocale),
    resolveCipherKey: () => resolveStartupDatabaseCipherKey(
      // resetOnError MUST stay false here: the cipher key is the one secret
      // whose loss makes the encrypted DB unrecoverable. A transient keystore
      // read error must throw rather than silently deleting the key and
      // triggering the §6 key-loss recovery. (#570 C2)
      resolveCipherKey: () => DatabaseEncryptionBootstrap(
        secureStorage: dbCipherSecureStorage,
        // On the key-loss recreate the Drift DB is wiped but SharedPreferences
        // survives; clear the DM sync state so the next inbox open runs a full
        // re-drain instead of skipping it as "already complete" (which had
        // left recovered chats stranded under "Message requests"). See #5304.
        onDatabaseReset: () => DmSyncState(sharedPreferences).clearAll(),
        // Recovery succeeds silently (returns a key, never throws), so record
        // it as a non-fatal to surface the corruption rate and any
        // recover-every-launch loop in Crashlytics.
        recordRecovery: (error, stack) => CrashReportingService.instance
            .recordError(error, stack, reason: 'DB startup recovery'),
        // A previous session's runtime corruption report forces the salvage.
        // The probe below is reactive and already missed this corruption once,
        // so re-running it would just clear the DB for another broken session.
        hasPendingCorruptionRecovery: () async =>
            databaseCorruptionService.hasPendingRecovery,
        clearPendingCorruptionRecovery:
            databaseCorruptionService.clearPendingRecovery,
      ).resolveCipherKey(),
      // SQLite3MultipleCiphers build misconfiguration or secure-storage
      // failures must fail closed after reporting. Continuing with a null key
      // would open an existing encrypted DB as plaintext and spam SQLITE_NOTADB.
      recordError: recordDatabaseBootstrapFailure,
    ),
    repairLocalDatabaseCache: (error, stack) =>
        resetLocalDatabaseCache(deleteCipherKey: true),
    shouldRepairLocalDatabaseCache:
        shouldRepairLocalDatabaseCacheAfterBootstrapError,
    // Manual escape hatch behind a confirmation, offered only for diagnoses
    // where the database is unusable. It clears the DB but not the signing key,
    // so it costs local-only drafts and clips while an uninstall — the
    // alternative a stuck user is left with — takes the whole Android keystore
    // and the account with it.
    //
    // The cipher key stays: the diagnoses that reach this button cannot prove
    // it is stale, and encrypted reset backups remain readable under it. For
    // db-unreadable, the damaged file is plaintext-shaped, so the reset deletes
    // it instead of preserving a plaintext backup.
    resetLocalDatabase: (diagnosis) async {
      try {
        if (diagnosis == DatabaseBootstrapDiagnosis.databaseUnreadable) {
          await resetUnreadablePlaintextDatabaseCache(
            secureStorage: dbCipherSecureStorage,
            onDatabaseReset: () => DmSyncState(sharedPreferences).clearAll(),
          );
        } else {
          await resetLocalDatabaseCache(deleteCipherKey: false);
        }
      } catch (error, stack) {
        // The screen keeps the user on it and says the reset failed; without
        // this the only report of a failed recovery would be that sentence.
        await CrashReportingService.instance.recordError(
          error,
          stack,
          reason: 'Manual local database reset from the bootstrap failure app',
        );
        rethrow;
      }
    },
    runApp: runApp,
    removeNativeSplash: FlutterNativeSplash.remove,
  );
  if (dbCipherKeyResult.didRenderFailureApp) return;
  final dbCipherKey = dbCipherKeyResult.cipherKey;

  // Build the device-scoped dependencies ONCE, before any container. The
  // database in particular holds the single open SQLite connection that must
  // survive account switches — every container (initial and swapped-in) shares
  // it via DeviceScope so a switch never opens a second connection.
  final deviceDatabase = createAppDatabase(
    cipherKey: dbCipherKey,
    // Same instance the bootstrap above consulted, so the interceptor the
    // database installs writes the flag the next launch reads.
    corruptionService: databaseCorruptionService,
  );
  final accountSwitchController = AccountSwitchController();

  // Resolve how this install was distributed (Play Store / App Store /
  // TestFlight / Zapstore / sideload) via the native method channel, and
  // record this cold start for the install-scoped engagement counter that the
  // in-app review gate reads. Both are best-effort and fall back to safe
  // defaults on web/desktop/unsupported native shells (#6296).
  final installSource = await const InstallSourceService().resolve();

  // Resolved once here so synchronous readers can rebase persisted absolute
  // paths without awaiting: iOS rewrites the container path on every app
  // update, and the plugin lookup behind it is a Future.
  final documentsPath = await getDocumentsPath();
  await AppEngagementStore(
    sharedPreferences: sharedPreferences,
  ).recordSession();

  final deviceScope = DeviceScope(
    database: deviceDatabase,
    sharedPreferences: sharedPreferences,
    switchController: accountSwitchController,
    appVersion: packageInfo.version,
    documentsPath: documentsPath,
    dbCipherKey: dbCipherKey,
    databaseCorruptionService: databaseCorruptionService,
    installSource: installSource,
    accountOverrides: [
      // Screenshot mode: lead the 01_classics OG-Viner row with returning
      // Vine OGs who all have avatars, so the marketing shot has no
      // placeholder circles (the live row mixes in avatar-less creators).
      if (ScreenshotMode.enabled)
        topClassicVinersProvider.overrideWith(
          (ref) async => screenshotOgVinersFixtures(),
        ),
      if (ScreenshotMode.enabled)
        discoveredListsProvider.overrideWith(ScreenshotDiscoveredLists.new),
    ],
  );

  // Create the initial account container to initialize services BEFORE runApp.
  final container = buildAccountContainer(deviceScope);

  final startupCoordinator = _createStartupCoordinator(container);
  // The native splash is released by [StartupSplashReleaseController], wired in
  // _DivineAppState.initState once the router exists, so that an authenticated
  // user's `/welcome` → `/home` redirect is applied before the splash lifts
  // (#5242). It cannot run here because the GoRouter is built in runApp.
  await startupCoordinator.initializeThrough(StartupPhase.critical);

  Log.info('Divine starting...', name: 'Main');
  Log.info('Log level: ${UnifiedLogger.currentLevel.name}', name: 'Main');
  final initDuration = DateTime.now().difference(startTime).inMilliseconds;
  CrashReportingService.instance.log(
    '[STARTUP] Blocking setup took ${initDuration}ms',
  );
  CrashReportingService.instance.logInitializationStep(
    'Blocking startup complete',
  );
  StartupPerformanceService.instance.checkpoint('pre_app_launch');

  await initializeDateFormatting();

  // Forward Bloc/Cubit errors (addError, uncaught handler throws, emit
  // failures) to Crashlytics + UnifiedLogger. Surfaced during the #3503
  // investigation as a missing observability hook. See #3526.
  Bloc.observer = DivineBlocObserver(
    // Once the database has reported corruption, the service above has already
    // recorded the incident and scheduled the next-launch salvage, so the
    // Drift failures every downstream bloc then hits are echoes of a handled
    // event rather than five separate defects. See #7507.
    isDatabaseCorrupted: () => databaseCorruptionService.isCorrupted.value,
  );

  // Tag every crash report with the running build so per-error triage doesn't
  // have to cross-reference the release dashboard. Set once, not per-error.
  // See #3758.
  final buildTag = '${packageInfo.version}+${packageInfo.buildNumber}';
  unawaited(CrashReportingService.instance.setCustomKey('build_tag', buildTag));

  // Provenance is diagnostic, so it waits for the first frame. Reuse the
  // updater constructed by the earlier recovery-critical callback when that
  // callback has already run.
  final environment = container.read(currentEnvironmentProvider).environment;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final shorebirdUpdater = startupShorebirdUpdater ??= ShorebirdUpdater();
    unawaited(
      _recordBuildProvenance(
        packageInfo: packageInfo,
        installSource: installSource,
        environment: environment,
        shorebirdUpdater: shorebirdUpdater,
      ),
    );
  });

  runApp(
    ContainerSwapHost(
      initialContainer: container,
      controller: accountSwitchController,
      child: DivineApp(
        startupCoordinator: startupCoordinator,
        packageInfo: packageInfo,
      ),
    ),
  );
}

Future<void> _recordBuildProvenance({
  required PackageInfo packageInfo,
  required InstallSource installSource,
  required AppEnvironment environment,
  required ShorebirdUpdater shorebirdUpdater,
}) async {
  try {
    final provenance = await BuildProvenanceService(
      packageInfo: packageInfo,
      installSource: installSource,
      environment: environment,
      platform: _startupPlatformName(),
      shorebirdAvailable: shorebirdUpdater.isAvailable,
      buildMode: BuildMode.current,
      readPatchNumber: () async =>
          (await shorebirdUpdater.readCurrentPatch())?.number,
    ).resolve();
    Log.info(provenance.summary, name: 'Main', category: LogCategory.system);
    CrashReportingService.instance.log(provenance.summary);
    unawaited(
      CrashReportingService.instance.setCustomKey(
        'environment',
        provenance.environment.name,
      ),
    );
    unawaited(
      CrashReportingService.instance.setCustomKey(
        'build_mode',
        provenance.buildMode.name,
      ),
    );
    unawaited(
      CrashReportingService.instance.setCustomKey(
        'install_source',
        provenance.installSource.name,
      ),
    );
    unawaited(
      CrashReportingService.instance.setCustomKey(
        'shorebird_available',
        provenance.shorebirdAvailable,
      ),
    );
    unawaited(
      CrashReportingService.instance.setCustomKey(
        'shorebird_patch',
        provenance.patchLabel,
      ),
    );
  } catch (error, stack) {
    Log.warning(
      'Build provenance logging failed: $error',
      name: 'Main',
      category: LogCategory.system,
    );
    unawaited(
      CrashReportingService.instance.recordError(
        error,
        stack,
        reason: 'Build provenance logging failed',
      ),
    );
  }
}

@visibleForTesting
Future<void> updateShorebirdFromSubscribedTrack({
  required ShorebirdUpdater updater,
  required SharedPreferences preferences,
  UnexpectedShorebirdErrorReporter reportUnexpectedError =
      _reportUnexpectedShorebirdStartupError,
}) async {
  try {
    await ShorebirdPatchRepository(
      updater: updater,
      preferences: preferences,
    ).updateSubscribedTrackAtStartup();
  } on UpdateException catch (error) {
    // Download/install failures are expected network or IO outcomes. Keep them
    // in diagnostic logs without flooding Crashlytics on every cold start.
    Log.warning(
      'Automatic Shorebird update did not install: $error',
      name: 'Main',
      category: LogCategory.system,
    );
  } catch (error, stackTrace) {
    Log.error(
      'Automatic Shorebird update failed',
      name: 'Main',
      category: LogCategory.system,
      error: error,
      stackTrace: stackTrace,
    );
    await reportUnexpectedError(error, stackTrace);
  }
}

Future<void> _reportUnexpectedShorebirdStartupError(
  Object error,
  StackTrace stackTrace,
) => CrashReportingService.instance.recordError(
  error,
  stackTrace,
  reason: 'Automatic Shorebird update failed',
);

String _startupPlatformName() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

/// Initialize core identity services after the first frame.
Future<void> _initializeCoreServices(ProviderContainer container) async {
  Log.info(
    '[INIT] Starting service initialization...',
    name: 'Main',
    category: LogCategory.system,
  );

  // Migrate any pre-secure-storage identity key into SecureKeyStorage before
  // the auth layer reads it. Runs on the shared storage instance so
  // AuthService's subsequent read is a warm cache hit.
  await migrateLegacyNostrKeys(container.read(secureKeyStorageProvider));
  Log.info(
    '[INIT] ✅ Legacy key migration checked',
    name: 'Main',
    category: LogCategory.system,
  );

  // Initialize auth service
  // NOTE: NostrService (relay connections) is initialized lazily in AuthService
  // when user actually authenticates, to avoid blocking startup for unauthenticated users
  await container.read(authServiceProvider).initialize();
  Log.info(
    '[INIT] ✅ AuthService initialized',
    name: 'Main',
    category: LogCategory.system,
  );

  await restorePendingEmailVerificationOnStartup(container);

  if (ScreenshotMode.enabled) {
    await buildScreenshotModeService(container).prepare();
    // The native side wrote the capture route + seed flag into
    // SharedPreferences at launch (AppDelegate). Load them, seed editor
    // clips if requested, then drive the router imperatively —
    // initialLocation resolves before this runs, so it can't be used.
    ScreenshotMode.loadLaunchConfig(container.read(sharedPreferencesProvider));
    if (ScreenshotMode.seedClips) {
      await seedScreenshotEditorClips(container);
    }
    final screenshotRoute = ScreenshotMode.initialRoute;
    if (screenshotRoute != null) {
      container.read(goRouterProvider).go(screenshotRoute);
    }
    Log.info(
      '[INIT] ✅ Screenshot mode prepared',
      name: 'Main',
      category: LogCategory.system,
    );
  }

  Log.info(
    '[INIT] ✅ Core services initialized',
    name: 'Main',
    category: LogCategory.system,
  );
}

/// Restore the email-verification screen on a plain cold reopen (no deep link).
///
/// Registration persists the deviceCode/verifier/email (24h TTL) but nothing
/// consults it on a normal startup, so a user who killed the app to read the
/// 6-digit PIN from their email would otherwise land on Welcome. When the user
/// has an unexpired pending record belonging to the current startup identity,
/// route them back to the polling-mode verification screen (PIN field visible)
/// so they can finish. Verification deep links (token mode) are handled by
/// [EmailVerificationListener]; this only fires from the Welcome landing and
/// never overrides a screen a deep link already opened.
Future<void> restorePendingEmailVerificationOnStartup(
  ProviderContainer container,
) async {
  final authService = container.read(authServiceProvider);
  final pending = await container
      .read(pendingVerificationServiceProvider)
      .load();
  final router = container.read(goRouterProvider);
  final currentPath = router.routeInformationProvider.value.uri.path;
  final target = pendingEmailVerificationStartupLocation(
    pending: pending,
    authState: authService.authState,
    isAnonymous: authService.isAnonymous,
    currentPublicKeyHex: authService.currentPublicKeyHex,
    currentPath: currentPath,
  );
  if (target == null) return;

  Log.info(
    'Restoring pending email verification on cold start',
    name: 'Main',
    category: LogCategory.auth,
  );
  router.go(target);
}

Future<void> _configurePlaybackAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(
    const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.moviePlayback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        usage: AndroidAudioUsage.media,
      ),
    ),
  );
}

Future<void> _initializeHiveStorage() => HiveStorageService.initialize();

Future<void> _initializeVideoCacheManifest() async {
  if (kIsWeb) return;

  await _runTimedStartupTask(
    phaseName: 'video_cache',
    initializationStep: 'Initializing video cache manifest',
    task: () async {
      try {
        await initializeMediaCache();
        // Trim the image cache back under its byte budget too (unawaited so
        // it never blocks startup). The video cache is handled inside
        // initializeMediaCache().
        unawaited(openVineImageCache.enforceCacheLimits());
      } catch (e) {
        Log.error(
          '[STARTUP] Video cache initialization failed: $e',
          name: 'Main',
          category: LogCategory.system,
        );
      }
    },
  );
}

Future<void> _sweepC2paDebris() async {
  final directories = await Future.wait([
    getApplicationDocumentsDirectory(),
    getTemporaryDirectory(),
  ]);
  directories.forEach(C2paDebrisJanitor.deleteStaleDebris);
}

Future<void> _initializeSeedDataPreload(ProviderContainer container) async {
  await _runTimedStartupTask(
    phaseName: 'seed_data_preload',
    initializationStep: 'Loading bundled seed data',
    task: () async {
      try {
        final db = container.read(databaseProvider);
        await SeedDataPreloadService.loadSeedDataIfNeeded(db);
      } catch (e, stack) {
        Log.error(
          '[SEED] Data preload failed (non-critical): $e',
          name: 'Main',
          category: LogCategory.system,
        );
        Log.verbose(
          '[SEED] Stack: $stack',
          name: 'Main',
          category: LogCategory.system,
        );
      }
    },
  );
}

Future<void> _initializeSeedMediaMaintenance() async {
  await _runTimedStartupTask(
    phaseName: 'seed_media_maintenance',
    initializationStep: 'Cleaning up seed media',
    task: () async {
      try {
        await SeedMediaCleanupService().cleanUpStrandedSeedMediaIfNeeded();
        await ClassicVinerSeedPreloadService().preloadAvatarImagesIfNeeded(
          cacheWriter:
              ({
                required String cacheKey,
                required Uint8List bytes,
                required String fileExtension,
              }) async {
                await openVineImageCache.putFile(
                  cacheKey,
                  bytes,
                  fileExtension: fileExtension,
                );
              },
        );
      } catch (e, stack) {
        Log.error(
          '[SEED] Media maintenance failed (non-critical): $e',
          name: 'Main',
          category: LogCategory.system,
        );
        Log.verbose(
          '[SEED] Stack: $stack',
          name: 'Main',
          category: LogCategory.system,
        );
      }
    },
  );
}

Future<void> _initializeZendeskSupport() async {
  await _runTimedStartupTask(
    phaseName: 'zendesk',
    initializationStep: 'Initializing Zendesk Support SDK',
    task: () async {
      try {
        final zendeskInitialized = await ZendeskSupportService.initialize(
          appId: ZendeskConfig.appId,
          clientId: ZendeskConfig.clientId,
          zendeskUrl: ZendeskConfig.zendeskUrl,
        );
        if (zendeskInitialized) {
          Log.info(
            '[STARTUP] Zendesk Support SDK initialized successfully',
            name: 'Main',
            category: LogCategory.system,
          );
          CrashReportingService.instance.logInitializationStep(
            '✓ Zendesk initialized',
          );
        } else {
          Log.info(
            '[STARTUP] Zendesk Support SDK not initialized (credentials not configured)',
            name: 'Main',
            category: LogCategory.system,
          );
          CrashReportingService.instance.logInitializationStep(
            '○ Zendesk skipped (no credentials)',
          );
        }
      } catch (e) {
        Log.warning(
          '[STARTUP] Zendesk initialization failed: $e',
          name: 'Main',
          category: LogCategory.system,
        );
        CrashReportingService.instance.logInitializationStep(
          '✗ Zendesk failed: $e',
        );
      }
    },
  );
}

/// Sink [handleUncaughtZoneError] files a report to.
typedef ZoneErrorRecorder =
    Future<void> Function(Object error, StackTrace stack, {String? reason});

/// Files a report for an error that escaped every `try`/`catch` in the app
/// zone.
///
/// Expected network/IO failures are dropped instead of reported, for the
/// reason spelled out on [isExpectedNetworkFailure]: a relay handshake that
/// fails because the device has no DNS is a state, not a defect, and the
/// relay's own reconnect path already handles it. Left ungated it dominated
/// the iOS non-fatal dashboard (#7290).
///
/// [recordError] defaults to the app-wide crash reporter; it is injectable so
/// tests can observe what does and does not get filed.
@visibleForTesting
Future<void> handleUncaughtZoneError(
  Object error,
  StackTrace stack, {
  ZoneErrorRecorder? recordError,
}) async {
  if (isExpectedNetworkFailure(error)) {
    Log.warning(
      'Expected network failure (not reported): $error',
      name: 'Main',
    );
    return;
  }

  // CrashReportingService.recordError self-guards (no-ops if uninitialized)
  // and logs its own failure internally, so no outer catch is needed here.
  final record = recordError ?? CrashReportingService.instance.recordError;
  await record(error, stack, reason: 'runZonedGuarded');
}

void main() {
  // Capture any uncaught Dart errors (foreground or background zones)
  runZonedGuarded(() async {
    await _startOpenVineApp();
  }, handleUncaughtZoneError);
}

class DivineApp extends ConsumerStatefulWidget {
  const DivineApp({
    required this.startupCoordinator,
    required this.packageInfo,
    super.key,
  });

  final StartupCoordinator startupCoordinator;
  final PackageInfo packageInfo;

  @override
  ConsumerState<DivineApp> createState() => _DivineAppState();
}

/// Whether a launch that observes [state] as its first lifecycle reading must
/// start with media downloads suspended.
///
/// #6222 tears in-flight downloads down on the `paused` transition, because on
/// Apple platforms a live NSURLSession callback trampolining into a suspended
/// isolate aborts the process in the `cupertino_http` FFI layer. A process
/// launched straight into the background — silent push, background upload
/// completion — never gets that transition, because it was never resumed. Its
/// downloads therefore ran until iOS suspended it mid-request, which is the
/// remaining crash. Reading the state we start in covers what a transition
/// cannot.
///
/// `null` means the engine has not reported a state yet, which is the normal
/// case on a foreground launch. Suspending there would risk latching downloads
/// off with no `resumed` transition arriving to lift them again, so it is
/// treated as "not background".
@visibleForTesting
bool shouldSuspendDownloadsAtLaunch(AppLifecycleState? state) =>
    state != null && state != AppLifecycleState.resumed;

class _DivineAppState extends ConsumerState<DivineApp>
    with WidgetsBindingObserver {
  bool _backgroundInitDone = false;
  StreamSubscription<void>? _shakeSubscription;
  StreamSubscription<NotificationTapEvent>? _notificationTapSubscription;
  ProviderSubscription<AsyncValue<AccountDeletionAttempt?>>?
  _deletionAttemptSubscription;
  bool _authenticatedDeletionLookupSettled = false;
  QuickActionsCoordinator? _quickActionsCoordinator;
  late final StartupSplashReleaseController _splashReleaseController;
  late final MemoryPressureHandler _memoryPressureHandler;
  late final MemoryTelemetryService _memoryTelemetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Transitions alone do not cover a process launched straight into the
    // background, so latch the suspension from the state we start in.
    if (shouldSuspendDownloadsAtLaunch(
      WidgetsBinding.instance.lifecycleState,
    )) {
      openVineMediaCache.cancelInFlightDownloads();
      openVineImageCache.cancelInFlightDownloads();
    }
    _memoryPressureHandler = MemoryPressureHandler(
      clearImageCache: () {
        PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
      },
      shedIngestion: () {
        ref.read(videoEventServiceProvider).eventRouter?.shedLowPriority();
      },
    );
    _memoryTelemetry = MemoryTelemetryService(
      readRssBytes: () => kIsWeb ? 0 : io.ProcessInfo.currentRss,
      nativeControllerCount: () =>
          DivineVideoPlayerController.liveControllerCount,
      queueDepth: () =>
          ref.read(videoEventServiceProvider).eventRouter?.queuedLength ?? 0,
      emit: _emitMemorySnapshot,
    );
    // Subscribe before deferred startup settles auth; routerDelegate reliably
    // notifies after redirect configuration changes (#5242).
    final router = ref.read(goRouterProvider);
    final authService = ref.read(authServiceProvider);
    final initialDeletionAttempt = ref.read(
      currentAccountDeletionAttemptProvider,
    );
    _authenticatedDeletionLookupSettled = authenticatedDeletionLookupSettled(
      authService.authState,
      initialDeletionAttempt,
    );
    _splashReleaseController = StartupSplashReleaseController(
      authStateStream: authService.authStateStream,
      currentAuthState: () => authService.authState,
      locationListenable: router.routerDelegate,
      currentLocation: () =>
          router.routerDelegate.currentConfiguration.uri.toString(),
      authenticatedRedirectPending: (location) =>
          authenticatedRedirectsFromAuthEntry(
            location,
            hasExpiredOAuthSession: authService.hasExpiredOAuthSession,
            isAnonymous: authService.isAnonymous,
          ) ||
          !_authenticatedDeletionLookupSettled,
    );
    _deletionAttemptSubscription = ref.listenManual(
      currentAccountDeletionAttemptProvider,
      (_, next) {
        _authenticatedDeletionLookupSettled =
            authenticatedDeletionLookupSettled(authService.authState, next);
        _splashReleaseController.reevaluate();
      },
    );
    // Start deferred startup after the first frame so the shell can paint first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_backgroundInitDone) {
        _backgroundInitDone = true;
        _initializeDeferredStartup();
        _initializeDeepLinkServices();
        _initializeQuickActions();
        _initializeBackgroundServices();
        _memoryTelemetry.start();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _memoryTelemetry.stop();
    _splashReleaseController.dispose();
    _deletionAttemptSubscription?.close();
    _notificationTapSubscription?.cancel();
    unawaited(_quickActionsCoordinator?.dispose());
    _shakeSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didHaveMemoryPressure() {
    _memoryPressureHandler.onMemoryPressure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Tear down in-flight media downloads before the OS suspends the app.
    // On Apple platforms cupertino_http delivers NSURLSession callbacks
    // through a Dart FFI trampoline that aborts if the isolate is suspended
    // mid-request. Cancellation also latches a suspension so prefetch loops
    // cannot re-arm fresh native requests in the same window; the latch is
    // lifted on resume, when downloads work again.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      openVineMediaCache.cancelInFlightDownloads();
      openVineImageCache.cancelInFlightDownloads();
    } else if (state == AppLifecycleState.resumed) {
      openVineMediaCache.resumeDownloads();
      openVineImageCache.resumeDownloads();
    }
  }

  /// Logs a memory snapshot at info and annotates Crashlytics custom keys so
  /// OOM crash reports carry the last-seen memory footprint and gauges.
  void _emitMemorySnapshot(MemorySnapshot snapshot) {
    const bytesPerMb = 1024 * 1024;
    final rssMb = (snapshot.rssBytes / bytesPerMb).toStringAsFixed(1);
    final peakMb = (snapshot.peakRssBytes / bytesPerMb).toStringAsFixed(1);
    Log.info(
      'Memory: rss $rssMb MB (peak $peakMb MB), '
      'vc_native=${snapshot.nativeControllers}, '
      'ingest_queue_depth=${snapshot.queueDepth}',
      name: 'MemoryTelemetry',
      category: LogCategory.system,
    );
    final crashReporting = CrashReportingService.instance;
    unawaited(crashReporting.setCustomKey('mem_rss_mb', rssMb));
    unawaited(crashReporting.setCustomKey('mem_peak_mb', peakMb));
    unawaited(
      crashReporting.setCustomKey('vc_native', snapshot.nativeControllers),
    );
    unawaited(
      crashReporting.setCustomKey('ingest_queue_depth', snapshot.queueDepth),
    );
  }

  void _initializeDeepLinkServices() {
    Log.info(
      '🔗 Initializing deep link services...',
      name: 'DeepLinkHandler',
      category: LogCategory.ui,
    );

    // Initialize the deep link service for video content
    final deepLinkService = ref.read(deepLinkServiceProvider);
    deepLinkService.initialize();

    // Route local notification taps (background-built via flutter_local_notifications)
    // through the same deep-link stream so the build() listener handles navigation.
    final container = ProviderScope.containerOf(context);
    _notificationTapSubscription?.cancel();
    _notificationTapSubscription = ref
        .read(notificationServiceProvider)
        .notificationTapStream
        .listen((tapEvent) {
          Log.info(
            '🔔 Local notification tap (type: ${tapEvent.notificationType})',
            name: 'DeepLinkHandler',
            category: LogCategory.ui,
          );
          unawaited(
            _routeNotificationTap(
              referencedAddress: tapEvent.referencedAddress,
              referencedEventId: tapEvent.referencedEventId,
              eventId: tapEvent.eventId,
              notificationType: tapEvent.notificationType,
              senderPubkey: tapEvent.senderPubkey,
              container: container,
            ),
          );
        });

    // Initialize the deep link service for password reset
    ref.read(passwordResetListenerProvider).initialize();

    // Initialize the deep link service for email verification
    ref.read(emailVerificationListenerProvider).initialize();

    Log.info(
      '✅ Deep Link services initialized',
      name: 'DeepLinkHandler',
      category: LogCategory.ui,
    );
  }

  bool get _quickActionsPlatformSupported =>
      !kIsWeb && (io.Platform.isAndroid || io.Platform.isIOS);

  void _initializeQuickActions() {
    if (!_quickActionsPlatformSupported) return;

    final container = ProviderScope.containerOf(context);
    final authService = ref.read(authServiceProvider);
    _quickActionsCoordinator = QuickActionsCoordinator(
      client: DivineQuickActionsClient(),
      authStateStream: authService.authStateStream,
      readAuthState: () => authService.authState,
      readTitles: () {
        final l10n = currentAppL10n(ref.read(sharedPreferencesProvider));
        return QuickActionTitles(
          camera: l10n.videoRecorderStartRecordingTooltip,
          notifications: l10n.navNotifications,
        );
      },
      navigator: _AppQuickActionsNavigator(container),
      reportError: (error, stackTrace, reason) {
        return CrashReportingService.instance.recordError(
          error,
          stackTrace,
          reason: reason,
        );
      },
      waitForAuthRedirectToSettle: () async {
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        return mounted;
      },
      scheduleRedirectSuppressionClear: (callback) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callback());
      },
      isAndroid: !kIsWeb && io.Platform.isAndroid,
    )..start();
  }

  void _initializeDeferredStartup() {
    unawaited(
      widget.startupCoordinator.initializeRemaining().catchError((
        Object error,
        StackTrace stackTrace,
      ) async {
        Log.error(
          '[INIT] Deferred startup failed: $error',
          name: 'Main',
          category: LogCategory.system,
        );
        await CrashReportingService.instance.recordError(
          error,
          stackTrace,
          reason: 'Deferred startup initialization failed',
        );
      }),
    );
  }

  /// Initialize opportunistic foreground-idle warmups owned by the app shell.
  void _initializeBackgroundServices() {
    ref.read(foregroundIdleWarmupSchedulerProvider).start();

    // Block/mute list sync is handled by blocklistSyncBridgeProvider
    // (watched in AppShell) which reacts to auth state changes and
    // covers both already-authenticated startup and post-login scenarios.

    // One-time repair for corrupted video events with local file paths (#2144).
    // It needs a signed-in identity and a connected client, so it is deferred
    // until the Nostr session reaches nostrReady — NOT run in the pre-restore
    // startup window where currentIdentity is still null. There it would no-op
    // and (before the CorruptedVideoRepairService flag fix) permanently mark
    // itself complete, silently disabling the migration. Reading
    // nostrServiceProvider only after restore is safe because NostrService's
    // in-flight-target guard (#5909) keeps a build-after-restore ordering from
    // spuriously rebuilding the client.
    _runCorruptedVideoRepairWhenReady();
  }

  void _runCorruptedVideoRepairWhenReady() {
    var started = false;
    bool runIfReady(NostrSessionReadiness session) {
      if (started || session.phase != NostrSessionPhase.nostrReady) {
        return false;
      }
      started = true;
      unawaited(_runCorruptedVideoRepair());
      return true;
    }

    if (runIfReady(ref.read(nostrSessionProvider))) return;
    late final ProviderSubscription<NostrSessionReadiness> subscription;
    subscription = ref.listenManual(nostrSessionProvider, (_, next) {
      if (runIfReady(next)) subscription.close();
    });
  }

  Future<void> _runCorruptedVideoRepair() async {
    try {
      final repairService = CorruptedVideoRepairService(
        nostrClient: ref.read(nostrServiceProvider),
        authService: ref.read(authServiceProvider),
        prefs: ref.read(sharedPreferencesProvider),
        blossomBaseUrl: ref.read(currentEnvironmentProvider).blossomUrl,
        videoEventService: ref.read(videoEventServiceProvider),
      );
      await repairService.repairIfNeeded();
    } catch (e) {
      Log.warning(
        '[INIT] Corrupted video repair failed (non-critical): $e',
        name: 'Main',
        category: LogCategory.system,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set up deep link listener (must be in build method per Riverpod rules)
    // Deep links that arrive while the app is running. GoRouter's redirect
    // resolves the same URL independently; both paths are idempotent and both
    // are required — see DeepLinkCoordinator.
    ref.listen<AsyncValue<DeepLink>>(deepLinksProvider, (previous, next) {
      DeepLinkCoordinator(
        router: ref.read(goRouterProvider),
        authService: ref.read(authServiceProvider),
      ).handle(next);
    });

    const bool crashProbe = bool.fromEnvironment('CRASHLYTICS_PROBE');

    final router = ref.read(goRouterProvider);

    // Initialize back button handler (Android only - uses platform channel)
    if (!kIsWeb && io.Platform.isAndroid) {
      BackButtonHandler.initialize(router, ref);
    }

    Widget wrapped = AppCompositionRoot(
      packageInfo: widget.packageInfo,
      child: const DivineMaterialApp(),
    );

    if (crashProbe) {
      // Invisible crash probe: tap top-left corner 7 times within 5s to crash
      wrapped = Stack(
        children: [
          wrapped,
          Positioned(
            left: 0,
            top: 0,
            width: 44,
            height: 44,
            child: _CrashProbeHotspot(),
          ),
        ],
      );
    }

    // Root-tier app-wide side effects are activated here, above
    // MaterialApp.router, so they run whether or not the bottom-nav shell is
    // mounted. See AppRootSideEffects for the membership rule.
    return AppRootSideEffects(
      child: wrapped, // ProviderScope now wraps DivineApp from outside
    );
  }
}

class _CrashProbeHotspot extends StatefulWidget {
  @override
  State<_CrashProbeHotspot> createState() => _CrashProbeHotspotState();
}

class _CrashProbeHotspotState extends State<_CrashProbeHotspot> {
  int _taps = 0;
  DateTime? _windowStart;

  Future<void> _onTap() async {
    final now = DateTime.now();
    if (_windowStart == null ||
        now.difference(_windowStart!) > const Duration(seconds: 5)) {
      _windowStart = now;
      _taps = 0;
    }
    _taps++;
    if (_taps >= 7) {
      // Record a breadcrumb, then crash the app (TestFlight validation)
      CrashReportingService.instance.log('CrashProbe: triggering test crash');
      // Force a native crash to ensure reporting in TF
      FirebaseCrashlytics.instance.crash();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: _onTap,
    child: const SizedBox.expand(),
  );
}

/// Window size constants for desktop experience
class WindowSizeConstants {
  WindowSizeConstants._();

  // Base dimensions for desktop vine experience (1x scale)
  static const double baseWidth = 450;
  static const double baseHeight = 700;
}
