// ABOUTME: Router-aware liked videos screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/likes/likes_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/liked_videos_state_bridge.dart';
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

    // Check if user is authenticated by checking if likes repository is available
    // This is safer than context.read<LikesBloc?>() which throws when no provider exists
    final likesRepository = ref.watch(likesRepositoryProvider);
    final isAuthenticated = likesRepository != null;

    // If not authenticated, show empty state
    if (!isAuthenticated) {
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

/// Feed view that uses BLoC state to display videos and syncs to Riverpod bridge
class _LikedVideosFeedView extends ConsumerStatefulWidget {
  const _LikedVideosFeedView({required this.videoIndex});

  final int videoIndex;

  @override
  ConsumerState<_LikedVideosFeedView> createState() =>
      _LikedVideosFeedViewState();
}

class _LikedVideosFeedViewState extends ConsumerState<_LikedVideosFeedView> {
  List<String>? _lastLoadedIds;

  @override
  void initState() {
    super.initState();
    // Trigger load when LikesBloc is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideosIfNeeded();
    });
  }

  @override
  void dispose() {
    // Reset bridge state when leaving the feed
    ref.read(likedVideosFeedStateProvider.notifier).state =
        const LikedVideosBridgeState.initial();
    super.dispose();
  }

  void _loadVideosIfNeeded() {
    if (!mounted) return;

    final likesState = context.read<LikesBloc>().state;
    if (likesState.isInitialized) {
      _triggerLoad(likesState.likedEventIds);
    }
  }

  void _triggerLoad(List<String> likedEventIds) {
    // Only reload if IDs changed
    if (_lastLoadedIds != null && _listEquals(_lastLoadedIds!, likedEventIds)) {
      return;
    }
    _lastLoadedIds = List.from(likedEventIds);
    context.read<ProfileLikedVideosBloc>().add(
      ProfileLikedVideosLoadRequested(likedEventIds: likedEventIds),
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Sync BLoC state to Riverpod bridge for activeVideoIdProvider
  void _syncToBridge(ProfileLikedVideosState state) {
    final isLoading =
        state.status == ProfileLikedVideosStatus.initial ||
        state.status == ProfileLikedVideosStatus.loading;

    ref.read(likedVideosFeedStateProvider.notifier).state =
        LikedVideosBridgeState(isLoading: isLoading, videos: state.videos);
  }

  /// Immediately filter bridge videos when liked IDs change.
  ///
  /// This ensures [activeVideoIdProvider] stays in sync without waiting
  /// for the BLoC to reload. Called before triggering the full BLoC reload.
  void _filterBridgeVideos(List<String> currentLikedIds) {
    final bridgeState = ref.read(likedVideosFeedStateProvider);
    if (bridgeState.videos.isEmpty) return;

    final likedIdSet = currentLikedIds.toSet();
    final filteredVideos = bridgeState.videos
        .where((v) => likedIdSet.contains(v.id))
        .toList();

    // Only update if something was actually filtered out
    if (filteredVideos.length != bridgeState.videos.length) {
      ref
          .read(likedVideosFeedStateProvider.notifier)
          .state = LikedVideosBridgeState(
        isLoading: bridgeState.isLoading,
        videos: filteredVideos,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LikesBloc, LikesState>(
      listenWhen: (prev, curr) =>
          prev.likedEventIds != curr.likedEventIds ||
          (!prev.isInitialized && curr.isInitialized),
      listener: (context, likesState) {
        if (likesState.isInitialized) {
          // Immediately filter bridge to keep activeVideoIdProvider in sync
          _filterBridgeVideos(likesState.likedEventIds);
          // Then trigger full BLoC reload
          _triggerLoad(likesState.likedEventIds);
        }
      },
      child: BlocConsumer<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        listener: (context, state) {
          // Sync BLoC state to Riverpod bridge whenever it changes
          _syncToBridge(state);
        },
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
