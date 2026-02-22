// ABOUTME: Fullscreen video feed using pooled_video_player package
// ABOUTME: Displays videos with swipe navigation using managed player pool
// ABOUTME: Uses FullscreenFeedBloc for state management

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/pooled_video_metrics_tracker.dart';
import 'package:openvine/utils/quiet_hours.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Arguments for navigating to PooledFullscreenVideoFeedScreen.
///
/// Uses a stream-based approach where the source BLoC/provider remains
/// the single source of truth. The fullscreen screen receives:
/// - A stream of videos for reactive updates
/// - A callback to trigger load more on the source
class PooledFullscreenVideoFeedArgs {
  const PooledFullscreenVideoFeedArgs({
    required this.videosStream,
    required this.initialIndex,
    this.onLoadMore,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
  });

  /// Stream of videos from the source (BLoC or provider).
  final Stream<List<VideoEvent>> videosStream;

  /// Initial video index to start playback.
  final int initialIndex;

  /// Callback to trigger pagination on the source.
  final VoidCallback? onLoadMore;

  /// Optional title for context display.
  final String? contextTitle;

  /// Traffic source for view event analytics.
  final ViewTrafficSource trafficSource;

  /// Additional context for the traffic source (e.g., hashtag name).
  final String? sourceDetail;
}

/// Fullscreen video feed screen using pooled_video_player.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation using the managed player pool.
///
/// Uses [FullscreenFeedBloc] for state management, receiving videos from
/// the source via a stream and delegating pagination back to the source.
class PooledFullscreenVideoFeedScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const routeName = 'pooled-video-feed';

  /// Path for this route.
  static const path = '/pooled-video-feed';

  const PooledFullscreenVideoFeedScreen({
    required this.videosStream,
    required this.initialIndex,
    this.onLoadMore,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    super.key,
  });

  final Stream<List<VideoEvent>> videosStream;
  final int initialIndex;
  final VoidCallback? onLoadMore;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaCache = ref.read(mediaCacheProvider);
    final blossomAuthService = ref.read(blossomAuthServiceProvider);

    return BlocProvider(
      create: (_) => FullscreenFeedBloc(
        videosStream: videosStream,
        initialIndex: initialIndex,
        onLoadMore: onLoadMore,
        mediaCache: mediaCache,
        blossomAuthService: blossomAuthService,
      )..add(const FullscreenFeedStarted()),
      child: FullscreenFeedContent(
        contextTitle: contextTitle,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
      ),
    );
  }
}

/// Factory function for creating a [VideoFeedController].
///
/// Used for dependency injection in tests.
typedef VideoFeedControllerFactory =
    VideoFeedController Function(List<VideoItem> videos, int initialIndex);

/// Content widget for the fullscreen video feed.
///
/// Manages the [VideoFeedController] lifecycle and wires hooks to dispatch
/// BLoC events for caching and loop enforcement.
@visibleForTesting
class FullscreenFeedContent extends ConsumerStatefulWidget {
  /// Creates fullscreen feed content.
  @visibleForTesting
  const FullscreenFeedContent({
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    @visibleForTesting this.controllerFactory,
    super.key,
  });

  /// Optional title for context display.
  final String? contextTitle;

  /// Traffic source for view event analytics.
  final ViewTrafficSource trafficSource;

  /// Additional context for the traffic source (e.g., hashtag name).
  final String? sourceDetail;

  /// Optional factory for creating the [VideoFeedController].
  ///
  /// If provided, this factory is used instead of the default controller
  /// creation. This allows tests to inject a custom controller with
  /// hooks that can be verified.
  @visibleForTesting
  final VideoFeedControllerFactory? controllerFactory;

  @override
  ConsumerState<FullscreenFeedContent> createState() =>
      _FullscreenFeedContentState();
}

class _FullscreenFeedContentState extends ConsumerState<FullscreenFeedContent> {
  VideoFeedController? _controller;
  List<VideoItem>? _lastPooledVideos;
  bool _awaitingLoadMoreConfirmation = false;
  bool _isLoadingMoreFromNudge = false;
  int? _lastPromptedVideoCount;
  bool _shouldResumeAfterBreakPrompt = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize controller if BLoC already has videos on first build
    _initializeControllerIfNeeded();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Initializes the controller if not already created and videos are available.
  ///
  /// Called from [didChangeDependencies] for initial setup and from
  /// [BlocListener] when videos become available asynchronously.
  void _initializeControllerIfNeeded({bool triggerRebuild = false}) {
    if (_controller != null) return;

    final state = context.read<FullscreenFeedBloc>().state;
    if (!state.hasPooledVideos) return;

    _controller = _createController(state.pooledVideos, state.currentIndex);
    _lastPooledVideos = state.pooledVideos;

    if (triggerRebuild) setState(() {});
  }

  /// Handles new videos from pagination.
  void _handleVideosChanged(FullscreenFeedState state) {
    final controller = _controller;
    if (controller == null || _lastPooledVideos == null) return;

    final newVideos = state.pooledVideos
        .where((v) => !_lastPooledVideos!.any((old) => old.id == v.id))
        .toList();

    if (newVideos.isNotEmpty) {
      controller.addVideos(newVideos);
      if (mounted) {
        setState(() {
          _awaitingLoadMoreConfirmation = false;
          _isLoadingMoreFromNudge = false;
          _lastPromptedVideoCount = null;
          _shouldResumeAfterBreakPrompt = false;
        });
      }
    }
    _lastPooledVideos = state.pooledVideos;
  }

  /// Handles seek commands from the BLoC.
  void _handleSeekCommand(SeekCommand command) {
    final controller = _controller;
    if (controller == null) return;

    controller.seek(command.position);
    context.read<FullscreenFeedBloc>().add(
      const FullscreenFeedSeekCommandHandled(),
    );
  }

  void _triggerLoadMore() {
    context.read<FullscreenFeedBloc>().add(
      const FullscreenFeedLoadMoreRequested(),
    );
  }

  void _pauseCurrentVideoForBreakPrompt() {
    final controller = _controller;
    if (controller == null) return;

    _shouldResumeAfterBreakPrompt = !controller.isPaused;
    if (_shouldResumeAfterBreakPrompt) {
      controller.pause();
    }
  }

  void _resumeCurrentVideoAfterBreakPrompt() {
    if (!_shouldResumeAfterBreakPrompt) return;

    _controller?.play();
    _shouldResumeAfterBreakPrompt = false;
  }

  void _dismissBreakPrompt() {
    if (_awaitingLoadMoreConfirmation) {
      setState(() {
        _awaitingLoadMoreConfirmation = false;
      });
    }
    _resumeCurrentVideoAfterBreakPrompt();
  }

  void _showBreakPrompt(int currentVideoCount) {
    if (_awaitingLoadMoreConfirmation ||
        _lastPromptedVideoCount == currentVideoCount) {
      return;
    }

    setState(() {
      _awaitingLoadMoreConfirmation = true;
    });
    _pauseCurrentVideoForBreakPrompt();
  }

  void _confirmAndLoadMore(int currentVideoCount) {
    if (_isLoadingMoreFromNudge) return;

    _resumeCurrentVideoAfterBreakPrompt();
    setState(() {
      _awaitingLoadMoreConfirmation = false;
      _isLoadingMoreFromNudge = true;
      _lastPromptedVideoCount = currentVideoCount;
    });
    _triggerLoadMore();
  }

  void _onNearEnd(FullscreenFeedState state, bool nudgesEnabled, int index) {
    if (nudgesEnabled) {
      return;
    }

    if (!state.canLoadMore) {
      return;
    }

    final isAtEnd = index >= state.videos.length - 1;
    if (isAtEnd) {
      _triggerLoadMore();
    }
  }

  bool _isForwardSwipeAtFeedEnd(ScrollNotification notification) {
    final isAtMaxExtent =
        notification.metrics.pixels >=
        notification.metrics.maxScrollExtent - 0.5;

    if (!isAtMaxExtent) return false;

    if (notification is OverscrollNotification) {
      return notification.overscroll > 0;
    }
    if (notification is ScrollUpdateNotification) {
      return (notification.scrollDelta ?? 0) > 0;
    }
    if (notification is UserScrollNotification) {
      return notification.direction == ScrollDirection.reverse;
    }

    return false;
  }

  /// Creates a VideoFeedController with hooks wired to dispatch BLoC events.
  ///
  /// If [widget.controllerFactory] is provided (for testing), uses that
  /// instead of the default controller creation.
  VideoFeedController _createController(
    List<VideoItem> videos,
    int initialIndex,
  ) {
    // Use injected factory if provided (for testing)
    final factory = widget.controllerFactory;
    if (factory != null) {
      return factory(videos, initialIndex);
    }

    return VideoFeedController(
      videos: videos,
      pool: PlayerPool.instance,
      initialIndex: initialIndex,
      // Hook: Dispatch event for background caching when video is ready
      onVideoReady: (index, player) {
        if (!mounted) return;
        context.read<FullscreenFeedBloc>().add(
          FullscreenFeedVideoCacheStarted(index: index),
        );
      },
      // Hook: Dispatch position updates for loop enforcement
      positionCallback: (index, position) {
        if (!mounted) return;
        context.read<FullscreenFeedBloc>().add(
          FullscreenFeedPositionUpdated(index: index, position: position),
        );
      },
      positionCallbackInterval: const Duration(milliseconds: 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nudgesEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.feedBreakNudges),
    );
    final useSleepCopy = isQuietHoursNow();

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
        BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
          listenWhen: (prev, curr) => prev.isLoadingMore != curr.isLoadingMore,
          listener: (context, state) {
            if (!state.isLoadingMore && _isLoadingMoreFromNudge) {
              setState(() {
                _isLoadingMoreFromNudge = false;
              });
            }
          },
        ),
        // Handle seek commands
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
          if (state.status == FullscreenFeedStatus.initial ||
              !state.hasVideos) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: const _FullscreenAppBar(),
              body: const Center(child: BrandedLoadingIndicator(size: 60)),
            );
          }

          if (!state.hasPooledVideos) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: const _FullscreenAppBar(),
              body: const Center(
                child: Text(
                  'No videos available',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: _FullscreenAppBar(currentVideo: state.currentVideo),
            body: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    final isAtEnd =
                        state.currentIndex >= state.videos.length - 1;

                    if (nudgesEnabled &&
                        isAtEnd &&
                        _isForwardSwipeAtFeedEnd(notification)) {
                      if (!_awaitingLoadMoreConfirmation &&
                          _lastPromptedVideoCount != state.videos.length) {
                        _showBreakPrompt(state.videos.length);
                      } else if (_awaitingLoadMoreConfirmation &&
                          state.canLoadMore &&
                          !state.isLoadingMore &&
                          !_isLoadingMoreFromNudge) {
                        _confirmAndLoadMore(state.videos.length);
                      }
                    }

                    return false;
                  },
                  child: PooledVideoFeed(
                    videos: state.pooledVideos,
                    controller: _controller,
                    initialIndex: state.currentIndex,
                    onActiveVideoChanged: (video, index) {
                      context.read<FullscreenFeedBloc>().add(
                        FullscreenFeedIndexChanged(index),
                      );
                    },
                    onNearEnd: (index) =>
                        _onNearEnd(state, nudgesEnabled, index),
                    nearEndThreshold: 0,
                    itemBuilder: (context, video, index, {required isActive}) {
                      final originalEvent = state.videos[index];
                      return _PooledFullscreenItem(
                        video: originalEvent,
                        index: index,
                        isActive: isActive,
                        contextTitle: widget.contextTitle,
                        trafficSource: widget.trafficSource,
                        sourceDetail: widget.sourceDetail,
                      );
                    },
                  ),
                ),
                if (_awaitingLoadMoreConfirmation &&
                    nudgesEnabled &&
                    state.currentIndex >= state.videos.length - 1)
                  _FeedBreakOverlay(
                    useSleepCopy: useSleepCopy,
                    showLoadMoreAction: state.canLoadMore,
                    isLoadingMore:
                        state.isLoadingMore || _isLoadingMoreFromNudge,
                    onShowMore: () => _confirmAndLoadMore(state.videos.length),
                    onDismiss: _dismissBreakPrompt,
                    onDone: context.pop,
                    videosSeen: state.videos.length,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeedBreakOverlay extends StatelessWidget {
  const _FeedBreakOverlay({
    required this.useSleepCopy,
    required this.showLoadMoreAction,
    required this.isLoadingMore,
    required this.onShowMore,
    required this.onDismiss,
    required this.onDone,
    required this.videosSeen,
  });

  final bool useSleepCopy;
  final bool showLoadMoreAction;
  final bool isLoadingMore;
  final VoidCallback onShowMore;
  final VoidCallback onDismiss;
  final VoidCallback onDone;
  final int videosSeen;

  @override
  Widget build(BuildContext context) {
    final title = useSleepCopy
        ? "You've watched a lot tonight."
        : "You've watched a lot of videos...";
    final subtitle = useSleepCopy
        ? 'End of feed. Time to sleep and make tomorrow.'
        : 'Now go MAKE some.';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if ((details.primaryDelta ?? 0) > 14) {
          onDismiss();
        }
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 220) {
          onDismiss();
        }
      },
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: VineTheme.vineGreen.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      color: VineTheme.vineGreen,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You watched $videosSeen video${videosSeen == 1 ? '' : 's'} in this run.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onDismiss,
                          child: const Text('Keep Watching'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: onDone,
                          child: const Text('Close Feed'),
                        ),
                        if (showLoadMoreAction) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: isLoadingMore ? null : onShowMore,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VineTheme.vineGreen,
                              side: const BorderSide(
                                color: VineTheme.vineGreen,
                              ),
                            ),
                            child: isLoadingMore
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Show More'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Swipe down to dismiss this prompt.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _FullscreenAppBar({this.currentVideo});

  final VideoEvent? currentVideo;

  static const _style = DiVineAppBarStyle(
    iconButtonBackgroundColor: Color(0x4D000000), // black with 0.3 alpha
  );

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DiVineAppBar(
      titleWidget: const SizedBox.shrink(),
      showBackButton: true,
      onBackPressed: context.pop,
      backgroundMode: DiVineAppBarBackgroundMode.transparent,
      style: _style,
      actions: _buildEditAction(context, ref),
    );
  }

  // TODO(any) : update to use bloc instead of riverpod
  List<DiVineAppBarAction> _buildEditAction(
    BuildContext context,
    WidgetRef ref,
  ) {
    final video = currentVideo;
    if (video == null) return const [];

    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isEditorEnabled = featureFlagService.isEnabled(
      FeatureFlag.enableVideoEditorV1,
    );
    if (!isEditorEnabled) return const [];

    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == video.pubkey;
    if (!isOwnVideo) return const [];

    return [
      DiVineAppBarAction(
        icon: const SvgIconSource('assets/icon/content-controls/pencil.svg'),
        onPressed: () => showEditDialogForVideo(context, video),
        tooltip: 'Edit video',
        semanticLabel: 'Edit video',
      ),
    ];
  }
}

class _PooledFullscreenItem extends ConsumerWidget {
  const _PooledFullscreenItem({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

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
      child: _PooledFullscreenItemContent(
        video: video,
        index: index,
        isActive: isActive,
        contextTitle: contextTitle,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
      ),
    );
  }
}

class _PooledFullscreenItemContent extends StatelessWidget {
  const _PooledFullscreenItemContent({
    required this.video,
    required this.index,
    required this.isActive,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

  @override
  Widget build(BuildContext context) {
    final isPortrait = video.dimensions != null ? video.isPortrait : true;

    return ColoredBox(
      color: Colors.black,
      child: PooledVideoPlayer(
        index: index,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: isActive,
        videoBuilder: (context, videoController, player) =>
            PooledVideoMetricsTracker(
              key: ValueKey('metrics-${video.id}'),
              video: video,
              player: player,
              isActive: isActive,
              trafficSource: trafficSource,
              sourceDetail: sourceDetail,
              child: _FittedVideoPlayer(
                videoController: videoController,
                isPortrait: isPortrait,
              ),
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
              contextTitle: contextTitle,
              isFullscreen: true,
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
        // Thumbnail background (if available)
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: boxFit,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        // Loading indicator overlay
        const _LoadingIndicator(),
      ],
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
