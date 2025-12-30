// ABOUTME: Router-aware liked videos screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/likes/likes_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';

/// Router-aware liked videos screen that shows grid or feed based on route
class LikedVideosScreenRouter extends ConsumerStatefulWidget {
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
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Invalid route', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    // Get services for ProfileLikedVideosBloc
    final videoEventService = ref.watch(videoEventServiceProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    // Check if LikesBloc is available (provided at app level when authenticated)
    final hasLikesBloc = context.read<LikesBloc?>() != null;

    // If not authenticated, show empty state
    if (!hasLikesBloc) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Please sign in to view liked videos',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final videoIndex = routeCtx.videoIndex;

    // Grid mode: no video index
    if (videoIndex == null) {
      Log.info(
        'LikedVideosScreenRouter: Showing grid',
        name: 'LikedVideosRouter',
        category: LogCategory.ui,
      );
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Liked Videos',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.goMyProfile(),
          ),
        ),
        // LikesBloc is provided at app level, only provide ProfileLikedVideosBloc here
        body: BlocProvider<ProfileLikedVideosBloc>(
          create: (_) => ProfileLikedVideosBloc(
            videoEventService: videoEventService,
            nostrClient: nostrClient,
          ),
          child: const ProfileLikedGrid(),
        ),
      );
    }

    // Feed mode: show video at specific index
    Log.info(
      'LikedVideosScreenRouter: Showing feed (index=$videoIndex)',
      name: 'LikedVideosRouter',
      category: LogCategory.ui,
    );

    // For feed mode, we need ProfileLikedVideosBloc to get the videos
    // LikesBloc is provided at app level
    return BlocProvider<ProfileLikedVideosBloc>(
      create: (_) => ProfileLikedVideosBloc(
        videoEventService: videoEventService,
        nostrClient: nostrClient,
      ),
      child: _LikedVideosFeedView(videoIndex: videoIndex),
    );
  }
}

/// Feed view that uses BLoC state to display videos
class _LikedVideosFeedView extends StatefulWidget {
  const _LikedVideosFeedView({required this.videoIndex});

  final int videoIndex;

  @override
  State<_LikedVideosFeedView> createState() => _LikedVideosFeedViewState();
}

class _LikedVideosFeedViewState extends State<_LikedVideosFeedView> {
  @override
  void initState() {
    super.initState();
    // Trigger load when LikesBloc is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideosIfNeeded();
    });
  }

  void _loadVideosIfNeeded() {
    if (!mounted) return;

    final likesState = context.read<LikesBloc>().state;
    if (likesState.isInitialized) {
      context.read<ProfileLikedVideosBloc>().add(
        ProfileLikedVideosLoadRequested(
          likedEventIds: likesState.likedEventIds,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LikesBloc, LikesState>(
      listenWhen: (prev, curr) => !prev.isInitialized && curr.isInitialized,
      listener: (context, likesState) {
        context.read<ProfileLikedVideosBloc>().add(
          ProfileLikedVideosLoadRequested(
            likedEventIds: likesState.likedEventIds,
          ),
        );
      },
      child: BlocBuilder<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        builder: (context, state) {
          if (state.status == ProfileLikedVideosStatus.initial ||
              state.status == ProfileLikedVideosStatus.loading) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
            );
          }

          if (state.status == ProfileLikedVideosStatus.failure) {
            return const Scaffold(
              backgroundColor: Colors.black,
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
              backgroundColor: Colors.black,
              body: Center(
                child: Text(
                  'No liked videos',
                  style: TextStyle(color: VineTheme.whiteText),
                ),
              ),
            );
          }

          // Determine target index from route context
          final safeIndex = widget.videoIndex.clamp(0, videos.length - 1);

          // Feed mode - show fullscreen video player
          return ExploreVideoScreenPure(
            startingVideo: videos[safeIndex],
            videoList: videos,
            contextTitle: 'Liked Videos',
            startingIndex: safeIndex,
            onNavigate: (index) => context.goLikedVideos(index),
          );
        },
      ),
    );
  }
}
