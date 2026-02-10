// ABOUTME: Router-driven HomeScreen using pooled_video_player
// ABOUTME: Bridges homeFeedProvider (Riverpod) to FullscreenFeedBloc for playback
// ABOUTME: Uses PooledVideoFeed for managed player pool and preloading

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/home_screen_controllers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Router-driven HomeScreen using pooled video player.
///
/// Bridges [homeFeedProvider] (Riverpod data source) to
/// [FullscreenFeedBloc] (playback management) via a stream.
class HomeScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'home';

  /// Path for this route.
  static const path = '/home';

  /// Path for this route with index.
  static const pathWithIndex = '/home/:index';

  /// Build path for a specific index.
  static String pathForIndex(int index) => '/home/$index';

  const HomeScreenRouter({super.key});

  @override
  ConsumerState<HomeScreenRouter> createState() => _HomeScreenRouterState();
}

class _HomeScreenRouterState extends ConsumerState<HomeScreenRouter> {
  late final StreamController<List<VideoEvent>> _videosController;

  @override
  void initState() {
    super.initState();
    _videosController = StreamController<List<VideoEvent>>();

    // Seed stream with current videos if available
    final state = ref.read(homeFeedProvider).asData?.value;
    if (state != null && state.videos.isNotEmpty) {
      _videosController.add(state.videos);
    }
  }

  @override
  void dispose() {
    _videosController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bridge: push homeFeedProvider updates into the BLoC's stream
    ref.listen<AsyncValue<VideoFeedState>>(homeFeedProvider, (_, next) {
      final state = next.asData?.value;
      if (state != null) {
        _videosController.add(state.videos);
      }
    });

    return BlocProvider(
      create: (_) => FullscreenFeedBloc(
        videosStream: _videosController.stream,
        initialIndex:
            ref.read(pageContextProvider).asData?.value?.videoIndex ?? 0,
        onLoadMore: () =>
            ref.read(homePaginationControllerProvider).maybeLoadMore(),
        mediaCache: ref.read(mediaCacheProvider),
        blossomAuthService: ref.read(blossomAuthServiceProvider),
      )..add(const FullscreenFeedStarted()),
      child: const _HomeScreenView(),
    );
  }
}

/// View widget that handles route checking, loading/empty states,
/// and renders the [_HomeFeedContent] when videos are available.
class _HomeScreenView extends ConsumerWidget {
  const _HomeScreenView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageContext = ref.watch(pageContextProvider);
    final ctx = pageContext.asData?.value;

    if (ctx == null || ctx.type != RouteType.home) {
      return const SizedBox.shrink();
    }

    final feedState = ref.watch(homeFeedProvider).asData?.value;

    // Initial loading (no data yet)
    if (feedState == null ||
        (feedState.lastUpdated == null && feedState.videos.isEmpty)) {
      return const Center(child: BrandedLoadingIndicator(size: 80));
    }

    // Empty state
    if (feedState.videos.isEmpty) {
      return const _EmptyHomeFeed();
    }

    ScreenAnalyticsService().markDataLoaded(
      'home_feed',
      dataMetrics: {'video_count': feedState.videos.length},
    );

    return _HomeFeedContent(
      urlIndex: (ctx.videoIndex ?? 0).clamp(0, feedState.videos.length - 1),
      videoListSources: feedState.videoListSources,
      listOnlyVideoIds: feedState.listOnlyVideoIds,
    );
  }
}

/// Content widget that manages [VideoFeedController] and renders
/// [PooledVideoFeed].
///
/// Follows the same pattern as [FullscreenFeedContent] from
/// `pooled_fullscreen_video_feed_screen.dart`.
class _HomeFeedContent extends ConsumerStatefulWidget {
  const _HomeFeedContent({
    required this.urlIndex,
    required this.videoListSources,
    required this.listOnlyVideoIds,
  });

  final int urlIndex;
  final Map<String, Set<String>> videoListSources;
  final Set<String> listOnlyVideoIds;

  @override
  ConsumerState<_HomeFeedContent> createState() => _HomeFeedContentState();
}

class _HomeFeedContentState extends ConsumerState<_HomeFeedContent> {
  VideoFeedController? _controller;
  List<VideoItem>? _lastPooledVideos;
  int? _lastPrefetchIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeControllerIfNeeded();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializeControllerIfNeeded({bool triggerRebuild = false}) {
    if (_controller != null) return;

    final state = context.read<FullscreenFeedBloc>().state;
    if (!state.hasPooledVideos) return;

    _controller = _createController(state.pooledVideos, state.currentIndex);
    _lastPooledVideos = state.pooledVideos;

    if (triggerRebuild) setState(() {});
  }

  void _handleVideosChanged(FullscreenFeedState state) {
    final controller = _controller;
    if (controller == null || _lastPooledVideos == null) return;

    final newVideos = state.pooledVideos
        .where((v) => !_lastPooledVideos!.any((old) => old.id == v.id))
        .toList();

    if (newVideos.isNotEmpty) {
      controller.addVideos(newVideos);
    }
    _lastPooledVideos = state.pooledVideos;
  }

  void _handleSeekCommand(SeekCommand command) {
    final controller = _controller;
    if (controller == null) return;

    controller.seek(command.position);
    context.read<FullscreenFeedBloc>().add(
      const FullscreenFeedSeekCommandHandled(),
    );
  }

  VideoFeedController _createController(
    List<VideoItem> videos,
    int initialIndex,
  ) {
    return VideoFeedController(
      videos: videos,
      pool: PlayerPool.instance,
      initialIndex: initialIndex,
      onVideoReady: (index, player) {
        if (!mounted) return;
        context.read<FullscreenFeedBloc>().add(
          FullscreenFeedVideoCacheStarted(index: index),
        );
      },
      positionCallback: (index, position) {
        if (!mounted) return;
        context.read<FullscreenFeedBloc>().add(
          FullscreenFeedPositionUpdated(index: index, position: position),
        );
      },
      positionCallbackInterval: const Duration(milliseconds: 100),
    );
  }

  /// Prefetch user profiles for adjacent videos.
  void _prefetchProfiles(int index, List<VideoEvent> videos) {
    if (index == _lastPrefetchIndex) return;
    _lastPrefetchIndex = index;

    final safeIndex = index.clamp(0, videos.length - 1);
    final pubkeys = <String>[];

    if (safeIndex > 0) {
      pubkeys.add(videos[safeIndex - 1].pubkey);
    }
    if (safeIndex < videos.length - 1) {
      pubkeys.add(videos[safeIndex + 1].pubkey);
    }

    if (pubkeys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(userProfileProvider.notifier)
            .prefetchProfilesImmediately(pubkeys);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pause/resume based on overlay visibility
    final hasOverlay = ref.watch(hasVisibleOverlayProvider);
    _controller?.setActive(active: !hasOverlay);

    return MultiBlocListener(
      listeners: [
        // Initialize controller when videos first become available
        BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
          listenWhen: (prev, curr) =>
              !prev.hasPooledVideos && curr.hasPooledVideos,
          listener: (context, state) =>
              _initializeControllerIfNeeded(triggerRebuild: true),
        ),
        // Handle new videos from pagination
        BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
          listenWhen: (prev, curr) => prev.videos.length != curr.videos.length,
          listener: (context, state) => _handleVideosChanged(state),
        ),
        // Handle seek commands (loop enforcement)
        BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
          listenWhen: (prev, curr) =>
              curr.seekCommand != null && prev.seekCommand != curr.seekCommand,
          listener: (context, state) {
            final command = state.seekCommand;
            if (command != null) {
              _handleSeekCommand(command);
            }
          },
        ),
      ],
      child: BlocBuilder<FullscreenFeedBloc, FullscreenFeedState>(
        builder: (context, state) {
          if (!state.hasPooledVideos) {
            return const Center(child: BrandedLoadingIndicator(size: 80));
          }

          return RefreshIndicator(
            color: VineTheme.onPrimary,
            backgroundColor: VineTheme.vineGreen,
            semanticsLabel: 'searching for more videos',
            onRefresh: () => ref.read(homeRefreshControllerProvider).refresh(),
            child: PooledVideoFeed(
              key: const Key('home-video-page-view'),
              videos: state.pooledVideos,
              controller: _controller,
              initialIndex: state.currentIndex,
              onActiveVideoChanged: (video, index) {
                // Update BLoC index
                context.read<FullscreenFeedBloc>().add(
                  FullscreenFeedIndexChanged(index),
                );

                // Update URL for router integration
                if (index != widget.urlIndex) {
                  context.go(HomeScreenRouter.pathForIndex(index));
                }

                // Trigger pagination near end
                if (index >= state.videos.length - 2) {
                  ref.read(homePaginationControllerProvider).maybeLoadMore();
                }

                // Prefetch profiles for adjacent videos
                _prefetchProfiles(index, state.videos);

                Log.debug(
                  'Page changed to index $index '
                  '(${state.videos[index].id})',
                  name: 'HomeScreenRouter',
                  category: LogCategory.video,
                );
              },
              onNearEnd: (_) {
                ref.read(homePaginationControllerProvider).maybeLoadMore();
              },
              nearEndThreshold: 2,
              itemBuilder: (context, video, index, {required isActive}) {
                final originalEvent = state.videos[index];
                final listSources = widget.videoListSources[originalEvent.id];

                return _PooledHomeFeedItem(
                  video: originalEvent,
                  index: index,
                  isActive: isActive,
                  hideFollowButtonIfFollowing: true,
                  listSources: listSources,
                  showListAttribution:
                      listSources != null && listSources.isNotEmpty,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PooledHomeFeedItem extends ConsumerWidget {
  const _PooledHomeFeedItem({
    required this.video,
    required this.index,
    required this.isActive,
    this.hideFollowButtonIfFollowing = false,
    this.listSources,
    this.showListAttribution = false,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool hideFollowButtonIfFollowing;
  final Set<String>? listSources;
  final bool showListAttribution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

    final addressableId = video.addressableId;

    return BlocProvider<VideoInteractionsBloc>(
      create: (_) =>
          VideoInteractionsBloc(
              eventId: video.id,
              authorPubkey: video.pubkey,
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
              addressableId: addressableId,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: _PooledHomeFeedItemContent(
        video: video,
        index: index,
        isActive: isActive,
        hideFollowButtonIfFollowing: hideFollowButtonIfFollowing,
        listSources: listSources,
        showListAttribution: showListAttribution,
      ),
    );
  }
}

class _PooledHomeFeedItemContent extends StatelessWidget {
  const _PooledHomeFeedItemContent({
    required this.video,
    required this.index,
    required this.isActive,
    this.hideFollowButtonIfFollowing = false,
    this.listSources,
    this.showListAttribution = false,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool hideFollowButtonIfFollowing;
  final Set<String>? listSources;
  final bool showListAttribution;

  @override
  Widget build(BuildContext context) {
    final isPortrait = video.dimensions != null ? video.isPortrait : true;

    return ColoredBox(
      color: Colors.black,
      child: PooledVideoPlayer(
        index: index,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: isActive,
        videoBuilder: (context, videoController, player) => _FittedVideoPlayer(
          videoController: videoController,
          isPortrait: isPortrait,
        ),
        loadingBuilder: (context) => _VideoLoadingPlaceholder(
          thumbnailUrl: video.thumbnailUrl,
          isPortrait: isPortrait,
        ),
        overlayBuilder: (context, videoController, player) =>
            VideoOverlayActions(
              video: video,
              isVisible: isActive,
              isActive: isActive,
              hasBottomNavigation: false,
              contextTitle: '',
              hideFollowButtonIfFollowing: hideFollowButtonIfFollowing,
              listSources: listSources,
              showListAttribution: showListAttribution,
            ),
      ),
    );
  }
}

class _FittedVideoPlayer extends StatelessWidget {
  const _FittedVideoPlayer({
    required this.videoController,
    this.isPortrait = true,
  });

  final VideoController videoController;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    return Video(
      controller: videoController,
      fit: boxFit,
      filterQuality: FilterQuality.high,
      controls: NoVideoControls,
    );
  }
}

class _VideoLoadingPlaceholder extends StatelessWidget {
  const _VideoLoadingPlaceholder({this.thumbnailUrl, this.isPortrait = true});

  final String? thumbnailUrl;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;
    final url = thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: boxFit,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        const Center(child: BrandedLoadingIndicator(size: 60)),
      ],
    );
  }
}

class _EmptyHomeFeed extends StatelessWidget {
  const _EmptyHomeFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: VineTheme.secondaryText,
            ),
            const SizedBox(height: 24),
            Text(
              'Your Home Feed is Empty',
              style: TextStyle(
                fontSize: 22,
                color: VineTheme.whiteText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Follow creators to see their videos here',
              style: TextStyle(fontSize: 16, color: VineTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(ExploreScreen.path),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Videos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
