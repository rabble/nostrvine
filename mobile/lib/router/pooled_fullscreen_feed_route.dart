// ABOUTME: Builder + redirect for the /pooled-video-feed fullscreen route.
// ABOUTME: Extracted from app_router.dart to keep that file under its size ceiling.

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';

/// Redirect target for the fullscreen video feed route.
///
/// The route receives its videos through in-memory `extra` args, which the web
/// platform discards on page reload / direct navigation. When [extra] is not a
/// valid args object, redirect to the home feed instead of showing an error
/// screen. Returns `null` (no redirect) when the args are present.
String? fullscreenFeedRedirect(Object? extra) {
  if (extra is PooledFullscreenVideoFeedArgs ||
      extra is ProfilePooledFullscreenVideoFeedArgs) {
    return null;
  }
  return VideoFeedPage.pathForIndex(0);
}

/// Builds the fullscreen video feed for the matched route, resolving the
/// in-memory `extra` args. [fullscreenFeedRedirect] guarantees valid args
/// before this runs; the final [RouteErrorScreen] is a defensive fallback.
Widget buildPooledFullscreenFeed(BuildContext context, GoRouterState state) {
  final extra = state.extra;
  if (extra is PooledFullscreenVideoFeedArgs) {
    return PooledFullscreenVideoFeedScreen(
      source: extra.source,
      feedRepository: extra.feedRepository,
      initialIndex: extra.initialIndex,
      initialVideoId: extra.initialVideoId,
      initialStableId: extra.initialStableId,
      contextTitle: extra.contextTitle,
      trafficSource: extra.trafficSource,
      sourceDetail: extra.sourceDetail,
      autoOpenComments: extra.autoOpenComments,
      onPageChanged: extra.onPageChanged,
    );
  }
  if (extra is ProfilePooledFullscreenVideoFeedArgs) {
    return ProfileVideoFeedView(
      npub: '',
      userIdHex: extra.userIdHex,
      videoIndex: extra.initialIndex,
      videos: extra.seedVideos,
      initialVideoId: extra.initialVideoId,
      initialStableId: extra.initialStableId,
      contextTitleOverride: extra.contextTitle,
      onPageChanged: extra.onPageChanged ?? (_) {},
    );
  }
  return RouteErrorScreen(message: context.l10n.routeNoVideosToDisplay);
}
