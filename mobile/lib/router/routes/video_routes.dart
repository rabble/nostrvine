// ABOUTME: Video routes (recorder, detail, sounds, editor, metadata, subtitle, fullscreen, engagement)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent;
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/fade_upwards_page.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/widgets/sound_detail_loader.dart';
import 'package:openvine/screens/creator_analytics_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/original_sound_detail_screen.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/subtitle_editor/subtitle_editor_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_engagement/video_engagement_list_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

List<RouteBase> videoRoutes() {
  return [
    GoRoute(
      path: VideoRecorderScreen.path,
      name: VideoRecorderScreen.routeName,
      // The recorder is a modal creation mode, not the next screen in a
      // flow — open it with the fade-upwards transition.
      pageBuilder: (_, state) => fadeUpwardsPage(
        state: state,
        child: const VideoRecorderRoute(),
      ),
    ),
    GoRoute(
      path: CreatorAnalyticsScreen.path,
      name: CreatorAnalyticsScreen.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => const CreatorAnalyticsScreen(),
    ),
    // Video detail route (for deep links)
    GoRoute(
      path: VideoDetailScreen.path,
      name: VideoDetailScreen.routeName,
      builder: (ctx, st) {
        final videoId = st.pathParameters['id'];
        if (videoId == null || videoId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
        }
        final extra = st.extra;
        final routeExtra = extra is VideoDetailRouteExtra ? extra : null;
        return VideoDetailScreen(
          videoId: videoId,
          autoOpenComments: routeExtra?.autoOpenComments ?? false,
          fallbackVideoIds: routeExtra?.fallbackVideoIds ?? const [],
          initialVideo: routeExtra?.initialVideo,
          dmReplyContext: routeExtra?.dmReplyContext,
        );
      },
    ),
    // Sound detail route (for audio reuse feature)
    GoRoute(
      path: SoundDetailScreen.path,
      name: SoundDetailScreen.routeName,
      builder: (ctx, st) {
        final soundId = st.pathParameters['id'];
        if (soundId == null || soundId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidSoundId);
        }
        // Extra can be an AudioEvent directly or a Map with both
        // sound and sourceVideo (for original sounds).
        final extra = st.extra;
        AudioEvent? sound;
        VideoEvent? sourceVideo;
        if (extra is AudioEvent) {
          sound = extra;
        } else if (extra is Map<String, dynamic>) {
          sound = extra['sound'] as AudioEvent?;
          sourceVideo = extra['sourceVideo'] as VideoEvent?;
        }
        if (sound != null) {
          return SoundDetailScreen(sound: sound, sourceVideo: sourceVideo);
        }
        // Wrap in a loader that fetches the sound by ID
        return SoundDetailLoader(soundId: soundId);
      },
    ),
    // Original sound detail route (for videos without shared audio)
    GoRoute(
      path: OriginalSoundDetailScreen.path,
      name: OriginalSoundDetailScreen.routeName,
      builder: (ctx, st) {
        final pubkey = st.pathParameters['pubkey'];
        final video = st.extra as VideoEvent?;
        if (pubkey == null || pubkey.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routerInvalidCreator);
        }
        return OriginalSoundDetailScreen(
          creatorPubkey: pubkey,
          sourceVideo: video,
        );
      },
    ),
    // Video editor route
    GoRoute(
      path: VideoEditorScreen.path,
      name: VideoEditorScreen.routeName,
      builder: (_, st) {
        final extra = st.extra as Map<String, dynamic>?;
        final fromLibrary = extra?['fromLibrary'] as bool? ?? false;

        return VideoEditorScreen(fromLibrary: fromLibrary);
      },
    ),
    GoRoute(
      path: VideoEditorScreen.draftPathWithId,
      name: VideoEditorScreen.draftRouteName,
      builder: (_, st) {
        // The draft ID is optional if the user wants to continue editing
        // the draft.
        final draftId = st.pathParameters['draftId'];
        final extra = st.extra as Map<String, dynamic>?;
        final fromLibrary = extra?['fromLibrary'] as bool? ?? false;

        return VideoEditorScreen(
          draftId: draftId == null || draftId.isEmpty ? null : draftId,
          fromLibrary: fromLibrary,
        );
      },
    ),
    GoRoute(
      path: VideoMetadataScreen.path,
      name: VideoMetadataScreen.routeName,
      builder: (_, st) => const VideoMetadataScreen(),
    ),
    GoRoute(
      path: '${VideoMetadataEditScreen.path}/:videoId',
      name: VideoMetadataEditScreen.routeName,
      builder: (ctx, st) {
        final videoId = st.pathParameters['videoId'];
        if (videoId == null || videoId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
        }
        final prefetched = st.extra as VideoEvent?;
        return VideoMetadataEditScreen(
          videoId: videoId,
          prefetched: prefetched,
        );
      },
    ),
    GoRoute(
      path: '${SubtitleEditorScreen.path}/:videoId',
      name: SubtitleEditorScreen.routeName,
      builder: (ctx, st) {
        final videoId = st.pathParameters['videoId'];
        if (videoId == null || videoId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidVideoId);
        }
        final prefetched = st.extra as VideoEvent?;
        return SubtitleEditorScreen(videoId: videoId, prefetched: prefetched);
      },
    ),
    // Fullscreen video feed.
    GoRoute(
      path: PooledFullscreenVideoFeedScreen.path,
      name: PooledFullscreenVideoFeedScreen.routeName,
      redirect: (context, state) => fullscreenFeedRedirect(state.extra),
      builder: buildPooledFullscreenFeed,
    ),
    // Engagement lists for own videos: who liked / reposted this video.
    // Reached when the video owner taps the Like or Repost button on
    // their own video.
    GoRoute(
      path: '/video/:eventId/likers',
      name: VideoEngagementListScreen.likersRouteName,
      builder: (ctx, st) {
        final eventId = st.pathParameters['eventId'];
        if (eventId == null || eventId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeNoVideosToDisplay);
        }
        final addressableId = st.uri.queryParameters['a'];
        return VideoEngagementListScreen(
          eventId: eventId,
          type: VideoEngagementType.likers,
          addressableId: addressableId,
        );
      },
    ),
    GoRoute(
      path: '/video/:eventId/reposters',
      name: VideoEngagementListScreen.repostersRouteName,
      builder: (ctx, st) {
        final eventId = st.pathParameters['eventId'];
        if (eventId == null || eventId.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeNoVideosToDisplay);
        }
        final addressableId = st.uri.queryParameters['a'];
        return VideoEngagementListScreen(
          eventId: eventId,
          type: VideoEngagementType.reposters,
          addressableId: addressableId,
        );
      },
    ),
  ];
}
