import 'dart:async';
import 'dart:convert';
import 'dart:io'
    if (dart.library.html) 'package:openvine/utils/platform_io_web.dart'
    as io;

import 'package:app_update_repository/app_update_repository.dart';
import 'package:app_version_client/app_version_client.dart';
import 'package:audio_session/audio_session.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/config/zendesk_config.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/l10n/email_verification_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';
import 'package:openvine/network/vine_cdn_http_overrides.dart'
    if (dart.library.html) 'package:openvine/utils/platform_io_web.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/services/notification_realtime_bridge.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/observability/divine_bloc_observer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/deep_link_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/back_button_handler.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/corrupted_video_repair_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/nip98_auth_service.dart' show HttpMethod;
import 'package:openvine/services/notification_helpers.dart'
    show parseFcmPayload;
import 'package:openvine/services/notification_service.dart'
    show NotificationPayloadKind, NotificationTapEvent;
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/seed_data_preload_service.dart';
import 'package:openvine/services/seed_media_preload_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:openvine/utils/recoverable_flutter_error.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:openvine/widgets/geo_blocking_gate.dart';
import 'package:openvine/widgets/upload_failure_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:window_manager/window_manager.dart';

/// Top-level background message handler required by Firebase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final title = data['title'] as String? ?? 'diVine';
  final body = data['body'] as String? ?? '';

  if (body.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
    macOS: darwinInit,
  );
  await plugin.initialize(initSettings);

  const androidDetails = AndroidNotificationDetails(
    'openvine_push',
    'Push Notifications',
    channelDescription: 'Notifications from diVine',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
    payload: jsonEncode({
      'referencedEventId': data['referencedEventId'],
      // Normalise at the boundary: FCM wire key is 'type'; the internal
      // payload (read by NotificationService) uses 'notificationType'.
      'notificationType': data['type'],
    }),
  );
}

@visibleForTesting
bool handleKnownFrameworkError(
  FlutterErrorDetails details, {
  required void Function(String message) logWarning,
  VoidCallback? clearKeyboardState,
}) {
  final exception = details.exception.toString();
  if (exception.contains('KeyDownEvent') ||
      exception.contains('HardwareKeyboard')) {
    logWarning(
      'Known Flutter framework keyboard issue (recovering): '
      '${details.exception}',
    );
    clearKeyboardState?.call();
    return true;
  }
  return false;
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

/// Describes the router action to take when navigating to a video deep link.
@visibleForTesting
enum VideoDeepLinkNavAction {
  /// Navigate to the route, keeping the current route in the back stack.
  push,

  /// Replace the current route in-place (already on a video route).
  go,

  /// Re-trigger the current route with [autoOpenComments] set to `true`.
  ///
  /// Used when the user is already on the target video but a reply
  /// notification tap needs the comments sheet to open.
  goSameRouteWithComments,

  /// The router is already on the target route with nothing new to do.
  skip,
}

/// Determines which router action to take for a video deep-link navigation
/// given the current router location and the incoming [DeepLink].
///
/// Extracted for testability — the caller executes the action; this function
/// only decides what action that should be.
@visibleForTesting
VideoDeepLinkNavAction resolveVideoDeepLinkNavAction({
  required String currentLocation,
  required String targetPath,
  required bool autoOpenComments,
}) {
  if (currentLocation == targetPath) {
    // Already on the exact target route.
    if (autoOpenComments) {
      // Reply notification tap while the video is already visible — retrigger
      // the route with autoOpenComments so the comments sheet opens.
      return VideoDeepLinkNavAction.goSameRouteWithComments;
    }
    // Duplicate navigation with nothing new to do (e.g. getInitialLink +
    // uriLinkStream both fire for the same URL). Safe to skip.
    return VideoDeepLinkNavAction.skip;
  }
  if (currentLocation.startsWith('${VideoDetailScreen.basePath}/')) {
    // A different video is already showing — replace it in-place.
    return VideoDeepLinkNavAction.go;
  }
  // Coming from a non-video route — push so back returns home.
  return VideoDeepLinkNavAction.push;
}

/// Resolves [referencedEventId] from a push notification payload to a video
/// event ID, then pushes a [DeepLink] into [deepLinkService].
///
/// For `notificationType == "reply"` (and other comment-type notifications),
/// [referencedEventId] is the ID of a Kind 1111 comment event, not a video.
/// [NotificationTargetResolver] fetches that event from the relay, walks its
/// NIP-22 `E` / NIP-10 `e` tags, and returns the root video event ID.
///
/// For video-type events the resolver returns the same ID unchanged.
Future<void> _resolveAndPushNotificationDeepLink({
  required String referencedEventId,
  required String? notificationType,
  required ProviderContainer container,
}) async {
  final deepLinkService = container.read(deepLinkServiceProvider);
  final autoOpenComments = notificationType == NotificationPayloadKind.reply;

  String? videoEventId;
  try {
    videoEventId = await NotificationTargetResolver(
      videoEventService: container.read(videoEventServiceProvider),
      nostrService: container.read(nostrServiceProvider),
    ).resolveVideoEventIdFromNotificationTarget(referencedEventId);
  } catch (e) {
    Log.error(
      'Failed to resolve notification target: $e',
      name: 'main',
      category: LogCategory.system,
    );
  }

  if (videoEventId == null) {
    Log.warning(
      'Could not resolve notification target to a video, '
      'referencedEventId=$referencedEventId type=$notificationType',
      name: 'main',
      category: LogCategory.system,
    );
    return;
  }

  Log.info(
    'Resolved notification target: $referencedEventId → $videoEventId '
    '(type=$notificationType, autoOpenComments=$autoOpenComments)',
    name: 'main',
    category: LogCategory.system,
  );

  deepLinkService.pushLink(
    DeepLink(
      type: DeepLinkType.video,
      videoRef: videoEventId,
      autoOpenComments: autoOpenComments,
    ),
  );
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

  if (!kIsWeb) {
    coordinator.registerService(
      name: 'MediaPlayback',
      phase: StartupPhase.essential,
      initialize: () async {
        await _runTimedStartupTask(
          phaseName: 'media_playback',
          initializationStep: 'Initializing media playback pool',
          task: _initializeMediaPlayback,
        );
      },
      optional: true,
    );
  }

  coordinator.registerService(
    name: 'HiveStorage',
    phase: StartupPhase.standard,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'hive_storage',
        initializationStep: 'Initializing Hive storage',
        task: _initializeHiveStorage,
      );
    },
  );

  coordinator.registerService(
    name: 'CacheSync',
    phase: StartupPhase.standard,
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

  coordinator.registerService(
    name: 'PerformanceMonitoring',
    phase: StartupPhase.deferred,
    initialize: () async {
      await _runTimedStartupTask(
        phaseName: 'performance_monitoring',
        initializationStep: 'Initializing performance monitoring',
        task: PerformanceMonitoringService.instance.initialize,
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
          await LoggingConfigService.instance.initialize();
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
      name: 'SeedMediaPreload',
      phase: StartupPhase.deferred,
      initialize: _initializeSeedMediaPreload,
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
              'App launched from push notification, '
              'target: ${parsed.referencedEventId} '
              '(type: ${parsed.notificationType})',
              name: 'main',
              category: LogCategory.system,
            );
            unawaited(
              _resolveAndPushNotificationDeepLink(
                referencedEventId: parsed.referencedEventId,
                notificationType: parsed.notificationType,
                container: container,
              ),
            );
          }
        }

        // Handle taps on notifications while app is in background
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final parsed = parseFcmPayload(message.data);
          if (parsed != null) {
            Log.info(
              'Push notification tapped (background), '
              'target: ${parsed.referencedEventId} '
              '(type: ${parsed.notificationType})',
              name: 'main',
              category: LogCategory.system,
            );
            unawaited(
              _resolveAndPushNotificationDeepLink(
                referencedEventId: parsed.referencedEventId,
                notificationType: parsed.notificationType,
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

Future<void> _startOpenVineApp() async {
  // Add timing logs for startup diagnostics
  final startTime = DateTime.now();

  // Ensure bindings are initialized first (required for everything)
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Keep the native splash visible until auth resolves. AuthService calls
  // FlutterNativeSplash.remove() in its initialize() finally block once a
  // terminal auth state is reached. The Future.delayed is a safety net for
  // catastrophic hangs — 5s is chosen to cover slow bunker/relay reconnects.
  // See #2749 and #2953 for the investigation.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  Future.delayed(const Duration(seconds: 5), FlutterNativeSplash.remove);

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
  // do not require explicit initialization like media_kit did.
  // They initialize automatically when VideoPlayerController is first created.
  //
  // NOTE: video_player_web_hls auto-registers for HLS support on web.
  // Just needs <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  // in web/index.html (already added).

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

  // Enable DNS override for legacy Vine CDN domains if configured (not supported on web)
  if (!kIsWeb) {
    const bool enableVineCdnFix = bool.fromEnvironment(
      'VINE_CDN_DNS_FIX',
      defaultValue: true,
    );
    const String cdnIp = String.fromEnvironment(
      'VINE_CDN_IP',
      defaultValue: '151.101.244.157',
    );
    if (enableVineCdnFix) {
      final ip = io.InternetAddress.tryParse(cdnIp);
      if (ip != null) {
        io.HttpOverrides.global = VineCdnHttpOverrides(overrideAddress: ip);
        Log.info('Enabled Vine CDN DNS override to $cdnIp', name: 'Networking');
      } else {
        Log.warning(
          'Invalid VINE_CDN_IP "$cdnIp". DNS override not applied.',
          name: 'Networking',
        );
      }
    }
  }

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
                const Icon(
                  Icons.error_outline_rounded,
                  color: VineTheme.accentOrange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Oops, something went wrong',
                  style: TextStyle(
                    color: VineTheme.whiteText,
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

    // Recover from Flutter's known duplicate key state assertion so desktop
    // text input continues working after logout/resume flows.
    if (handleKnownFrameworkError(
      details,
      logWarning: (message) => Log.warning(message, name: 'Main'),
      clearKeyboardState: () {
        // Flutter does not currently expose a stable public recovery API for
        // this duplicate-key assertion path. Keep this workaround tightly
        // scoped to the known framework failure above.
        // ignore: invalid_use_of_visible_for_testing_member
        HardwareKeyboard.instance.clearState();
      },
    )) {
      return;
    }

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
      try {
        FirebaseCrashlytics.instance.recordError(
          details.exception,
          details.stack,
          reason: 'Cache manager JSON corruption',
        );
      } catch (_) {}
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
      try {
        FirebaseCrashlytics.instance.recordError(
          details.exception,
          details.stack,
          reason: 'Video player disposed race condition',
        );
      } catch (_) {}
      // Still show the error widget (dark placeholder) but don't report
      // as fatal.
      FlutterError.presentError(details);
      return;
    }

    final recoverableReason = classifyRecoverableFlutterError(details);
    if (recoverableReason != null) {
      Log.warning(
        'Recoverable Flutter resource load error (non-fatal): '
        '${details.exception}',
        name: 'Main',
      );
      try {
        FirebaseCrashlytics.instance.recordError(
          details.exception,
          details.stack,
          reason: recoverableReason,
        );
      } catch (_) {}
      FlutterError.presentError(details);
      return;
    }

    // For other errors, forward to any existing handler (e.g., Crashlytics),
    // then use default presentation which will now use our ErrorWidget.builder
    try {
      if (previousOnError != null) {
        previousOnError(details);
      }
    } catch (_) {}
    FlutterError.presentError(details);
  };

  // Initialize SharedPreferences for feature flags
  StartupPerformanceService.instance.startPhase('shared_preferences');
  final sharedPreferences = await SharedPreferences.getInstance();
  StartupPerformanceService.instance.completePhase('shared_preferences');

  // Load package info for version checking (non-blocking, fast).
  final packageInfo = await PackageInfo.fromPlatform();

  // Create ProviderContainer to initialize services BEFORE runApp
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPreferences)],
  );

  final startupCoordinator = _createStartupCoordinator(container);
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
  Bloc.observer = DivineBlocObserver();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: DivineApp(
        startupCoordinator: startupCoordinator,
        packageInfo: packageInfo,
      ),
    ),
  );
}

/// Initialize core identity services after the first frame.
Future<void> _initializeCoreServices(ProviderContainer container) async {
  Log.info(
    '[INIT] Starting service initialization...',
    name: 'Main',
    category: LogCategory.system,
  );

  // Initialize key manager first (needed for NIP-17 bug reports and auth)
  await container.read(nostrKeyManagerProvider).initialize();
  Log.info(
    '[INIT] ✅ NostrKeyManager initialized',
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

  // Re-initialize NostrKeyManager after AuthService, because AuthService may
  // have imported/restored keys into PlatformSecureStorage during its own
  // initialization (e.g. nsec import, key generation, session restore).
  // NostrKeyManager ran first and found no keys; re-running picks them up.
  final keyManager = container.read(nostrKeyManagerProvider);
  if (!keyManager.hasKeys) {
    await keyManager.initialize();
    Log.info(
      '[INIT] NostrKeyManager re-initialized after auth — '
      'hasKeys=${keyManager.hasKeys}',
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

Future<void> _initializeMediaPlayback() async {
  MediaKit.ensureInitialized();
  await PlayerPool.init();
}

Future<void> _initializeHiveStorage() => Hive.initFlutter();

Future<void> _initializeVideoCacheManifest() async {
  if (kIsWeb) return;

  await _runTimedStartupTask(
    phaseName: 'video_cache',
    initializationStep: 'Initializing video cache manifest',
    task: () async {
      try {
        await initializeMediaCache();
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

Future<void> _initializeSeedMediaPreload() async {
  await _runTimedStartupTask(
    phaseName: 'seed_media_preload',
    initializationStep: 'Loading bundled seed media',
    task: () async {
      try {
        await SeedMediaPreloadService.loadSeedMediaIfNeeded();
      } catch (e, stack) {
        Log.error(
          '[SEED] Media preload failed (non-critical): $e',
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

void main() {
  // Capture any uncaught Dart errors (foreground or background zones)
  runZonedGuarded(
    () async {
      await _startOpenVineApp();
    },
    (error, stack) async {
      // Best-effort logging; if Crashlytics isn't ready, still print
      try {
        await CrashReportingService.instance.recordError(
          error,
          stack,
          reason: 'runZonedGuarded',
        );
      } catch (_) {}
    },
  );
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

class _DivineAppState extends ConsumerState<DivineApp> {
  bool _backgroundInitDone = false;
  StreamSubscription<void>? _shakeSubscription;
  StreamSubscription<NotificationTapEvent>? _notificationTapSubscription;

  @override
  void initState() {
    super.initState();
    // Start deferred startup after the first frame so the shell can paint first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_backgroundInitDone) {
        _backgroundInitDone = true;
        _initializeDeferredStartup();
        _initializeDeepLinkServices();
        _initializeBackgroundServices();
      }
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    _shakeSubscription?.cancel();
    super.dispose();
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
            '🔔 Local notification tap: eventId=${tapEvent.referencedEventId} '
            'type=${tapEvent.notificationType}',
            name: 'DeepLinkHandler',
            category: LogCategory.ui,
          );
          unawaited(
            _resolveAndPushNotificationDeepLink(
              referencedEventId: tapEvent.referencedEventId,
              notificationType: tapEvent.notificationType,
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

  /// Initialize opportunistic background warmups owned by the app shell.
  void _initializeBackgroundServices() {
    Future.microtask(() {
      unawaited(
        ref
            .read(popularNowFeedProvider.future)
            .then((state) {
              Log.info(
                '[INIT] Warmed New feed with ${state.videos.length} videos',
                name: 'Main',
                category: LogCategory.system,
              );
            })
            .catchError((Object error, StackTrace stackTrace) {
              Log.warning(
                '[INIT] New feed warmup failed (non-critical): $error',
                name: 'Main',
                category: LogCategory.system,
              );
            }),
      );
    });

    // Block/mute list sync is handled by blocklistSyncBridgeProvider
    // (watched in AppShell) which reacts to auth state changes and
    // covers both already-authenticated startup and post-login scenarios.

    // One-time repair for corrupted video events with local file paths (#2144)
    unawaited(
      Future.microtask(() async {
        try {
          final nostrClient = ref.read(nostrServiceProvider);
          final authService = ref.read(authServiceProvider);
          final env = ref.read(currentEnvironmentProvider);
          final prefs = ref.read(sharedPreferencesProvider);
          final videoEventService = ref.read(videoEventServiceProvider);
          final repairService = CorruptedVideoRepairService(
            nostrClient: nostrClient,
            authService: authService,
            prefs: prefs,
            blossomBaseUrl: env.blossomUrl,
            videoEventService: videoEventService,
          );
          await repairService.repairIfNeeded();
        } catch (e) {
          Log.warning(
            '[INIT] Corrupted video repair failed (non-critical): $e',
            name: 'Main',
            category: LogCategory.system,
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Activate route normalization at app root
    ref.watch(routeNormalizationProvider);

    // Set up deep link listener (must be in build method per Riverpod rules)
    ref.listen<AsyncValue<DeepLink>>(deepLinksProvider, (previous, next) {
      Log.info(
        '🔗 Deep link event received - AsyncValue state: ${next.runtimeType}',
        name: 'DeepLinkHandler',
        category: LogCategory.ui,
      );

      next.when(
        data: (deepLink) {
          Log.info(
            '🔗 Processing deep link: $deepLink',
            name: 'DeepLinkHandler',
            category: LogCategory.ui,
          );

          final router = ref.read(goRouterProvider);
          final currentLocation = router.routeInformationProvider.value.uri
              .toString();
          Log.info(
            '🔗 Current router location: $currentLocation',
            name: 'DeepLinkHandler',
            category: LogCategory.ui,
          );

          switch (deepLink.type) {
            case DeepLinkType.video:
              if (deepLink.videoRef != null) {
                final targetPath = VideoDetailScreen.pathForId(
                  deepLink.videoRef!,
                );
                Log.info(
                  '📱 Navigating to video: $targetPath'
                  '${deepLink.autoOpenComments ? " (open comments)" : ""}',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
                try {
                  final routeExtra = deepLink.autoOpenComments
                      ? const VideoDetailRouteExtra(autoOpenComments: true)
                      : null;
                  final action = resolveVideoDeepLinkNavAction(
                    currentLocation: currentLocation,
                    targetPath: targetPath,
                    autoOpenComments: deepLink.autoOpenComments,
                  );
                  switch (action) {
                    case VideoDeepLinkNavAction.skip:
                      break;
                    case VideoDeepLinkNavAction.goSameRouteWithComments:
                      // Already on the video — retrigger so the comments
                      // sheet opens in response to a reply notification tap.
                      router.go(targetPath, extra: routeExtra);
                    case VideoDeepLinkNavAction.go:
                      // When another shared video is opened while a shared
                      // video route is already visible, replace the current
                      // detail route instead of stacking it.
                      router.go(targetPath, extra: routeExtra);
                    case VideoDeepLinkNavAction.push:
                      // Keep the home route underneath the first shared video
                      // so back navigation returns to the main screen.
                      router.push(targetPath, extra: routeExtra);
                  }
                  Log.info(
                    '✅ Navigation completed to: $targetPath',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                } catch (e) {
                  Log.error(
                    '❌ Navigation failed: $e',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                }
              } else {
                Log.warning(
                  '⚠️ Video deep link missing videoRef',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            case DeepLinkType.profile:
              if (deepLink.npub != null) {
                // Mirror universalLinkToRouterPath: no index → grid mode
                // (/profile/<npub>), explicit index → feed mode
                // (/profile/<npub>/<index>). The old `index ?? 0` form always
                // produced a feed-mode path, which disagreed with the
                // resolver's grid-mode redirect for index-less universal links
                // and caused a spurious second navigation.
                final index = deepLink.index;
                final targetPath = index != null
                    ? ProfileScreenRouter.pathForIndex(deepLink.npub!, index)
                    : ProfileScreenRouter.pathForNpub(deepLink.npub!);
                Log.info(
                  '📱 Navigating to profile: $targetPath',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
                try {
                  // GoRouter's universal-link redirect may have already
                  // navigated here; skip the duplicate go() to avoid a
                  // second navigation frame on the same target.
                  if (currentLocation == targetPath) break;
                  router.go(targetPath);
                  Log.info(
                    '✅ Navigation completed to: $targetPath',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                } catch (e) {
                  Log.error(
                    '❌ Navigation failed: $e',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                }
              } else {
                Log.warning(
                  '⚠️ Profile deep link missing npub',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            case DeepLinkType.hashtag:
              if (deepLink.hashtag != null) {
                final targetPath = HashtagScreenRouter.pathForTag(
                  deepLink.hashtag!,
                );
                Log.info(
                  '📱 Navigating to hashtag: $targetPath',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
                try {
                  // GoRouter's universal-link redirect may have already
                  // navigated here; skip the duplicate go() to avoid a
                  // second navigation frame on the same target.
                  if (currentLocation == targetPath) break;
                  router.go(targetPath);
                  Log.info(
                    '✅ Navigation completed to: $targetPath',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                } catch (e) {
                  Log.error(
                    '❌ Navigation failed: $e',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                }
              } else {
                Log.warning(
                  '⚠️ Hashtag deep link missing hashtag',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            case DeepLinkType.search:
              if (deepLink.searchTerm != null) {
                final targetPath = SearchResultsPage.pathForQuery(
                  deepLink.searchTerm!,
                  requestFocusOnMount: false,
                );
                Log.info(
                  '📱 Navigating to search: $targetPath',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
                try {
                  // GoRouter's universal-link redirect may have already
                  // navigated here; skip the duplicate go() to avoid a
                  // second navigation frame on the same target.
                  if (currentLocation == targetPath) break;
                  router.go(targetPath);
                  Log.info(
                    '✅ Navigation completed to: $targetPath',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                } catch (e) {
                  Log.error(
                    '❌ Navigation failed: $e',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                }
              } else {
                Log.warning(
                  '⚠️ Search deep link missing search term',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            case DeepLinkType.invite:
              if (deepLink.inviteCode != null) {
                final targetPath = WelcomeScreen.inviteGatePathWithCode(
                  deepLink.inviteCode!,
                );
                Log.info(
                  '📱 Navigating to invite gate: ${redactUriStringForLogs(targetPath)}',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
                try {
                  router.go(targetPath);
                } catch (e) {
                  Log.error(
                    '❌ Invite navigation failed: $e',
                    name: 'DeepLinkHandler',
                    category: LogCategory.ui,
                  );
                }
              } else {
                Log.warning(
                  '⚠️ Invite deep link missing code',
                  name: 'DeepLinkHandler',
                  category: LogCategory.ui,
                );
              }
            case DeepLinkType.signerCallback:
              Log.info(
                '📱 Signer callback - triggering relay reconnection',
                name: 'DeepLinkHandler',
                category: LogCategory.auth,
              );
              ref.read(authServiceProvider).onSignerCallbackReceived();
            case DeepLinkType.unknown:
              Log.warning(
                '📱 Unknown deep link type',
                name: 'DeepLinkHandler',
                category: LogCategory.ui,
              );
          }
        },
        loading: () {
          Log.info(
            '🔗 Deep link loading...',
            name: 'DeepLinkHandler',
            category: LogCategory.ui,
          );
        },
        error: (error, stack) {
          Log.error(
            '🔗 Deep link error: $error',
            name: 'DeepLinkHandler',
            category: LogCategory.ui,
          );
        },
      );
    });

    const bool crashProbe = bool.fromEnvironment('CRASHLYTICS_PROBE');

    final router = ref.read(goRouterProvider);

    // Initialize back button handler (Android only - uses platform channel)
    if (!kIsWeb && io.Platform.isAndroid) {
      BackButtonHandler.initialize(router, ref);
    }

    // Helper functions for tab navigation
    RouteType routeTypeForTab(int index) {
      switch (index) {
        case 0:
          return RouteType.home;
        case 1:
          return RouteType.explore;
        case 2:
          return RouteType.notifications;
        case 3:
          return RouteType.profile;
        default:
          return RouteType.home;
      }
    }

    int? tabIndexFromRouteType(RouteType type) {
      switch (type) {
        case RouteType.home:
          return 0;
        case RouteType.explore:
        case RouteType.hashtag: // Hashtag is part of explore tab
          return 1;
        case RouteType.notifications:
          return 2;
        case RouteType.profile:
          return 3;
        default:
          return null; // Not a main tab route
      }
    }

    // Helper function to handle back navigation (iOS/macOS/Windows use PopScope)
    Future<bool> handleBackNavigation(GoRouter router, WidgetRef ref) async {
      // Get current route context
      final ctxAsync = ref.read(pageContextProvider);
      final ctx = ctxAsync.value;
      if (ctx == null) {
        return false; // Not handled - let PopScope handle it
      }

      // First, check if we're in a sub-route (hashtag, search, etc.)
      // If so, navigate back to parent route
      switch (ctx.type) {
        case RouteType.hashtag:
          // Hashtag is a standalone screen — pop back
          router.pop();
          return true; // Handled
        case RouteType.categoryGallery:
          if (router.canPop()) {
            router.pop();
          } else {
            router.go(ExploreScreen.path);
          }
          return true; // Handled
        case RouteType.videoRecorder:
        case RouteType.videoEditor:
        case RouteType.videoMetadata:
        case RouteType.videoEdit:
          // Pop the video editing flow screens
          router.pop();
          return true; // Handled
        default:
          break;
      }

      // For routes with videoIndex (feed mode), go to grid mode first
      // This handles page-internal navigation before tab switching
      // For explore: go to grid mode (null index)
      // For notifications: go to index 0 (notifications always has an index)
      // For other routes: go to grid mode (null index)
      if (ctx.videoIndex != null && ctx.videoIndex != 0) {
        final newRoute = switch (ctx.type) {
          // Notifications always has an index, go to index 0
          RouteType.notifications => NotificationsPage.pathForIndex(0),
          RouteType.explore => ExploreScreen.path,
          RouteType.profile => ProfileScreenRouter.pathForNpub(
            ctx.npub ?? 'me',
          ),
          RouteType.hashtag => HashtagScreenRouter.pathForTag(
            ctx.hashtag ?? '',
          ),
          RouteType.home => VideoFeedPage.pathForIndex(0),
          _ => ExploreScreen.path,
        };

        router.go(newRoute);
        return true; // Handled
      }

      // Check tab history for navigation
      final tabHistory = ref.read(tabHistoryProvider.notifier);
      final previousTab = tabHistory.getPreviousTab();

      // If there's a previous tab in history, navigate to it
      if (previousTab != null) {
        // Navigate to previous tab
        final previousRouteType = routeTypeForTab(previousTab);
        final lastIndex = ref
            .read(lastTabPositionProvider.notifier)
            .getPosition(previousRouteType);

        // Remove current tab from history before navigating
        tabHistory.navigateBack();

        // Navigate to previous tab using BuildContext extension methods
        // We need a BuildContext for this, but we don't have one here
        // So we'll use router.go directly
        switch (previousTab) {
          case 0:
            router.go(VideoFeedPage.pathForIndex(lastIndex ?? 0));
          case 1:
            if (lastIndex != null) {
              router.go(ExploreScreen.pathForIndex(lastIndex));
            } else {
              router.go(ExploreScreen.path);
            }
          case 2:
            router.go(NotificationsPage.pathForIndex(lastIndex ?? 0));
          case 3:
            // Get current user's npub for profile
            final authService = ref.read(authServiceProvider);
            final currentNpub = authService.currentNpub;
            if (currentNpub != null) {
              router.go(ProfileScreenRouter.pathForNpub(currentNpub));
            } else {
              router.go(VideoFeedPage.pathForIndex(0));
            }
        }
        return true; // Handled
      }

      // No previous tab - check if we're on a non-home tab
      // If so, go to home first before exiting
      final currentTab = tabIndexFromRouteType(ctx.type);
      if (currentTab != null && currentTab != 0) {
        // Go to home first
        router.go(VideoFeedPage.pathForIndex(0));
        return true; // Handled
      }

      // Already at home with no history - let PopScope handle exit
      return false; // Not handled - let PopScope handle it (may exit app)
    }

    // Build MaterialApp with locale from LocaleCubit.
    // The BlocBuilder is used because the cubit is provided further down
    // in the widget tree by MultiBlocProvider.
    Widget buildApp(Locale? locale) {
      if (locale != null) {
        Intl.defaultLocale = locale.toLanguageTag();
      }
      if (!kIsWeb && io.Platform.isAndroid) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: VineTheme.statusBarStyle,
          child: MaterialApp.router(
            title: 'Divine',
            debugShowCheckedModeBanner: false,
            theme: VineTheme.theme,
            routerConfig: router,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            localeListResolutionCallback: resolveAppUiLocale,
          ),
        );
      }
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await handleBackNavigation(router, ref);
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: VineTheme.statusBarStyle,
          child: MaterialApp.router(
            title: 'Divine',
            debugShowCheckedModeBanner: false,
            theme: VineTheme.theme,
            routerConfig: router,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            localeListResolutionCallback: resolveAppUiLocale,
          ),
        ),
      );
    }

    /// Creates the publish service with callbacks wired to this notifier.
    Future<VideoPublishService> createPublishService({
      required OnProgressChanged onProgress,
    }) async {
      final profileRepository = ref.read(profileRepositoryProvider);
      return VideoPublishService(
        uploadManager: ref.read(uploadManagerProvider),
        authService: ref.read(authServiceProvider),
        videoEventPublisher: ref.read(videoEventPublisherProvider),
        blossomService: ref.read(blossomUploadServiceProvider),
        draftService: ref.read(draftStorageServiceProvider),
        mentionResolutionService: profileRepository == null
            ? null
            : MentionResolutionService(
                profileRepository: profileRepository,
              ),
        collaboratorInviteService: CollaboratorInviteService(
          dmRepository: ref.read(dmRepositoryProvider),
          l10n: currentAppL10n(ref.read(sharedPreferencesProvider)),
        ),
        onProgressChanged:
            ({required String draftId, required double progress}) {
              onProgress(draftId: draftId, progress: progress);
            },
      );
    }

    const forceOpenOnboarding = AppConfig.isGhActionsPrPreviewBuild;

    // Gate the global PeopleListsBloc on the curated-lists feature flag.
    // When enabled we provision it above MaterialApp.router so every route
    // (including ones outside AppShell) sees the same lists state. The
    // bloc only depends on the repository and a pubkey stream; we derive
    // the latter from AuthService.
    final peopleListsEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );

    // Eagerly create the outgoing-DM retry service so its foreground
    // subscription is wired up at app shell setup. The service has no
    // UI consumer (it operates on the durable outgoing_dms queue), so
    // without an explicit read it would never be created. See #4124.
    ref.watch(outgoingDmRetryServiceProvider);

    // Eagerly create the notification realtime bridge so WS arrivals
    // land in the new repository snapshot the moment the repository is
    // available. The provider returns `null` until the repo is built;
    // the watch causes a rebuild that wires the bridge as soon as
    // [notificationRepositoryProvider] yields a non-null value. See
    // #4204 (badge / list realtime sync).
    ref.watch(notificationRealtimeBridgeProvider);

    // Wrap with geo-blocking check first, then lifecycle handler
    Widget wrapped = MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => InviteApiClient(
            baseUrl: AppConfig.inviteServerBaseUrl,
            // ignore: avoid_redundant_argument_values
            forceOpenOnboarding: forceOpenOnboarding,
            authHeaderProvider:
                ({
                  required String url,
                  required InviteRequestMethod method,
                  String? payload,
                }) async {
                  final authService = ref.read(nip98AuthServiceProvider);
                  if (!authService.canCreateTokens) return null;
                  final token = await authService.createAuthToken(
                    url: url,
                    method: switch (method) {
                      InviteRequestMethod.get => HttpMethod.get,
                      InviteRequestMethod.post => HttpMethod.post,
                      InviteRequestMethod.put => HttpMethod.put,
                      InviteRequestMethod.patch => HttpMethod.patch,
                    },
                    payload: payload,
                  );
                  return token?.authorizationHeader;
                },
            warningLogger: (message) {
              Log.warning(
                message,
                name: 'InviteApiClient',
                category: LogCategory.api,
              );
            },
          ),
          dispose: (client) => client.dispose(),
        ),
        BlocProvider(
          create: (_) =>
              DmUnreadCountCubit(dmRepository: ref.read(dmRepositoryProvider)),
        ),
        // Notification badge cubit. Subscribes to the new
        // `NotificationRepository.watchUnreadCount()` stream so the
        // bottom-nav badge stays in lock-step with per-row reads,
        // mark-all-read flows, and WS realtime arrivals (the latter via
        // [NotificationRealtimeBridge] below). The repository is `null`
        // during early auth — the cubit handles that by emitting 0 with
        // no subscription. The `ValueKey` on the BlocProvider keyed to
        // the repository's identity recreates the cubit when the
        // underlying repository instance flips (account switch).
        BlocProvider(
          key: ValueKey(
            identityHashCode(ref.watch(notificationRepositoryProvider)),
          ),
          create: (_) => NotificationBadgeCubit(
            repository: ref.read(notificationRepositoryProvider),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            lazy: false,
            create: (_) => VideoVolumeCubit(
              sharedPreferences: ref.read(sharedPreferencesProvider),
            ),
          ),
          BlocProvider(
            create: (_) => LocaleCubit(
              localePreferenceService: LocalePreferenceService(
                sharedPreferences: ref.read(sharedPreferencesProvider),
              ),
            ),
          ),
          BlocProvider(
            create: (_) => BackgroundPublishBloc(
              videoPublishServiceFactory: createPublishService,
              draftStorageService: ref.read(draftStorageServiceProvider),
            ),
          ),
          BlocProvider(
            create: (_) => CameraPermissionBloc(
              permissionsService: const PermissionHandlerPermissionsService(),
            )..add(const CameraPermissionRefresh()),
          ),
          BlocProvider(
            create: (context) => InviteGateBloc(
              inviteApiClient: context.read<InviteApiClient>(),
            ),
          ),
          BlocProvider(
            create: (context) => EmailVerificationCubit(
              oauthClient: ref.read(oauthClientProvider),
              authService: ref.read(authServiceProvider),
              inviteApiClient: context.read<InviteApiClient>(),
            ),
          ),
          BlocProvider(
            create: (context) => InviteStatusCubit(
              inviteApiClient: context.read<InviteApiClient>(),
            ),
          ),
          BlocProvider(
            create: (_) => AppUpdateBloc(
              repository: AppUpdateRepository(
                appVersionClient: AppVersionClient(),
                sharedPreferences: ref.read(sharedPreferencesProvider),
                currentVersion: widget.packageInfo.version,
                installSource: InstallSource.sideload,
              ),
            )..add(const AppUpdateCheckRequested()),
          ),
          if (peopleListsEnabled)
            BlocProvider(
              create: (_) {
                final authService = ref.read(authServiceProvider);
                final ownerPubkeyStream = authService.authStateStream
                    .map((_) => authService.currentPublicKeyHex)
                    .distinct();
                return PeopleListsBloc(
                  repository: ref.read(peopleListsRepositoryProvider),
                  ownerPubkeyStream: ownerPubkeyStream,
                  initialOwnerPubkey: authService.currentPublicKeyHex,
                )..add(const PeopleListsStarted());
              },
            ),
        ],
        // Global listener for email verification failures - shows snackbar
        // when verification times out or fails while user is elsewhere in app
        child: BlocListener<EmailVerificationCubit, EmailVerificationState>(
          listenWhen: (previous, current) =>
              current.status == EmailVerificationStatus.failure &&
              previous.status != EmailVerificationStatus.failure,
          listener: (context, state) {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final errorCode = state.errorCode;
            if (messenger != null && errorCode != null) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.emailVerificationErrorMessage(errorCode),
                  ),
                  backgroundColor: VineTheme.error,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          },
          child: UpdateDialogListener(
            child: _UploadFailureListener(
              child: GeoBlockingGate(
                child: AppLifecycleHandler(
                  child: BlocBuilder<LocaleCubit, LocaleState>(
                    builder: (context, localeState) =>
                        buildApp(localeState.locale),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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

    return wrapped; // ProviderScope now wraps DivineApp from outside
  }
}

/// Listens for background upload failures and shows a bottom sheet.
///
/// Uses [NavigatorKeys.root] to obtain a [BuildContext] inside the
/// [Navigator] tree, which [showModalBottomSheet] requires.
///
/// Tracks the set of currently-failed draft IDs so that only **new**
/// failures trigger a sheet. When a draft is retried or dismissed its ID
/// leaves the failed set, so a subsequent failure is detected as new again.
class _UploadFailureListener extends StatefulWidget {
  const _UploadFailureListener({required this.child});

  final Widget child;

  @override
  State<_UploadFailureListener> createState() => _UploadFailureListenerState();
}

class _UploadFailureListenerState extends State<_UploadFailureListener> {
  var _lastKnownFailedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackgroundPublishBloc, BackgroundPublishState>(
      listener: (context, state) {
        // Don't show failure sheets while the user is not authenticated
        // (e.g. still on the login screen after a cold start).
        // Also don't update _lastKnownFailedIds so these failures are
        // detected as "new" once the user eventually authenticates.
        final authService = ProviderScope.containerOf(
          context,
        ).read(authServiceProvider);
        if (!authService.isAuthenticated) return;

        final currentFailedIds = state.uploads
            .where((u) => u.result is PublishError)
            .map((u) => u.draft.id)
            .toSet();

        final newFailedIds = currentFailedIds.difference(_lastKnownFailedIds);
        _lastKnownFailedIds = currentFailedIds;

        if (newFailedIds.isEmpty) return;

        final navContext = NavigatorKeys.root.currentContext;
        if (navContext == null) return;

        final newFailures = state.uploads
            .where((u) => newFailedIds.contains(u.draft.id))
            .toList();

        _showFailureSheetsSequentially(navContext, newFailures);
      },
      child: widget.child,
    );
  }
}

/// Shows failure bottom sheets one after another for each failed upload.
Future<void> _showFailureSheetsSequentially(
  BuildContext context,
  List<BackgroundUpload> failedUploads,
) async {
  for (final upload in failedUploads) {
    if (!context.mounted) return;
    await showUploadFailureSheet(context, upload);
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
      try {
        FirebaseCrashlytics.instance.log('CrashProbe: triggering test crash');
      } catch (_) {}
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
