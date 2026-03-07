import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/providers/page_context_provider.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/screens/feed/feed_video_overlay.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_presentation.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class VideoFeedPage extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'home';

  /// Path for this route.
  static const path = '/home';

  /// Path for this route with index.
  static const pathWithIndex = '/home/:index';

  /// Build path for a specific index.
  static String pathForIndex(int index) => '/home/$index';

  const VideoFeedPage({this.initialMode = FeedMode.home, super.key});

  /// The feed mode to start with. Defaults to [FeedMode.home].
  final FeedMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosRepository = ref.watch(videosRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final curatedListRepository = ref.watch(curatedListRepositoryProvider);
    final authService = ref.watch(authServiceProvider);

    // Show loading until NostrClient has keys
    if (followRepository == null) {
      return const BrandedLoadingScaffold();
    }

    return BlocProvider(
      create: (_) => VideoFeedBloc(
        videosRepository: videosRepository,
        followRepository: followRepository,
        curatedListRepository: curatedListRepository,
        userPubkey: authService.currentPublicKeyHex,
        feedTracker: FeedPerformanceTracker(),
      )..add(VideoFeedStarted(mode: initialMode)),
      child: const VideoFeedView(),
    );
  }
}

@visibleForTesting
class VideoFeedView extends ConsumerStatefulWidget {
  const VideoFeedView({super.key, @visibleForTesting this.controller});

  /// Optional external [VideoFeedController] for testing.
  ///
  /// When provided, this controller is used instead of creating one
  /// internally. This allows tests to inject a mock/fake controller
  /// and verify that overlay visibility changes call [setActive].
  @visibleForTesting
  final VideoFeedController? controller;

  @override
  ConsumerState<VideoFeedView> createState() => _VideoFeedViewState();
}

class _VideoFeedViewState extends ConsumerState<VideoFeedView>
    with WidgetsBindingObserver {
  int? lastPrefetchIndex;

  /// Whether the home tab is currently active.
  ///
  /// Used to prevent overlay-close from resuming playback when the user
  /// has navigated away to another tab (e.g. Search).
  bool _isOnHomeTab = true;

  /// Guards so startup milestones fire only once.
  bool _hasMarkedUIReady = false;
  bool _hasMarkedVideoReady = false;

  /// The controller for the pooled video feed.
  ///
  /// Created lazily when videos first become available from the BLoC,
  /// or injected via [VideoFeedView.controller] for testing.
  VideoFeedController? controller;

  /// Tracks the last set of pooled videos to detect new additions.
  List<VideoItem>? lastPooledVideos;

  /// Tracks which feed mode the current controller was built for.
  FeedMode? controllerMode;

  /// Whether this state owns (and should dispose) the controller.
  bool get ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Use injected controller if provided (for testing)
    if (!ownsController) controller = widget.controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize controller eagerly if BLoC already has videos on first build
    handleVideoController();
  }

  @override
  void dispose() {
    if (ownsController) controller?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<VideoFeedBloc>().add(const VideoFeedAutoRefreshRequested());
    }
  }

  /// Handles the controller changes.
  ///
  /// Called from [didChangeDependencies] for eager setup and from
  /// [BlocListener] when videos arrive asynchronously.
  void handleVideoController([VideoFeedState? state]) {
    if (!ownsController) return;

    final effectiveState = state ?? context.read<VideoFeedBloc>().state;
    if (!effectiveState.isLoaded || effectiveState.videos.isEmpty) return;

    final pooledVideos = effectiveState.videos.toPooledVideoItems();

    if (controller != null &&
        controllerMode == effectiveState.mode &&
        lastPooledVideos != null &&
        _samePooledVideos(lastPooledVideos!, pooledVideos)) {
      return;
    }

    _resetVideoController();

    controller = VideoFeedController(
      videos: pooledVideos,
      pool: PlayerPool.instance,
      onVideoReady: (index, player) {
        if (!_hasMarkedVideoReady && index == 0) {
          _hasMarkedVideoReady = true;
          StartupPerformanceService.instance.markVideoReady();
        }
      },
    );

    controllerMode = effectiveState.mode;
    lastPooledVideos = pooledVideos;
  }

  /// Handles new videos from pagination by adding them to the controller.
  void handleVideosChanged(VideoFeedState state) {
    if (!ownsController) return;

    final pooledVideos = state.videos.toPooledVideoItems();

    if (controller == null || lastPooledVideos == null) {
      handleVideoController(state);
      return;
    }

    if (controllerMode != state.mode ||
        !_isAppendOnlyPooledUpdate(lastPooledVideos!, pooledVideos)) {
      handleVideoController(state);
      return;
    }

    final newVideos = pooledVideos.skip(lastPooledVideos!.length).toList();

    if (newVideos.isNotEmpty) controller?.addVideos(newVideos);

    lastPooledVideos = pooledVideos;
  }

  void _resetVideoController() {
    if (ownsController) {
      controller?.dispose();
      controller = null;
    }
    controllerMode = null;
    lastPooledVideos = null;
    lastPrefetchIndex = null;
  }

  bool _samePooledVideos(List<VideoItem> previous, List<VideoItem> current) {
    if (previous.length != current.length) return false;

    for (var i = 0; i < previous.length; i++) {
      if (previous[i].id != current[i].id ||
          previous[i].url != current[i].url) {
        return false;
      }
    }

    return true;
  }

  bool _isAppendOnlyPooledUpdate(
    List<VideoItem> previous,
    List<VideoItem> current,
  ) {
    if (current.length < previous.length) return false;

    for (var i = 0; i < previous.length; i++) {
      if (previous[i].id != current[i].id ||
          previous[i].url != current[i].url) {
        return false;
      }
    }

    return true;
  }

  void prefetchProfiles(List<VideoEvent> videos, int index) {
    if (index == lastPrefetchIndex) return;
    lastPrefetchIndex = index;

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
    // Pause/resume when navigating away from/back to home tab.
    // The home navigator's GlobalKey keeps this widget alive across
    // tab switches, so we must explicitly pause on tab change.
    ref.listen(pageContextProvider, (_, next) {
      final routeType = next.asData?.value.type;
      if (routeType == null) return;

      final isHome = routeType == RouteType.home;
      if (isHome == _isOnHomeTab) return;
      _isOnHomeTab = isHome;
      controller?.setActive(active: isHome);
    });

    // Pause/resume for overlays (drawer, modals), but only when on
    // the home tab. Without this guard, closing an overlay while on
    // another tab would incorrectly resume the home feed audio.
    ref.listen(hasVisibleOverlayProvider, (_, hasOverlay) {
      if (!_isOnHomeTab) return;
      controller?.setActive(active: !hasOverlay);
    });

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: MultiBlocListener(
        listeners: [
          // Reset controller when mode changes so a fresh one is
          // created for the new feed.
          BlocListener<VideoFeedBloc, VideoFeedState>(
            listenWhen: (previous, current) => previous.mode != current.mode,
            listener: (_, state) {
              _resetVideoController();
              handleVideoController(state);
            },
          ),
          // Initialize controller when videos first become available
          BlocListener<VideoFeedBloc, VideoFeedState>(
            listenWhen: (previous, current) =>
                !previous.isLoaded &&
                current.isLoaded &&
                current.videos.isNotEmpty,
            listener: (_, state) {
              handleVideoController(state);
              if (!_hasMarkedUIReady) {
                _hasMarkedUIReady = true;
                StartupPerformanceService.instance.markUIReady();
              }
            },
          ),
          // Handle new videos from pagination
          BlocListener<VideoFeedBloc, VideoFeedState>(
            listenWhen: (previous, current) =>
                previous.videos.length != current.videos.length,
            listener: (_, state) => handleVideosChanged(state),
          ),
        ],
        child: BlocBuilder<VideoFeedBloc, VideoFeedState>(
          builder: (context, state) {
            // Loading state (including initial state before first load)
            if (state.isLoading) {
              return const Center(child: BrandedLoadingIndicator());
            }

            // Error state
            if (state.status == VideoFeedStatus.failure) {
              return _FeedErrorWidget(error: state.error);
            }

            // Empty state
            if (state.isEmpty) {
              return Stack(
                children: [
                  FeedEmptyWidget(state: state),
                  const FeedModeSwitch(),
                ],
              );
            }

            // Wrap videos for pool compatibility
            final pooledVideos = state.videos.toPooledVideoItems();
            final eventsById = {
              for (final event in state.videos) event.id: event,
            };

            // Note: RefreshIndicator removed - it conflicts with PageView
            // scrolling and adds memory overhead. Use the refresh button
            // instead.
            return Stack(
              children: [
                PooledVideoFeed(
                  key: ValueKey(state.mode),
                  videos: pooledVideos,
                  controller: controller,
                  itemBuilder: (context, video, index, {required isActive}) {
                    final originalEvent = eventsById[video.id];
                    if (originalEvent == null) {
                      Log.debug(
                        'Feed item missing original event: '
                        'mode=${state.mode.name}, index=$index, '
                        'videoId=${video.id}, playbackUrl=${video.url}, '
                        'stateVideoCount=${state.videos.length}',
                        name: 'VideoFeedPage',
                        category: LogCategory.video,
                      );
                      return const ColoredBox(
                        color: VineTheme.backgroundColor,
                      );
                    }
                    Log.debug(
                      'Feed item build: mode=${state.mode.name}, index=$index, '
                      'eventId=${originalEvent.id}, isActive=$isActive, '
                      'playbackUrl=${video.url}, originalUrl=${originalEvent.videoUrl}, '
                      'thumbnailUrl=${originalEvent.thumbnailUrl}',
                      name: 'VideoFeedPage',
                      category: LogCategory.video,
                    );
                    final listSources =
                        state.listOnlyVideoIds.contains(originalEvent.id)
                        ? state.videoListSources[originalEvent.id]
                        : null;
                    return _PooledVideoFeedItem(
                      video: originalEvent,
                      index: index,
                      isActive: isActive,
                      contextTitle: state.mode.name,
                      listSources: listSources,
                    );
                  },
                  onActiveVideoChanged: (video, index) {
                    FeedPerformanceTracker().startVideoSwipeTracking(video.id);
                    final sourceIndex = state.videos.indexWhere(
                      (event) => event.id == video.id,
                    );
                    if (sourceIndex != -1) {
                      final event = state.videos[sourceIndex];
                      Log.info(
                        '📺 Feed active video: mode=${state.mode.name}, '
                        'index=$index, eventId=${event.id}, pubkey=${event.pubkey}, '
                        'playbackUrl=${video.url}, originalUrl=${event.videoUrl}, '
                        'thumbnailUrl=${event.thumbnailUrl}',
                        name: 'VideoFeedPage',
                        category: LogCategory.video,
                      );
                      prefetchProfiles(state.videos, sourceIndex);
                    }
                  },
                  onNearEnd: (index) {
                    // PooledVideoFeed fires this when the user is within
                    // nearEndThreshold (default 3) of the end, using the
                    // controller's actual video count (not the BlocBuilder's
                    // list length, which may differ due to deduplication).
                    if (state.hasMore) {
                      context.read<VideoFeedBloc>().add(
                        const VideoFeedLoadMoreRequested(),
                      );
                    }
                  },
                ),
                const FeedModeSwitch(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeedErrorWidget extends StatelessWidget {
  const _FeedErrorWidget({this.error});

  final VideoFeedError? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: VineTheme.error, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Failed to load videos',
            style: TextStyle(color: VineTheme.whiteText, fontSize: 18),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: VineTheme.lightText),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<VideoFeedBloc>().add(
              const VideoFeedRefreshRequested(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class FeedEmptyWidget extends StatelessWidget {
  const FeedEmptyWidget({required this.state, super.key});

  final VideoFeedState state;

  @override
  Widget build(BuildContext context) {
    final isNoFollowedUsers =
        state.mode == FeedMode.home &&
        state.error == VideoFeedError.noFollowedUsers;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            color: VineTheme.lightText,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(state),
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          if (isNoFollowedUsers) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go(ExploreScreen.path),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Videos'),
              style: FilledButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getEmptyMessage(VideoFeedState state) {
    if (state.mode == FeedMode.home &&
        state.error == VideoFeedError.noFollowedUsers) {
      return 'No followed users.\nFollow someone to see their videos here.';
    }
    return 'No videos found for ${state.mode.name} feed.';
  }
}

/// A video feed item that uses [PooledVideoPlayer] for playback.
///
/// This widget renders video content with automatic controller management
/// from the pool, plus the full overlay UI with author info, actions, etc.
class _PooledVideoFeedItem extends ConsumerWidget {
  const _PooledVideoFeedItem({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
    this.listSources,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;
  final Set<String>? listSources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

    // Build addressable ID for reposts if video has a d-tag (vineId)
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
              initialLikeCount: video.nostrLikeCount != null
                  ? video.totalLikes
                  : null,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: _PooledVideoFeedItemContent(
        video: video,
        index: index,
        isActive: isActive,
        contextTitle: contextTitle,
        listSources: listSources,
      ),
    );
  }
}

class _PooledVideoFeedItemContent extends StatelessWidget {
  const _PooledVideoFeedItemContent({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
    this.listSources,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;
  final Set<String>? listSources;

  @override
  Widget build(BuildContext context) {
    // All videos without dimensions are treated as portrait as its default
    // usecase (e.g. Reels-style vertical videos).
    final isPortrait = !(video.dimensions != null) || video.isPortrait;
    final alignment = videoAlignmentForDimensions(video.width, video.height);

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: PooledVideoPlayer(
        index: index,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: isActive,
        videoBuilder: (context, videoController, player) => _FittedVideoPlayer(
          videoController: videoController,
          isPortrait: isPortrait,
          alignment: alignment,
        ),
        loadingBuilder: (context) => _VideoLoadingPlaceholder(
          thumbnailUrl: video.thumbnailUrl,
          isPortrait: isPortrait,
          videoId: video.id,
          feedMode: contextTitle,
          index: index,
          alignment: alignment,
        ),
        overlayBuilder: (context, videoController, player) => FeedVideoOverlay(
          video: video,
          isActive: isActive,
          player: player,
          firstFrameFuture: videoController?.waitUntilFirstFrameRendered,
          listSources: listSources,
        ),
      ),
    );
  }
}

class _FittedVideoPlayer extends StatelessWidget {
  const _FittedVideoPlayer({
    required this.videoController,
    this.isPortrait = true,
    this.alignment = Alignment.center,
  });

  final VideoController videoController;
  final bool isPortrait;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    // Portrait: fill screen (cover), Landscape: fit entirely (contain)
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    return Video(
      controller: videoController,
      fit: boxFit,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      controls: null,
    );
  }
}

class _VideoLoadingPlaceholder extends StatefulWidget {
  const _VideoLoadingPlaceholder({
    required this.videoId,
    required this.index,
    this.feedMode,
    this.thumbnailUrl,
    this.isPortrait = true,
    this.alignment = Alignment.center,
  });

  final String videoId;
  final int index;
  final String? feedMode;
  final String? thumbnailUrl;
  final bool isPortrait;
  final Alignment alignment;

  @override
  State<_VideoLoadingPlaceholder> createState() =>
      _VideoLoadingPlaceholderState();
}

class _VideoLoadingPlaceholderState extends State<_VideoLoadingPlaceholder> {
  bool _loggedStart = false;
  bool _loggedLoaded = false;
  bool _loggedError = false;

  void _logStartIfNeeded() {
    if (_loggedStart) return;
    _loggedStart = true;
    Log.debug(
      'Feed thumbnail load_start: mode=${widget.feedMode ?? 'unknown'}, '
      'index=${widget.index}, eventId=${widget.videoId}, '
      'thumbnailUrl=${widget.thumbnailUrl}',
      name: 'VideoFeedPage',
      category: LogCategory.video,
    );
  }

  void _logLoadedIfNeeded() {
    if (_loggedLoaded) return;
    _loggedLoaded = true;
    Log.debug(
      'Feed thumbnail loaded: mode=${widget.feedMode ?? 'unknown'}, '
      'index=${widget.index}, eventId=${widget.videoId}, '
      'thumbnailUrl=${widget.thumbnailUrl}',
      name: 'VideoFeedPage',
      category: LogCategory.video,
    );
  }

  void _logErrorIfNeeded(Object error) {
    if (_loggedError) return;
    _loggedError = true;
    Log.warning(
      'Feed thumbnail load_failed: mode=${widget.feedMode ?? 'unknown'}, '
      'index=${widget.index}, eventId=${widget.videoId}, '
      'thumbnailUrl=${widget.thumbnailUrl}, error=$error',
      name: 'VideoFeedPage',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnailUrl == null) {
      if (!_loggedStart) {
        _loggedStart = true;
        Log.debug(
          'Feed thumbnail missing: mode=${widget.feedMode ?? 'unknown'}, '
          'index=${widget.index}, eventId=${widget.videoId}',
          name: 'VideoFeedPage',
          category: LogCategory.video,
        );
      }
      return const _LoadingIndicator();
    }

    // Portrait: fill height, crop sides (cover)
    // Landscape: fit entirely, centered (contain)
    final boxFit = widget.isPortrait ? BoxFit.cover : BoxFit.contain;
    _logStartIfNeeded();

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: SizedBox.expand(
        child: Image.network(
          widget.thumbnailUrl!,
          fit: boxFit,
          alignment: widget.alignment,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              _logLoadedIfNeeded();
            }
            return child;
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              _logLoadedIfNeeded();
              return child;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                child,
                const _LoadingIndicator(),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            _logErrorIfNeeded(error);
            return const _LoadingIndicator();
          },
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator(size: 60));
  }
}
