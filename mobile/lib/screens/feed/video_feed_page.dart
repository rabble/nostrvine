import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/screens/feed/feed_video_overlay.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/utils/pooled_player_logger.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/web_video_feed.dart';
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

  const VideoFeedPage({this.initialMode = FeedMode.forYou, super.key});

  /// The feed mode to start with. Defaults to [FeedMode.forYou].
  final FeedMode initialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(divineHostFilterVersionProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final followRepository = ref.watch(followRepositoryProvider);
    final curatedListRepository = ref.watch(curatedListRepositoryProvider);
    final profileRepository = ref.watch(profileRepositoryProvider);
    final authService = ref.watch(authServiceProvider);
    final sharedPreferences = ref.watch(sharedPreferencesProvider);
    final showDivineHostedOnly = ref
        .read(divineHostFilterServiceProvider)
        .showDivineHostedOnly;

    final blocklistService = ref.watch(contentBlocklistServiceProvider);

    return MultiBlocProvider(
      key: ValueKey('video-feed-$showDivineHostedOnly'),
      providers: [
        BlocProvider(
          create: (_) => VideoFeedBloc(
            videosRepository: videosRepository,
            followRepository: followRepository,
            curatedListRepository: curatedListRepository,
            profileRepository: profileRepository,
            contentBlocklistService: blocklistService,
            userPubkey: authService.currentPublicKeyHex,
            sharedPreferences: sharedPreferences,
            serveCachedHomeFeed: !showDivineHostedOnly,
            feedTracker: FeedPerformanceTracker(),
          )..add(VideoFeedStarted(mode: initialMode)),
        ),
        BlocProvider(create: (_) => VideoPlaybackStatusCubit()),
      ],
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

  /// Key for accessing the rendered pooled feed state for programmatic skips.
  final _feedKey = GlobalKey<PooledVideoFeedState>();

  /// Tracks the current fractional page position for scroll-driven overlay opacity.
  late final ValueNotifier<double> _pagePosition;

  /// Tracks the last set of pooled videos to detect new additions.
  List<VideoItem>? lastPooledVideos;

  /// Tracks which feed mode the current controller was built for.
  FeedMode? controllerMode;

  /// Whether this state owns (and should dispose) the controller.
  bool get ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _pagePosition = ValueNotifier<double>(0);
    WidgetsBinding.instance.addObserver(this);
    // Use injected controller if provided (for testing)
    if (!ownsController) controller = widget.controller;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize controller eagerly if BLoC already has videos on first build
    handleVideoController();
    _syncControllerPlaybackState();
  }

  @override
  void dispose() {
    if (ownsController) controller?.dispose();
    _pagePosition.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<VideoFeedBloc>().add(const VideoFeedAutoRefreshRequested());
    }
  }

  void _skipToNextVideoIfPossible() {
    final feedState = _feedKey.currentState;
    if (feedState == null) return;

    final nextIndex = feedState.controller.currentIndex + 1;
    if (nextIndex >= feedState.controller.videoCount) return;

    unawaited(feedState.animateToPage(nextIndex));
  }

  /// Handles the controller changes.
  ///
  /// Called from [didChangeDependencies] for eager setup and from
  /// [BlocListener] when videos arrive asynchronously.
  void handleVideoController([VideoFeedState? state]) {
    if (kIsWeb) return; // Skip media_kit controller on web
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
      maxLoopDuration: VideoEditorConstants.maxDuration,
      onVideoReady: (index, player) {
        if (!_hasMarkedVideoReady && index == 0) {
          _hasMarkedVideoReady = true;
          StartupPerformanceService.instance.markVideoReady();
        }
      },
      onVideoStalled: (index) {
        if (!mounted) return;
        _skipToNextVideoIfPossible();
      },
      onLog: pooledPlayerLogCallback(),
    );

    controllerMode = effectiveState.mode;
    lastPooledVideos = pooledVideos;

    // If an overlay is open or we're not on the home tab, deactivate
    // immediately so the video doesn't start playing in the background.
    final overlayState = ref.read(overlayVisibilityProvider);
    if (!_isOnHomeTab || overlayState.hasVisibleOverlay) {
      controller?.setActive(
        active: false,
        retainCurrentPlayer: overlayState.shouldRetainPlayer,
      );
      return;
    }

    _syncControllerPlaybackState(resumeIfHome: true);
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

  void _syncControllerPlaybackState({bool resumeIfHome = false}) {
    final activeController = controller;
    if (activeController == null) return;

    final routeType = ref.read(pageContextProvider).asData?.value.type;
    if (routeType != null) {
      _isOnHomeTab = routeType == RouteType.home;
    }

    final overlayState = ref.read(overlayVisibilityProvider);
    if (!_isOnHomeTab || overlayState.hasVisibleOverlay) {
      activeController.setActive(
        active: false,
        retainCurrentPlayer: overlayState.shouldRetainPlayer,
      );
      return;
    }

    if (resumeIfHome) {
      activeController.setActive(active: true);
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

      // Don't resume when GoRouter falsely reports "home" while a pushed
      // overlay (e.g. video recorder) is still open. This happens because
      // GoRouter's routeInformationProvider can emit the shell-route
      // location when popping between pushed routes (recorder → editor →
      // pop back to recorder). The overlay listener handles resume when
      // the overlay actually closes.
      if (isHome && ref.read(overlayVisibilityProvider).hasVisibleOverlay) {
        return;
      }

      controller?.setActive(active: isHome);
    });

    // Refresh feed when blocklist changes (block from profile, DM, or relay).
    ref.listen(blocklistVersionProvider, (previous, current) {
      if (previous != null && current > previous) {
        context.read<VideoFeedBloc>().add(const VideoFeedBlocklistChanged());
      }
    });

    // Pause/resume for overlays (drawer, pages, bottom sheets), but only when
    // on the home tab. Without this guard, closing an overlay while on
    // another tab would incorrectly resume the home feed audio.
    //
    // Bottom sheets retain the current player for instant resume.
    // Pages/drawer release all players to free memory.
    ref.listen(overlayVisibilityProvider, (previous, current) {
      if (!_isOnHomeTab) return;

      final hadOverlay = previous?.hasVisibleOverlay ?? false;
      final hasOverlay = current.hasVisibleOverlay;

      if (hasOverlay && !hadOverlay) {
        // Overlay opened - pause with retention based on overlay type
        controller?.setActive(
          active: false,
          retainCurrentPlayer: current.shouldRetainPlayer,
        );
      } else if (!hasOverlay && hadOverlay) {
        // All overlays closed - resume playback
        controller?.setActive(active: true);
      }
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
              _pagePosition.value = 0;
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
                if (kIsWeb)
                  WebVideoFeed(
                    videos: state.videos
                        .where((v) => v.videoUrl != null)
                        .toList(),
                    onNearEnd: (index) {
                      if (state.hasMore) {
                        context.read<VideoFeedBloc>().add(
                          const VideoFeedLoadMoreRequested(),
                        );
                      }
                    },
                  )
                else
                  KeyedSubtree(
                    key: ValueKey(state.mode),
                    child: PooledVideoFeed(
                      key: _feedKey,
                      videos: pooledVideos,
                      maxLoopDuration: VideoEditorConstants.maxDuration,
                      controller: controller,
                      onScrollOffsetChanged: (page) =>
                          _pagePosition.value = page,
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
                          pagePosition: _pagePosition,
                          contextTitle: state.mode.name,
                          listSources: listSources,
                        );
                      },
                      onActiveVideoChanged: (video, index) {
                        FeedPerformanceTracker().startVideoSwipeTracking(
                          video.id,
                        );
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
        state.mode == FeedMode.following &&
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
    if (state.mode == FeedMode.following &&
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
    required this.pagePosition,
    this.contextTitle,
    this.listSources,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final ValueNotifier<double> pagePosition;
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
        pagePosition: pagePosition,
        contextTitle: contextTitle,
        listSources: listSources,
      ),
    );
  }
}

class _PooledVideoFeedItemContent extends StatefulWidget {
  const _PooledVideoFeedItemContent({
    required this.video,
    required this.index,
    required this.isActive,
    required this.pagePosition,
    this.contextTitle,
    this.listSources,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final ValueNotifier<double> pagePosition;
  final String? contextTitle;
  final Set<String>? listSources;

  @override
  State<_PooledVideoFeedItemContent> createState() =>
      _PooledVideoFeedItemContentState();
}

class _PooledVideoFeedItemContentState
    extends State<_PooledVideoFeedItemContent> {
  final _heartTrigger = ValueNotifier<HeartTrigger?>(null);
  int _heartTriggerId = 0;
  bool _contentWarningRevealed = false;

  void _handleDoubleTapLike(TapDownDetails details) {
    final hasContentWarning = shouldShowContentWarningOverlay(
      contentWarningLabels: widget.video.contentWarningLabels,
      warnLabels: widget.video.warnLabels,
    );
    if (hasContentWarning && !_contentWarningRevealed) return;

    final bloc = context.read<VideoInteractionsBloc>();
    final state = bloc.state;
    if (!state.isLiked && !state.isLikeInProgress) {
      bloc.add(const VideoInteractionsLikeToggled());
    }

    // Always show heart animation at tap position (even if already liked)
    _heartTrigger.value = (
      offset: details.localPosition,
      id: ++_heartTriggerId,
    );
  }

  @override
  void dispose() {
    _heartTrigger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    // All videos without dimensions are treated as portrait as its default
    // usecase (e.g. Reels-style vertical videos).
    final isPortrait = !(video.dimensions != null) || video.isPortrait;

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: PooledVideoPlayer(
        index: widget.index,
        isActive: widget.isActive,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: widget.isActive,
        onDoubleTap: _handleDoubleTapLike,
        videoBuilder: (context, videoController, player) => _FittedVideoPlayer(
          videoController: videoController,
          isPortrait: isPortrait,
        ),
        loadingBuilder: (context) => _VideoLoadingPlaceholder(
          thumbnailUrl: video.thumbnailUrl,
          isPortrait: isPortrait,
          videoId: video.id,
          feedMode: widget.contextTitle,
          index: widget.index,
        ),
        errorBuilder: (context, onRetry, errorType) {
          // Capture the cubit eagerly so the post-frame callback doesn't
          // walk the ancestor tree on a potentially-deactivated element.
          final cubit = context.read<VideoPlaybackStatusCubit>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            cubit.report(video.id, playbackStatusFromError(errorType));
          });
          return PooledVideoErrorOverlay(
            video: video,
            onRetry: onRetry,
            errorType: errorType,
          );
        },
        overlayBuilder: (context, videoController, player) => Stack(
          children: [
            FeedVideoOverlay(
              video: video,
              isActive: widget.isActive,
              pagePosition: widget.pagePosition,
              index: widget.index,
              player: player,
              firstFrameFuture: videoController?.waitUntilFirstFrameRendered,
              listSources: widget.listSources,
              onContentWarningRevealed: () {
                _contentWarningRevealed = true;
              },
            ),
            Positioned.fill(
              child: DoubleTapHeartOverlay(trigger: _heartTrigger),
            ),
            if (!video.isFromDivineServer)
              _SlowExternalVideoOverlay(index: widget.index),
          ],
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
    // Portrait: fill screen (cover), Landscape: fit entirely (contain)
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    // Do not set filterQuality to high — on Android the bicubic
    // interpolation causes visible blur on the Texture widget when
    // the video resolution doesn't match the display size exactly.
    return Video(
      controller: videoController,
      fit: boxFit,
      controls: null,
    );
  }
}

/// Overlay shown when an externally hosted video takes too long to load.
///
/// Listens to the controller's index notifier and shows a skip action
/// when `isSlowLoad` is true and the video is still loading.
/// Only rendered for non-Divine videos (controlled by the parent).
class _SlowExternalVideoOverlay extends StatelessWidget {
  const _SlowExternalVideoOverlay({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final feedController = VideoPoolProvider.feedOf(context);

    return ValueListenableBuilder<VideoIndexState>(
      valueListenable: feedController.getIndexNotifier(index),
      builder: (context, state, _) {
        if (!state.isSlowLoad || !state.isLoading) {
          return const SizedBox.shrink();
        }

        final isLastVideo =
            feedController.currentIndex >= feedController.videoCount - 1;

        return Positioned(
          bottom: 120,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: VineTheme.backgroundColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const DivineIcon(
                  icon: DivineIconName.globe,
                  color: VineTheme.secondaryText,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'External video loading slowly',
                    style: VineTheme.bodyMediumFont(),
                  ),
                ),
                if (!isLastVideo)
                  TextButton(
                    onPressed: () {
                      final nextIndex = feedController.currentIndex + 1;
                      context
                          .findAncestorStateOfType<PooledVideoFeedState>()
                          ?.animateToPage(nextIndex);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: VineTheme.vineGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Skip'),
                  ),
              ],
            ),
          ),
        );
      },
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
  });

  final String videoId;
  final int index;
  final String? feedMode;
  final String? thumbnailUrl;
  final bool isPortrait;

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
              children: [child, const _LoadingIndicator()],
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
