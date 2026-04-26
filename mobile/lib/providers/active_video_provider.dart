// ABOUTME: Router-driven active video provider
// ABOUTME: Derives active video ID from URL context, feed state, and app foreground state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:unified_logger/unified_logger.dart';

/// Active video ID derived from router state and app lifecycle
/// Returns null when app is backgrounded, overlay is visible, or no valid video at current index
/// Route-aware: switches feed provider based on route type
final activeVideoIdProvider = Provider<String?>((ref) {
  // Check app foreground state using the Notifier-based provider that
  // defaults to true immediately (no stream delay). The old StreamProvider
  // defaulted to false when the stream hadn't emitted yet, causing all
  // videos to pause on startup until the stream caught up.
  final isFg = ref.watch(appForegroundProvider);
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
      // Home feed uses PooledVideoFeed which manages its own playback
      // via VideoFeedController. Return null to let it handle internally.
      Log.debug(
        '[ACTIVE] Home route (self-managed by PooledVideoFeed)',
        name: 'ActiveVideoProvider',
        category: LogCategory.system,
      );
      return null;
    case RouteType.profile:
      videosAsync = ref.watch(videosForProfileRouteProvider);
    case RouteType.hashtag:
      // Hashtag feed uses PooledFullscreenVideoFeedScreen pushed as overlay,
      // which manages its own playback. Return null to let it handle internally.
      return null;
    case RouteType.explore:
      videosAsync = ref.watch(videosForExploreRouteProvider);
    case RouteType.likedVideos:
      // Liked videos feed mode uses PooledFullscreenVideoFeedScreen inline,
      // which self-manages playback. Return null.
      return null;
    case RouteType.videoFeed: // legacy alias, same as pooledVideoFeed
    case RouteType.pooledVideoFeed:
    case RouteType.videoDetail:
      // Pooled feed routes manage their own playback internally.
      // Return null to let the screen handle it.
      Log.debug(
        '[ACTIVE] ❌ pooledVideoFeed route (self-managed)',
        name: 'ActiveVideoProvider',
        category: LogCategory.system,
      );
      return null;
    case RouteType.notifications:
    case RouteType.inbox:
    case RouteType.conversation:
    case RouteType.categoryGallery:
    case RouteType.videoRecorder:
    case RouteType.videoEditor:
    case RouteType.videoMetadata:
    case RouteType.settings:
    case RouteType.relaySettings:
    case RouteType.relayDiagnostic:
    case RouteType.blossomSettings:
    case RouteType.notificationSettings:
    case RouteType.keyManagement:
    case RouteType.safetySettings:
    case RouteType.contentFilters:
    case RouteType.contentPreferences:
    case RouteType.generalSettings:
    case RouteType.supportCenter:
    case RouteType.legal:
    case RouteType.nostrSettings:
    case RouteType.blueskySettings:
    case RouteType.editProfile:
    case RouteType.clips:
    case RouteType.clipsNoSound:
    case RouteType.drafts:
    case RouteType.importKey:
    case RouteType.welcome:
    case RouteType.developerOptions:
    case RouteType.loginOptions:
    case RouteType.followers:
    case RouteType.following:
    case RouteType.profileView:
    case RouteType.curatedList:
    case RouteType.discoverLists:
    case RouteType.creatorAnalytics:
    case RouteType.sound:
    case RouteType.originalSound:
    case RouteType.secureAccount:
    case RouteType.messageRequests:
    case RouteType.requestPreview:
    case RouteType.appLanguage:
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
final ProviderFamily<bool, String> isVideoActiveProvider =
    Provider.family<bool, String>((ref, videoId) {
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
  });
});
