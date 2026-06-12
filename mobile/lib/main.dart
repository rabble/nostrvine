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
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/observability/divine_bloc_observer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/db_cipher_key_provider.dart';
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
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/back_button_handler.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/corrupted_video_repair_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/firebase_initialization.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/nip98_auth_service.dart' show HttpMethod;
import 'package:openvine/services/notification_helpers.dart'
    show localNotificationTapPayload, parseFcmPayload;
import 'package:openvine/services/notification_service.dart'
    show NotificationTapEvent;
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/pro_video_editor_log_forwarder.dart';
import 'package:openvine/services/quick_actions_coordinator.dart';
import 'package:openvine/services/seed_data_preload_service.dart';
import 'package:openvine/services/seed_media_preload_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/log_message_batcher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:openvine/utils/recoverable_flutter_error.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:openvine/widgets/geo_blocking_gate.dart';
import 'package:openvine/widgets/upload_failure_sheet.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Top-level background message handler required by Firebase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureDefaultFirebaseInitialized();

  // The OS already presents iOS alert pushes (aps.alert); only render a local
  // notification for data-only messages so we don't double-render (#4731).
  if (!shouldRenderLocalPushNotification(message)) return;

  final data = message.data;
  final title = data['title'] as String? ?? 'diVine';
  final body = data['body'] as String? ?? '';

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
    macOS: darwinInit,
  );
  await plugin.initialize(settings: initSettings);

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
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
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

/// Describes the router action to take when navigating to a profile deep link.
///
/// Mirrors [VideoDeepLinkNavAction] so profile links get the same nav-stack
/// parity video links already have: `push` keeps the previous route (e.g. home)
/// underneath so back returns there, `go` replaces an existing profile route
/// in-place, and `skip` dedupes a navigation to the route already shown.
@visibleForTesting
enum ProfileDeepLinkNavAction {
  /// Navigate to the route, keeping the current route in the back stack.
  push,

  /// Replace the current route in-place (already on a profile route).
  go,

  /// The router is already on the target route with nothing new to do.
  skip,
}

/// Determines which router action to take for a profile deep-link navigation
/// given the current router location and the incoming target path.
///
/// Mirrors [resolveVideoDeepLinkNavAction]: extracted for testability — the
/// caller executes the action; this function only decides what it should be.
///
/// Before this existed, the profile case always called `router.go()`, which
/// replaces the entire navigation stack and stranded the user wherever they
/// were (mid-settings, camera, DMs, …) with no back button to return.
@visibleForTesting
ProfileDeepLinkNavAction resolveProfileDeepLinkNavAction({
  required String currentLocation,
  required String targetPath,
}) {
  if (currentLocation == targetPath) {
    // Already on the exact target route. Duplicate navigation with nothing new
    // to do (e.g. GoRouter's universal-link redirect already navigated here, or
    // getInitialLink + uriLinkStream both fire for the same URL). Safe to skip.
    return ProfileDeepLinkNavAction.skip;
  }
  if (currentLocation.startsWith('${ProfileScreenRouter.path}/')) {
    // A different profile is already showing — replace it in-place, matching
    // the video-replaces-video behaviour.
    return ProfileDeepLinkNavAction.go;
  }
  // Coming from a non-profile route — push so back returns to where the user
  // was instead of obliterating the navigation stack.
  return ProfileDeepLinkNavAction.push;
}

/// Describes the router action to take when navigating to a hashtag deep link.
///
/// Mirrors [VideoDeepLinkNavAction] and [ProfileDeepLinkNavAction] so hashtag
/// links get the same nav-stack parity: `push` keeps the previous route (e.g.
/// home) underneath so back returns there, `go` replaces an existing hashtag
/// route in-place, and `skip` dedupes a navigation to the route already shown.
@visibleForTesting
enum HashtagDeepLinkNavAction {
  /// Navigate to the route, keeping the current route in the back stack.
  push,

  /// Replace the current route in-place (already on a hashtag route).
  go,

  /// The router is already on the target route with nothing new to do.
  skip,
}

/// Determines which router action to take for a hashtag deep-link navigation
/// given the current router location and the incoming target path.
///
/// Mirrors [resolveProfileDeepLinkNavAction]: extracted for testability — the
/// caller executes the action; this function only decides what it should be.
///
/// Before this existed, the hashtag case always called `router.go()`, which
/// replaces the entire navigation stack and stranded the user wherever they
/// were (mid-settings, camera, DMs, …) with no back button to return.
@visibleForTesting
HashtagDeepLinkNavAction resolveHashtagDeepLinkNavAction({
  required String currentLocation,
  required String targetPath,
}) {
  if (currentLocation == targetPath) {
    // Already on the exact target route. Duplicate navigation with nothing new
    // to do (e.g. GoRouter's universal-link redirect already navigated here, or
    // getInitialLink + uriLinkStream both fire for the same URL). Safe to skip.
    return HashtagDeepLinkNavAction.skip;
  }
  if (currentLocation.startsWith('${HashtagScreenRouter.basePath}/')) {
    // A different hashtag is already showing — replace it in-place, matching
    // the video-replaces-video behaviour.
    return HashtagDeepLinkNavAction.go;
  }
  // Coming from a non-hashtag route — push so back returns to where the user
  // was instead of obliterating the navigation stack.
  return HashtagDeepLinkNavAction.push;
}

/// Describes the router action to take when navigating to a search deep link.
///
/// Mirrors [VideoDeepLinkNavAction] and [ProfileDeepLinkNavAction] so search
/// links get the same nav-stack parity: `push` keeps the previous route (e.g.
/// home) underneath so back returns there, `go` replaces an existing search
/// route in-place, and `skip` dedupes a navigation to the route already shown.
@visibleForTesting
enum SearchDeepLinkNavAction {
  /// Navigate to the route, keeping the current route in the back stack.
  push,

  /// Replace the current route in-place (already on a search route).
  go,

  /// The router is already on the target route with nothing new to do.
  skip,
}

/// Determines which router action to take for a search deep-link navigation
/// given the current router location and the incoming target path.
///
/// Mirrors [resolveProfileDeepLinkNavAction]: extracted for testability — the
/// caller executes the action; this function only decides what it should be.
///
/// Before this existed, the search case always called `router.go()`, which
/// replaces the entire navigation stack and stranded the user wherever they
/// were (mid-settings, camera, DMs, …) with no back button to return.
///
/// The "already in the search family" check covers three location shapes:
/// a prefilled query (`/search-results/<query>`), the empty search screen
/// (`/search-results`, [SearchResultsPage.emptyPath]), and the empty search
/// screen with a query string (`/search-results?focus=1`, produced by
/// [SearchResultsPage.pathForEmptyQuery] when mount focus is requested). All
/// three are the same search surface, so a deep link replaces them in-place
/// rather than stacking search on top of search.
@visibleForTesting
SearchDeepLinkNavAction resolveSearchDeepLinkNavAction({
  required String currentLocation,
  required String targetPath,
}) {
  if (currentLocation == targetPath) {
    // Already on the exact target route. Duplicate navigation with nothing new
    // to do (e.g. GoRouter's universal-link redirect already navigated here, or
    // getInitialLink + uriLinkStream both fire for the same URL). Safe to skip.
    return SearchDeepLinkNavAction.skip;
  }
  if (currentLocation == SearchResultsPage.emptyPath ||
      currentLocation.startsWith('${SearchResultsPage.pathPrefix}/') ||
      currentLocation.startsWith('${SearchResultsPage.emptyPath}?')) {
    // Already somewhere on the search surface (empty search, a different
    // query, or empty search with ?focus=1) — replace it in-place, matching
    // the video-replaces-video behaviour.
    return SearchDeepLinkNavAction.go;
  }
  // Coming from a non-search route — push so back returns to where the user
  // was instead of obliterating the navigation stack.
  return SearchDeepLinkNavAction.push;
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
    disposeAllVideoControllers(container);
    _router.go(VideoRecorderScreen.path);
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

void _removeSplashWhenStartupAuthSettles(AuthService authService) {
  unawaited(
    _waitForStartupAuthTerminalState(authService)
        .timeout(AuthService.startupAuthRestoreTimeout)
        .catchError((Object error, StackTrace stackTrace) {
          Log.warning(
            '[INIT] Auth startup did not settle before splash timeout: $error',
            name: 'Main',
            category: LogCategory.system,
          );
        })
        .whenComplete(FlutterNativeSplash.remove),
  );
}

Future<void> _waitForStartupAuthTerminalState(AuthService authService) async {
  if (_isTerminalStartupAuthState(authService.authState)) return;
  await authService.authStateStream.firstWhere(_isTerminalStartupAuthState);
}

bool _isTerminalStartupAuthState(AuthState state) {
  return switch (state) {
    AuthState.unauthenticated ||
    AuthState.awaitingTosAcceptance ||
    AuthState.authenticated => true,
    AuthState.checking || AuthState.authenticating => false,
  };
}

Future<void> _startOpenVineApp() async {
  // Add timing logs for startup diagnostics
  final startTime = DateTime.now();

  // Ensure bindings are initialized first (required for everything)
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

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

  // Resolve the at-rest database cipher key before the container so the
  // database provider opens an encrypted SQLCipher connection on first use.
  // This also forces package:sqlite3 onto the SQLCipher build (Android) and
  // runs the one-time plaintext→encrypted migration, both of which must happen
  // before any sqlite3 open. (#570, finding C2)
  String? dbCipherKey;
  try {
    dbCipherKey = await DatabaseEncryptionBootstrap(
      // resetOnError MUST stay false here: the cipher key is the one secret
      // whose loss makes the encrypted DB unrecoverable. A transient keystore
      // read error must throw (caught below → plaintext this launch, retry
      // next) rather than silently deleting the key and triggering the §6
      // key-loss recovery. (#570 C2)
      secureStorage: const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    ).resolveCipherKey();
  } catch (error, stack) {
    // SQLCipher build misconfiguration or an unexpected keystore failure.
    // Report and degrade to a plaintext database so the app still launches;
    // the device-QA gate prevents an unencrypted build from shipping. (#570 C2)
    await CrashReportingService.instance.recordError(
      error,
      stack,
      reason: 'DatabaseEncryptionBootstrap.resolveCipherKey failed',
    );
  }

  // Create ProviderContainer to initialize services BEFORE runApp
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      dbCipherKeyProvider.overrideWithValue(dbCipherKey),
    ],
  );

  final startupCoordinator = _createStartupCoordinator(container);
  _removeSplashWhenStartupAuthSettles(container.read(authServiceProvider));
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

  // Tag every crash report with the running build so per-error triage doesn't
  // have to cross-reference the release dashboard. Set once, not per-error.
  // See #3758.
  unawaited(
    CrashReportingService.instance.setCustomKey(
      'build_tag',
      '${packageInfo.version}+${packageInfo.buildNumber}',
    ),
  );

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
  QuickActionsCoordinator? _quickActionsCoordinator;

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
        _initializeQuickActions();
        _initializeBackgroundServices();
      }
    });
  }

  @override
  void dispose() {
    _notificationTapSubscription?.cancel();
    unawaited(_quickActionsCoordinator?.dispose());
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
                  final action = resolveProfileDeepLinkNavAction(
                    currentLocation: currentLocation,
                    targetPath: targetPath,
                  );
                  switch (action) {
                    case ProfileDeepLinkNavAction.skip:
                      // GoRouter's universal-link redirect may have already
                      // navigated here; skip the duplicate navigation to avoid
                      // a second navigation frame on the same target.
                      break;
                    case ProfileDeepLinkNavAction.go:
                      // Another profile is already showing — replace it
                      // in-place instead of stacking it.
                      router.go(targetPath);
                    case ProfileDeepLinkNavAction.push:
                      // Keep the current route underneath so back returns to
                      // wherever the user was instead of wiping the stack.
                      router.push(targetPath);
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
                  final action = resolveHashtagDeepLinkNavAction(
                    currentLocation: currentLocation,
                    targetPath: targetPath,
                  );
                  switch (action) {
                    case HashtagDeepLinkNavAction.skip:
                      // GoRouter's universal-link redirect may have already
                      // navigated here; skip the duplicate navigation to avoid
                      // a second navigation frame on the same target.
                      break;
                    case HashtagDeepLinkNavAction.go:
                      // Another hashtag is already showing — replace it
                      // in-place instead of stacking it.
                      router.go(targetPath);
                    case HashtagDeepLinkNavAction.push:
                      // Keep the current route underneath so back returns to
                      // wherever the user was instead of wiping the stack.
                      router.push(targetPath);
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
                  final action = resolveSearchDeepLinkNavAction(
                    currentLocation: currentLocation,
                    targetPath: targetPath,
                  );
                  switch (action) {
                    case SearchDeepLinkNavAction.skip:
                      // GoRouter's universal-link redirect may have already
                      // navigated here; skip the duplicate navigation to avoid
                      // a second navigation frame on the same target.
                      break;
                    case SearchDeepLinkNavAction.go:
                      // Already on the search surface (empty search, another
                      // query, or ?focus=1) — replace it in-place instead of
                      // stacking search on top of search.
                      router.go(targetPath);
                    case SearchDeepLinkNavAction.push:
                      // Keep the current route underneath so back returns to
                      // wherever the user was instead of wiping the stack.
                      router.push(targetPath);
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
            : MentionResolutionService(profileRepository: profileRepository),
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

    // Eagerly create the view-event retry service so foreground sweeps
    // run for the durable pending_view_events queue without a UI consumer.
    ref.watch(viewEventRetryServiceProvider);

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
        // Notification badge cubit. Keep the provider identity stable so
        // repository readiness/account switches do not remount MaterialApp
        // and AppShell; the sync widget below swaps only the cubit's stream
        // subscription when the repository identity changes.
        BlocProvider(
          create: (_) => NotificationBadgeCubit(
            repository: ref.read(notificationRepositoryProvider),
          ),
        ),
      ],
      child: _NotificationBadgeRepositorySync(
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
                isInviteAuthReady: () =>
                    ref.read(nip98AuthServiceProvider).canCreateTokens,
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
              child: UploadFailureListener(
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

class _NotificationBadgeRepositorySync extends ConsumerWidget {
  const _NotificationBadgeRepositorySync({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationRepositoryProvider, (_, repository) {
      context.read<NotificationBadgeCubit>().setRepository(repository);
    });
    return child;
  }
}

/// Listens for background upload completions and shows the appropriate UI.
///
/// Uses [NavigatorKeys.root] to obtain a [BuildContext] inside the
/// [Navigator] tree, which [showModalBottomSheet] and [ScaffoldMessenger]
/// require.
///
/// **Failure tracking:** Tracks the set of currently-failed draft IDs so that
/// only *new* failures trigger a sheet. When a draft is retried or dismissed
/// its ID leaves the failed set, so a subsequent failure is detected as new.
///
/// **Success tracking (publish-flow continuity, #4626):** Reads
/// [BackgroundPublishState.recentlySucceededIds] — populated by the bloc only
/// on a true [PublishSuccess], never on [BackgroundPublishVanished] — so a
/// vanished upload cannot produce a false "published" snackbar. If the user is
/// not yet authenticated at the moment of success (mid re-auth redirect), the
/// count is buffered and shown once authentication is restored.
@visibleForTesting
class UploadFailureListener extends StatefulWidget {
  const UploadFailureListener({required this.child, super.key});

  final Widget child;

  @override
  State<UploadFailureListener> createState() => _UploadFailureListenerState();
}

class _UploadFailureListenerState extends State<UploadFailureListener> {
  var _lastKnownFailedIds = <String>{};
  var _pendingSuccessCount = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackgroundPublishBloc, BackgroundPublishState>(
      listener: (context, state) {
        final authService = ProviderScope.containerOf(
          context,
        ).read(authServiceProvider);

        // Use the bloc's own recentlySucceededIds so we never confuse a
        // BackgroundPublishVanished removal with a true publish success.
        final succeededCount = state.recentlySucceededIds.length;

        if (succeededCount > 0) {
          if (authService.isAuthenticated) {
            // Show immediately — user is still in-app.
            _showPublishSuccessSnackbar(context, succeededCount);
          } else {
            // Buffer for when auth is restored after re-auth redirect.
            _pendingSuccessCount += succeededCount;
          }
        }

        final currentFailedIds = state.uploads
            .where((u) => u.result is PublishError)
            .map((u) => u.draft.id)
            .toSet();

        // Don't show failure sheets while the user is not authenticated
        // (e.g. still on the login screen after a cold start).
        // Also don't update _lastKnownFailedIds so these failures are
        // detected as "new" once the user eventually authenticates.
        if (!authService.isAuthenticated) {
          return;
        }

        // Auth is now confirmed — flush buffered successes from re-auth window.
        if (_pendingSuccessCount > 0) {
          _showPublishSuccessSnackbar(context, _pendingSuccessCount);
          _pendingSuccessCount = 0;
        }

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

/// Shows a snackbar confirming that [count] background uploads completed.
///
/// Uses [ScaffoldMessenger] via [NavigatorKeys.root] to reach the root
/// [Scaffold] — this is required because the listener's [BuildContext] may
/// not have a [Scaffold] ancestor when the snackbar fires during a re-auth
/// redirect. The l10n strings are resolved from the passed-in [context]
/// (the BlocListener's context), which always has localisation ancestors.
void _showPublishSuccessSnackbar(BuildContext context, int count) {
  final navContext = NavigatorKeys.root.currentContext;
  if (navContext == null || !navContext.mounted) return;
  final l10n = context.l10n;
  ScaffoldMessenger.of(navContext).showSnackBar(
    SnackBar(
      content: Text(
        l10n.uploadPublishedCountMessage(count),
        style: VineTheme.bodyMediumFont(),
      ),
      backgroundColor: VineTheme.navGreen,
      behavior: SnackBarBehavior.floating,
    ),
  );
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
