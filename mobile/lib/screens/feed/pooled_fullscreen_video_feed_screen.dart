// ABOUTME: Fullscreen video feed using pooled_video_player package
// ABOUTME: Displays videos with swipe navigation using managed player pool
// ABOUTME: Uses FullscreenFeedBloc for state management

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/video_presentation.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/pooled_video_metrics_tracker.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

// Scroll-fraction constants for overlay opacity during page transitions.
//
// Opacity is scroll-driven: it changes continuously as the page scrolls,
// tracking the finger position rather than running on a separate timer.
// A small transition band around each threshold gives a smooth cross-fade.
const double _kOverlayFullOpacityThreshold = 0.1; // fully visible below 10 %
const double _kOverlayHideThreshold = 0.5; // fully hidden above 50 %
const double _kOverlayDimmedOpacity = 0.5; // opacity while in the dim band
// Half-width of the smooth cross-fade zone around each threshold.
// e.g. 0.03 → full↔dim transition spans 7 %–13 %, dim↔hidden spans 47 %–53 %.
const double _kOverlayFadeHalfWidth = 0.03;

/// Maps [distance] (0–1 fraction scrolled away from an item) to overlay
/// opacity using smooth linear interpolation around each threshold.
double _scrollDrivenOpacity(double distance) {
  const dimLo = _kOverlayFullOpacityThreshold - _kOverlayFadeHalfWidth;
  const dimHi = _kOverlayFullOpacityThreshold + _kOverlayFadeHalfWidth;
  const hideLo = _kOverlayHideThreshold - _kOverlayFadeHalfWidth;
  const hideHi = _kOverlayHideThreshold + _kOverlayFadeHalfWidth;

  if (distance <= dimLo) return 1.0;
  if (distance <= dimHi) {
    return lerpDouble(
      1.0,
      _kOverlayDimmedOpacity,
      (distance - dimLo) / (dimHi - dimLo),
    )!;
  }
  if (distance <= hideLo) return _kOverlayDimmedOpacity;
  if (distance <= hideHi) {
    return lerpDouble(
      _kOverlayDimmedOpacity,
      0.0,
      (distance - hideLo) / (hideHi - hideLo),
    )!;
  }
  return 0.0;
}

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
    final mediaCache = kIsWeb ? null : ref.read(mediaCacheProvider);
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

class _FullscreenFeedContentState extends ConsumerState<FullscreenFeedContent>
    with RouteAware {
  VideoFeedController? _controller;
  List<VideoItem>? _lastPooledVideos;
  late final ValueNotifier<double> _pagePosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes to pause/resume when navigating away
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    // Initialize controller if BLoC already has videos on first build
    _initializeControllerIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = context.read<FullscreenFeedBloc>().state.currentIndex;
    _pagePosition = ValueNotifier<double>(initialIndex.toDouble());
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controller?.dispose();
    _pagePosition.dispose();
    super.dispose();
  }

  // RouteAware callbacks: pause when another route is pushed on top,
  // resume when this route becomes visible again.

  @override
  void didPushNext() {
    // Another route was pushed on top - pause playback
    _controller?.setActive(active: false);
  }

  @override
  void didPopNext() {
    // Returned to this route - resume playback
    _controller?.setActive(active: true);
  }

  /// Initializes the controller if not already created and videos are
  /// available.
  ///
  /// Called from [didChangeDependencies] for initial setup and from
  /// [BlocListener] when videos become available asynchronously.
  void _initializeControllerIfNeeded({bool triggerRebuild = false}) {
    if (kIsWeb) return; // Skip media_kit controller on web
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

  void _onNearEnd(FullscreenFeedState state, int index) {
    if (!state.canLoadMore) {
      return;
    }

    final isAtEnd = index >= state.videos.length - 1;
    if (isAtEnd) {
      _triggerLoadMore();
    }
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
              backgroundColor: VineTheme.backgroundColor,
              appBar: DiVineAppBar(
                title: '',
                showBackButton: true,
                onBackPressed: context.pop,
                backgroundMode: DiVineAppBarBackgroundMode.transparent,
                forceMaterialTransparency: true,
              ),
              body: const Center(child: BrandedLoadingIndicator(size: 60)),
            );
          }

          if (!state.hasPooledVideos) {
            return Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              appBar: DiVineAppBar(
                title: '',
                showBackButton: true,
                onBackPressed: context.pop,
                backgroundMode: DiVineAppBarBackgroundMode.transparent,
                forceMaterialTransparency: true,
              ),
              body: const Center(
                child: Text(
                  'No videos available',
                  style: TextStyle(color: VineTheme.whiteText),
                ),
              ),
            );
          }

          final authService = ref.watch(authServiceProvider);
          final currentUserPubkey = authService.currentPublicKeyHex;
          final isOwnVideo =
              currentUserPubkey != null &&
              currentUserPubkey == state.currentVideo?.pubkey;

          final featureFlagService = ref.watch(featureFlagServiceProvider);
          final isEditorEnabled = featureFlagService.isEnabled(
            FeatureFlag.enableVideoEditorV1,
          );
          final currentVideo = state.currentVideo;
          final editAction =
              isEditorEnabled && isOwnVideo && currentVideo != null
              ? DiVineAppBarAction(
                  icon: SvgIconSource(
                    'assets/icon/${DivineIconName.pencilSimpleLine.fileName}.svg',
                  ),
                  onPressed: () =>
                      showEditDialogForVideo(context, currentVideo),
                  semanticLabel: 'Edit video',
                )
              : null;

          return Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            extendBodyBehindAppBar: true,
            appBar: DiVineAppBar(
              title: '',
              showBackButton: true,
              onBackPressed: context.pop,
              backgroundMode: DiVineAppBarBackgroundMode.transparent,
              forceMaterialTransparency: true,
              actions: [?editAction],
            ),
            body: kIsWeb
                ? WebVideoFeed(
                    videos: state.videos
                        .where((v) => v.videoUrl != null)
                        .toList(),
                    initialIndex: state.currentIndex,
                    onActiveVideoChanged: (video, index) {
                      _pagePosition.value = index.toDouble();
                      FeedPerformanceTracker().startVideoSwipeTracking(
                        video.id,
                      );
                      context.read<FullscreenFeedBloc>().add(
                        FullscreenFeedIndexChanged(index),
                      );
                    },
                    onNearEnd: (index) => _onNearEnd(state, index),
                    itemBuilder:
                        (
                          context,
                          video,
                          index, {
                          required isActive,
                          controller,
                        }) {
                          return _WebFullscreenItem(
                            video: video,
                            isActive: isActive,
                            isOwnVideo: currentUserPubkey == video.pubkey,
                            contextTitle: widget.contextTitle,
                          );
                        },
                  )
                : PooledVideoFeed(
                    videos: state.pooledVideos,
                    controller: _controller,
                    initialIndex: state.currentIndex,
                    onActiveVideoChanged: (video, index) {
                      FeedPerformanceTracker().startVideoSwipeTracking(
                        video.id,
                      );
                      context.read<FullscreenFeedBloc>().add(
                        FullscreenFeedIndexChanged(index),
                      );
                    },
                    onNearEnd: (index) => _onNearEnd(state, index),
                    nearEndThreshold: 0,
                    onScrollOffsetChanged: (page) => _pagePosition.value = page,
                    itemBuilder: (context, video, index, {required isActive}) {
                      if (state.videos.isEmpty) {
                        debugPrint(
                          'FullscreenFeed: itemBuilder called with empty '
                          'state.videos! index=$index, '
                          'video.id=${video.id}',
                        );
                        return const ColoredBox(
                          color: VineTheme.backgroundColor,
                        );
                      }
                      final originalEvent = state.videos.firstWhere(
                        (v) => v.id == video.id,
                        orElse: () {
                          final clamped = index.clamp(
                            0,
                            state.videos.length - 1,
                          );
                          debugPrint(
                            'FullscreenFeed: video ID lookup miss! '
                            'video.id=${video.id}, index=$index, '
                            'clamped=$clamped, '
                            'state.videos.length='
                            '${state.videos.length}, '
                            'pooledVideos.length='
                            '${state.pooledVideos.length}',
                          );
                          return state.videos[clamped];
                        },
                      );
                      return _PooledFullscreenItem(
                        video: originalEvent,
                        index: index,
                        isActive: isActive,
                        pagePosition: _pagePosition,
                        contextTitle: widget.contextTitle,
                        trafficSource: widget.trafficSource,
                        sourceDetail: widget.sourceDetail,
                        isOwnVideo: isOwnVideo,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _PooledFullscreenItem extends ConsumerWidget {
  const _PooledFullscreenItem({
    required this.video,
    required this.index,
    required this.isActive,
    required this.isOwnVideo,
    required this.pagePosition,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool isOwnVideo;
  final ValueNotifier<double> pagePosition;
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
              initialLikeCount: video.nostrLikeCount != null
                  ? video.totalLikes
                  : null,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: _PooledFullscreenItemContent(
        video: video,
        index: index,
        isActive: isActive,
        pagePosition: pagePosition,
        contextTitle: contextTitle,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
        isOwnVideo: isOwnVideo,
      ),
    );
  }
}

class _WebFullscreenItem extends ConsumerWidget {
  const _WebFullscreenItem({
    required this.video,
    required this.isActive,
    required this.isOwnVideo,
    this.contextTitle,
  });

  final VideoEvent video;
  final bool isActive;
  final bool isOwnVideo;
  final String? contextTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

    return BlocProvider<VideoInteractionsBloc>(
      create: (_) =>
          VideoInteractionsBloc(
              eventId: video.id,
              authorPubkey: video.pubkey,
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
              addressableId: video.addressableId,
              initialLikeCount: video.nostrLikeCount != null
                  ? video.totalLikes
                  : null,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: VideoOverlayActions(
        video: video,
        isVisible: true,
        isActive: isActive,
        hasBottomNavigation: false,
        contextTitle: contextTitle,
        isFullscreen: true,
        topOffset: isOwnVideo ? 64 : 8,
      ),
    );
  }
}

class _PooledFullscreenItemContent extends ConsumerStatefulWidget {
  const _PooledFullscreenItemContent({
    required this.video,
    required this.index,
    required this.isActive,
    required this.isOwnVideo,
    required this.pagePosition,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool isOwnVideo;
  final ValueNotifier<double> pagePosition;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

  @override
  ConsumerState<_PooledFullscreenItemContent> createState() =>
      _PooledFullscreenItemContentState();
}

class _PooledFullscreenItemContentState
    extends ConsumerState<_PooledFullscreenItemContent> {
  bool _contentWarningRevealed = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final isPortrait = video.dimensions != null && video.isPortrait;
    final alignment = videoAlignmentForDimensions(video.width, video.height);
    final overlayLabels = contentWarningOverlayLabels(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );
    final showContentWarningOverlay = shouldShowContentWarningOverlay(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );

    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: PooledVideoPlayer(
        index: widget.index,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: widget.isActive,
        videoBuilder: (context, videoController, player) =>
            PooledVideoMetricsTracker(
              key: ValueKey('metrics-${video.id}'),
              video: video,
              player: player,
              isActive: widget.isActive,
              trafficSource: widget.trafficSource,
              sourceDetail: widget.sourceDetail,
              child: _FittedVideoPlayer(
                videoController: videoController,
                isPortrait: isPortrait,
                alignment: alignment,
              ),
            ),
        loadingBuilder: (context) => _VideoLoadingPlaceholder(
          thumbnailUrl: video.thumbnailUrl,
          isPortrait: isPortrait,
          alignment: alignment,
        ),
        overlayBuilder: (context, videoController, player) {
          if (showContentWarningOverlay && !_contentWarningRevealed) {
            return ContentWarningBlurOverlay(
              labels: overlayLabels,
              onReveal: () => setState(() {
                _contentWarningRevealed = true;
              }),
              onHideSimilar: () {
                hideContentWarningsLikeThese(
                  context: context,
                  ref: ref,
                  labels: overlayLabels,
                );
              },
            );
          }
          return MediaQuery(
            data: MediaQueryData.fromView(View.of(context)),
            child: Stack(
              children: [
                if (player != null)
                  PausedVideoPlayOverlay(
                    player: player,
                    firstFrameFuture:
                        videoController?.waitUntilFirstFrameRendered,
                    isVisible: widget.isActive,
                  ),
                // Subtitle overlay — needs player position stream
                if (video.hasSubtitles && player != null)
                  Positioned.fill(
                    child: _SubtitleLayer(video: video, player: player),
                  ),
                ValueListenableBuilder<double>(
                  valueListenable: widget.pagePosition,
                  builder: (context, page, _) {
                    final distance = (page - widget.index).abs().clamp(
                      0.0,
                      1.0,
                    );
                    return VideoOverlayActions(
                      video: video,
                      // isVisible:true — scroll opacity handles fading;
                      // the hard-cut guard is not needed in fullscreen.
                      isVisible: true,
                      isActive: widget.isActive,
                      overlayOpacity: _scrollDrivenOpacity(distance),
                      hasBottomNavigation: false,
                      contextTitle: widget.contextTitle,
                      isFullscreen: true,
                      topOffset: widget.isOwnVideo ? 64 : 8,
                    );
                  },
                ),
              ],
            ),
          );
        },
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
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    // Do not set filterQuality to high — on Android the bicubic
    // interpolation causes visible blur on the Texture widget when
    // the video resolution doesn't match the display size exactly.
    return Video(
      controller: videoController,
      fit: boxFit,
      alignment: alignment,
      controls: null,
    );
  }
}

class _VideoLoadingPlaceholder extends StatelessWidget {
  const _VideoLoadingPlaceholder({
    this.thumbnailUrl,
    this.isPortrait = true,
    this.alignment = Alignment.center,
  });

  final String? thumbnailUrl;
  final bool isPortrait;
  final Alignment alignment;

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
            alignment: alignment,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: VineTheme.backgroundColor),
          )
        else
          const ColoredBox(color: VineTheme.backgroundColor),
        // Loading indicator overlay
        const _LoadingIndicator(),
      ],
    );
  }
}

class _LoadingIndicator extends StatefulWidget {
  const _LoadingIndicator();

  @override
  State<_LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<_LoadingIndicator> {
  // Delay before the indicator becomes visible. Suppresses sub-threshold
  // flashes that occur during play/pause and loop-enforcement seeks without
  // hiding the indicator during genuine long loads.
  static const _delay = Duration(milliseconds: 100);
  static const _fadeDuration = Duration(milliseconds: 150);

  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: _fadeDuration,
      opacity: _visible ? 1.0 : 0.0,
      child: const Center(child: BrandedLoadingIndicator(size: 60)),
    );
  }
}

/// Streams player position and renders subtitle text for fullscreen feed.
class _SubtitleLayer extends ConsumerWidget {
  const _SubtitleLayer({required this.video, required this.player});

  final VideoEvent video;
  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitlesVisible = ref.watch(subtitleVisibilityProvider);

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final positionMs = snapshot.data?.inMilliseconds ?? 0;
        return Stack(
          children: [
            SubtitleOverlay(
              video: video,
              positionMs: positionMs,
              visible: subtitlesVisible,
              bottomOffset: 180,
            ),
          ],
        );
      },
    );
  }
}
