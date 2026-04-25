// ABOUTME: Router-aware liked videos screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';
import 'package:unified_logger/unified_logger.dart';

/// Router-aware liked videos screen that shows grid or feed based on route
class LikedVideosScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'liked-videos';

  /// Path for this route.
  static const path = '/liked-videos';

  /// Path for this route with index.
  static const pathWithIndex = '/liked-videos/:index';

  /// Build path for grid mode or specific index.
  static String pathForIndex(int? index) =>
      index == null ? path : '/liked-videos/$index';

  const LikedVideosScreenRouter({super.key});

  @override
  ConsumerState<LikedVideosScreenRouter> createState() =>
      _LikedVideosScreenRouterState();
}

class _LikedVideosScreenRouterState
    extends ConsumerState<LikedVideosScreenRouter> {
  @override
  Widget build(BuildContext context) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;

    if (routeCtx == null || routeCtx.type != RouteType.likedVideos) {
      Log.warning(
        'LikedVideosScreenRouter: Invalid route context',
        name: 'LikedVideosRouter',
        category: LogCategory.ui,
      );
      return const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
          child: Text(
            'Invalid route',
            style: TextStyle(color: VineTheme.whiteText),
          ),
        ),
      );
    }

    // Get services for ProfileLikedVideosBloc
    final likesRepository = ref.watch(likesRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final videoIndex = routeCtx.videoIndex;

    // Grid mode: no video index
    if (videoIndex == null) {
      Log.info(
        'LikedVideosScreenRouter: Showing grid',
        name: 'LikedVideosRouter',
        category: LogCategory.ui,
      );
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: DiVineAppBar(
          title: 'Liked Videos',
          showBackButton: true,
          backgroundColor: VineTheme.backgroundColor,
          onBackPressed: () {
            // Navigate to own profile grid
            final authService = ref.read(authServiceProvider);
            final currentUserHex = authService.currentPublicKeyHex;
            if (currentUserHex != null) {
              final npub = NostrKeyUtils.encodePubKey(currentUserHex);
              context.go(ProfileScreenRouter.pathForNpub(npub));
            }
          },
        ),
        body: BlocProvider<ProfileLikedVideosBloc>(
          create: (_) => ProfileLikedVideosBloc(
            likesRepository: likesRepository,
            videosRepository: videosRepository,
            currentUserPubkey: currentUserPubkey,
          )..add(const ProfileLikedVideosSyncRequested()),
          child: const ProfileLikedGrid(isOwnProfile: true),
        ),
      );
    }

    // Feed mode: show video at specific index
    Log.info(
      'LikedVideosScreenRouter: Showing feed (index=$videoIndex)',
      name: 'LikedVideosRouter',
      category: LogCategory.ui,
    );

    return BlocProvider<ProfileLikedVideosBloc>(
      create: (_) => ProfileLikedVideosBloc(
        likesRepository: likesRepository,
        videosRepository: videosRepository,
        currentUserPubkey: currentUserPubkey,
      )..add(const ProfileLikedVideosSyncRequested()),
      child: _LikedVideosFeedView(videoIndex: videoIndex),
    );
  }
}

/// Feed view that streams BLoC state into [PooledFullscreenVideoFeedScreen].
class _LikedVideosFeedView extends ConsumerStatefulWidget {
  const _LikedVideosFeedView({required this.videoIndex});

  final int videoIndex;

  @override
  ConsumerState<_LikedVideosFeedView> createState() =>
      _LikedVideosFeedViewState();
}

class _LikedVideosFeedViewState extends ConsumerState<_LikedVideosFeedView> {
  late final StreamController<List<VideoEvent>> _streamController;
  List<VideoEvent>? _lastVideos;

  @override
  void initState() {
    super.initState();
    _streamController = StreamController<List<VideoEvent>>.broadcast();
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  /// Push the latest non-empty video list into the stream.
  void _pushVideos(List<VideoEvent> videos) {
    if (videos.isEmpty) return;
    if (identical(videos, _lastVideos)) return;
    _lastVideos = videos;
    if (!_streamController.isClosed) _streamController.add(videos);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      listener: (context, state) {
        _pushVideos(state.videos);
      },
      builder: (context, state) {
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
            state.status == ProfileLikedVideosStatus.loading) {
          return const Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          );
        }

        if (state.status == ProfileLikedVideosStatus.failure) {
          return const Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            body: Center(
              child: Text(
                'Error loading liked videos',
                style: TextStyle(color: VineTheme.whiteText),
              ),
            ),
          );
        }

        final videos = state.videos;

        if (videos.isEmpty) {
          return const Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            body: Center(
              child: Text(
                'No liked videos',
                style: TextStyle(color: VineTheme.whiteText),
              ),
            ),
          );
        }

        ScreenAnalyticsService().markDataLoaded(
          'liked_videos',
          dataMetrics: {'video_count': videos.length},
        );

        final safeIndex = widget.videoIndex.clamp(0, videos.length - 1);

        return PooledFullscreenVideoFeedScreen(
          // Stream is seeded via _pushVideos in the BlocConsumer listener.
          videosStream: _streamController.stream,
          initialIndex: safeIndex,
          removedIdsStream: ref.read(videoEventServiceProvider).removedVideoIds,
          contextTitle: 'Liked Videos',
          trafficSource: ViewTrafficSource.profile,
        );
      },
    );
  }
}
