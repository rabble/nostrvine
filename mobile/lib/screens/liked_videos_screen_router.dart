// ABOUTME: Router-aware liked videos screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/liked_videos_state_bridge.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';

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
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Invalid route', style: TextStyle(color: Colors.white)),
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
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'Liked Videos',
            style: TextStyle(color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Navigate to own profile grid
              final authService = ref.read(authServiceProvider);
              final currentUserHex = authService.currentPublicKeyHex;
              if (currentUserHex != null) {
                final npub = NostrKeyUtils.encodePubKey(currentUserHex);
                context.go(ProfileScreenRouter.pathForNpub(npub));
              }
            },
          ),
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

/// Feed view that uses BLoC state to display videos and syncs to Riverpod bridge
class _LikedVideosFeedView extends ConsumerStatefulWidget {
  const _LikedVideosFeedView({required this.videoIndex});

  final int videoIndex;

  @override
  ConsumerState<_LikedVideosFeedView> createState() =>
      _LikedVideosFeedViewState();
}

class _LikedVideosFeedViewState extends ConsumerState<_LikedVideosFeedView> {
  @override
  void dispose() {
    // Reset bridge state when leaving the feed
    ref.read(likedVideosFeedStateProvider.notifier).state =
        const LikedVideosBridgeState.initial();
    super.dispose();
  }

  /// Sync BLoC state to Riverpod bridge for activeVideoIdProvider
  void _syncToBridge(ProfileLikedVideosState state) {
    final isLoading =
        state.status == ProfileLikedVideosStatus.initial ||
        state.status == ProfileLikedVideosStatus.syncing ||
        state.status == ProfileLikedVideosStatus.loading;

    ref.read(likedVideosFeedStateProvider.notifier).state =
        LikedVideosBridgeState(isLoading: isLoading, videos: state.videos);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      listener: (context, state) {
        // Sync BLoC state to Riverpod bridge whenever it changes
        _syncToBridge(state);
      },
      builder: (context, state) {
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
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
          onNavigate: (index) =>
              context.go(LikedVideosScreenRouter.pathForIndex(index)),
        );
      },
    );
  }
}
