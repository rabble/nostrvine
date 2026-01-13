// ABOUTME: Router-driven active video provider
// ABOUTME: Derives active video ID from URL context, feed state, and app foreground state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/providers/liked_videos_state_bridge.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';

/// Active video ID derived from router state and app lifecycle
/// Returns null when app is backgrounded, overlay is visible, or no valid video at current index
/// Route-aware: switches feed provider based on route type
final activeVideoIdProvider = Provider<String?>((ref) {
  // Check app foreground state - be defensive and require explicit foreground signal
  final isFg = ref
      .watch(appForegroundProvider)
      .maybeWhen(
        data: (v) => v,
        orElse: () => false, // Default to background if provider not ready
      );
  if (!isFg) {
    Log.debug(
      '[ACTIVE] ❌ App not in foreground',
      name: 'ActiveVideoProvider',
      category: LogCategory.system,
    );
    return null;
  }

  // Check if any overlay (drawer, settings, modal) is visible
  final hasOverlay = ref.watch(hasVisibleOverlayProvider);
  if (hasOverlay) {
    Log.debug(
      '[ACTIVE] ❌ Overlay is visible (drawer/settings/modal)',
      name: 'ActiveVideoProvider',
      category: LogCategory.system,
    );
    return null;
  }

  // Get current page context from router
  final ctx = ref.watch(pageContextProvider).asData?.value;
  if (ctx == null) {
    Log.debug(
      '[ACTIVE] ❌ No page context available',
      name: 'ActiveVideoProvider',
      category: LogCategory.system,
    );
    return null;
  }

  Log.debug(
    '[ACTIVE] 📍 Route context: type=${ctx.type}, videoIndex=${ctx.videoIndex}',
    name: 'ActiveVideoProvider',
    category: LogCategory.system,
  );

  // Select feed provider based on route type
  AsyncValue<VideoFeedState> videosAsync;
  switch (ctx.type) {
    case RouteType.home:
      videosAsync = ref.watch(videosForHomeRouteProvider);
      break;
    case RouteType.profile:
      videosAsync = ref.watch(videosForProfileRouteProvider);
      break;
    case RouteType.hashtag:
      videosAsync = ref.watch(hashtagFeedProvider);
      break;
    case RouteType.explore:
      videosAsync = ref.watch(videosForExploreRouteProvider);
      break;
    case RouteType.search:
      videosAsync = ref.watch(videosForSearchRouteProvider);
      break;
    case RouteType.likedVideos:
      videosAsync = ref.watch(likedVideosFeedProvider);
      break;
    case RouteType.videoFeed:
      // videoFeed route manages its own playback via passed videos
      // Return null to let FullscreenVideoFeedScreen handle it internally
      Log.debug(
        '[ACTIVE] ❌ videoFeed route (self-managed)',
        name: 'ActiveVideoProvider',
        category: LogCategory.system,
      );
      return null;
    case RouteType.notifications:
    case RouteType.camera:
    case RouteType.clipManager:
    case RouteType.editVideo:
    case RouteType.settings:
    case RouteType.relaySettings:
    case RouteType.relayDiagnostic:
    case RouteType.blossomSettings:
    case RouteType.notificationSettings:
    case RouteType.keyManagement:
    case RouteType.safetySettings:
    case RouteType.editProfile:
    case RouteType.clips:
    case RouteType.importKey:
    case RouteType.welcome:
    case RouteType.developerOptions:
    case RouteType.loginOptions:
    case RouteType.authNative:
    case RouteType.followers:
    case RouteType.following:
    case RouteType.profileView:
    case RouteType.curatedList:
    case RouteType.discoverLists:
    case RouteType.sound:
    case RouteType.secureAccount:
      // Non-video routes - return null
      Log.debug(
        '[ACTIVE] ❌ Non-video route: ${ctx.type}',
        name: 'ActiveVideoProvider',
        category: LogCategory.system,
      );
      return null;
  }

  final videos = videosAsync.maybeWhen(
    data: (state) => state.videos,
    orElse: () => const <VideoEvent>[],
  );

  Log.debug(
    '[ACTIVE] 📊 Feed state: videosAsync.hasValue=${videosAsync.hasValue}, videos.length=${videos.length}',
    name: 'ActiveVideoProvider',
    category: LogCategory.system,
  );

  if (videos.isEmpty) {
    Log.debug(
      '[ACTIVE] ❌ No videos in feed',
      name: 'ActiveVideoProvider',
      category: LogCategory.system,
    );
    return null;
  }

  // Grid mode (no videoIndex) - no active video
  if (ctx.videoIndex == null) {
    Log.debug(
      '[ACTIVE] ❌ Grid mode (no videoIndex)',
      name: 'ActiveVideoProvider',
      category: LogCategory.system,
    );
    return null;
  }

  // Get video at current index - videoIndex maps directly to list index
  final idx = ctx.videoIndex!.clamp(0, videos.length - 1);
  final video = videos[idx];

  Log.info(
    '[ACTIVE] ✅ Active video at index $idx: ${video.stableId} (vineId=${video.vineId}, id=${video.id})',
    name: 'ActiveVideoProvider',
    category: LogCategory.system,
  );

  return video.stableId;
});

/// Per-video active state (for efficient VideoFeedItem updates)
/// Returns true if the given videoId matches the current active video
final isVideoActiveProvider = Provider.family<bool, String>((ref, videoId) {
  final activeVideoId = ref.watch(activeVideoIdProvider);
  return activeVideoId == videoId;
});

/// Auto-cleanup provider that disposes all video controllers when navigating
/// between different screens (e.g., home → explore, home → camera).
///
/// This ensures videos stop playing when leaving a video feed screen.
/// Does NOT dispose on swipe within the same feed to avoid flicker.
///
/// Must be watched at app level to activate.
final videoControllerAutoCleanupProvider = Provider<void>((ref) {
  // Track previous route type to detect screen changes vs swipes
  RouteType? previousRouteType;

  // Listen to page context changes to detect route type changes
  ref.listen<AsyncValue<RouteContext>>(pageContextProvider, (previous, next) {
    final prevCtx = previous?.asData?.value;
    final nextCtx = next.asData?.value;

    // Update previous route type for next comparison
    final prevType = prevCtx?.type ?? previousRouteType;
    final nextType = nextCtx?.type;

    if (nextType != null) {
      previousRouteType = nextType;
    }

    // Only dispose controllers when route TYPE changes (screen navigation)
    // Don't dispose on videoIndex change (swipe within same feed)
    if (prevType != null && nextType != null && prevType != nextType) {
      Log.info(
        '🧹 Route type changed ($prevType → $nextType), disposing all video controllers',
        name: 'VideoControllerCleanup',
        category: LogCategory.video,
      );

      // Dispose all controllers when leaving a video feed screen
      disposeAllVideoControllers(ref.container);
    }
  }, fireImmediately: false);
});
