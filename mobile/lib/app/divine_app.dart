// ABOUTME: The root app widget: lifecycle, memory telemetry, deferred startup
// ABOUTME: Split out of main.dart, which is now only the entry point (#3337)

import 'dart:async';
import 'dart:io'
    if (dart.library.html) 'package:openvine/utils/platform_io_web.dart'
    as io;

import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/deep_link_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/foreground_idle_warmup_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/deep_link_coordinator.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/back_button_handler.dart';
import 'package:openvine/services/corrupted_video_repair_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/memory_pressure_handler.dart';
import 'package:openvine/services/memory_telemetry_service.dart';
import 'package:openvine/services/notification_service.dart'
    show NotificationTapEvent;
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/quick_actions_coordinator.dart';
import 'package:openvine/startup/app_composition_root.dart';
import 'package:openvine/startup/app_side_effects.dart';
import 'package:openvine/startup/divine_material_app.dart';
import 'package:openvine/startup/startup_splash_release_controller.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unified_logger/unified_logger.dart';

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
            routeNotificationTap(
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
