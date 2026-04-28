// ABOUTME: Fullscreen video feed using pooled_video_player package
// ABOUTME: Displays videos with swipe navigation using managed player pool
// ABOUTME: Uses FullscreenFeedBloc for state management

import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/feed/feed_auto_advance_completion_listener.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_auto_advance_error_listener.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/pooled_player_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/pooled_video_metrics_tracker.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_player_subtitle_layer.dart';
import 'package:openvine/widgets/web_video_auth_header_provider.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:openvine/widgets/web_video_player.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:video_player/video_player.dart';

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
    this.hasMoreStream,
    this.removedIdsStream,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.autoOpenComments = false,
    this.onPageChanged,
  });

  /// Stream of videos from the source (BLoC or provider).
  final Stream<List<VideoEvent>> videosStream;

  /// Initial video index to start playback.
  final int initialIndex;

  /// Callback to trigger pagination on the source.
  final VoidCallback? onLoadMore;

  /// Stream of whether the source can paginate further.
  final Stream<bool>? hasMoreStream;

  /// Side-channel for "this video must be dropped now" — fed from
  /// [VideoEventService.removedVideoIds]. Optional so that callers
  /// pre-dating the deletion-bus migration keep working.
  final Stream<String>? removedIdsStream;

  /// Optional title for context display.
  final String? contextTitle;

  /// Traffic source for view event analytics.
  final ViewTrafficSource trafficSource;

  /// Additional context for the traffic source (e.g., hashtag name).
  final String? sourceDetail;

  /// Whether to open the comments sheet immediately after the first frame.
  ///
  /// Used when navigating from a comment/reply notification.
  final bool autoOpenComments;

  /// Called whenever the active video index changes.
  ///
  /// Used by embedded surfaces to keep the URL in sync.
  final void Function(int index)? onPageChanged;
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
    this.hasMoreStream,
    this.removedIdsStream,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.autoOpenComments = false,
    this.onPageChanged,
    super.key,
  });

  final Stream<List<VideoEvent>> videosStream;
  final int initialIndex;
  final VoidCallback? onLoadMore;
  final Stream<bool>? hasMoreStream;

  /// Side-channel that emits a video id whenever the underlying service
  /// has marked it removed (deletion / future block / mute). Optional so
  /// not-yet-migrated callers keep working — without the wire-up the
  /// fullscreen falls back to today's stale behaviour.
  final Stream<String>? removedIdsStream;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

  /// When true, opens the comments sheet immediately after the first frame.
  ///
  /// Used when navigating from a comment/reply notification.
  final bool autoOpenComments;

  /// Called whenever the active video index changes.
  ///
  /// Receives the new feed index. Used by embedded surfaces (e.g. explore,
  /// search) to keep the URL in sync for deep-linking.
  final void Function(int index)? onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaCache = kIsWeb ? null : ref.read(mediaCacheProvider);
    final blossomAuthService = ref.read(blossomAuthServiceProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => FullscreenFeedBloc(
            videosStream: videosStream,
            initialIndex: initialIndex,
            hasMoreStream: hasMoreStream,
            removedIdsStream: removedIdsStream,
            onLoadMore: onLoadMore,
            mediaCache: mediaCache,
            blossomAuthService: blossomAuthService,
          )..add(const FullscreenFeedStarted()),
        ),
        BlocProvider(create: (_) => VideoPlaybackStatusCubit()),
      ],
      child: FullscreenFeedContent(
        contextTitle: contextTitle,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
        autoOpenComments: autoOpenComments,
        onPageChanged: onPageChanged,
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
    this.autoOpenComments = false,
    this.onPageChanged,
    @visibleForTesting this.controllerFactory,
    @visibleForTesting this.webControllerFactory,
    super.key,
  });

  /// Optional title for context display.
  final String? contextTitle;

  /// Traffic source for view event analytics.
  final ViewTrafficSource trafficSource;

  /// Additional context for the traffic source (e.g., hashtag name).
  final String? sourceDetail;

  /// When true, opens the comments sheet immediately after the first frame.
  ///
  /// Used when navigating from a comment/reply notification.
  final bool autoOpenComments;

  /// Called whenever the active video index changes.
  ///
  /// Used by embedded surfaces to keep the URL in sync.
  final void Function(int index)? onPageChanged;

  /// Optional factory for creating the [VideoFeedController].
  ///
  /// If provided, this factory is used instead of the default controller
  /// creation. This allows tests to inject a custom controller with
  /// hooks that can be verified.
  @visibleForTesting
  final VideoFeedControllerFactory? controllerFactory;

  /// Optional factory for creating web video controllers in tests.
  @visibleForTesting
  final WebVideoPlayerControllerFactory? webControllerFactory;

  @override
  ConsumerState<FullscreenFeedContent> createState() =>
      _FullscreenFeedContentState();
}

class _FullscreenFeedContentState extends ConsumerState<FullscreenFeedContent>
    with RouteAware, WidgetsBindingObserver {
  VideoFeedController? _controller;
  List<VideoItem>? _lastPooledVideos;
  late final ValueNotifier<double> _pagePosition;
  final _feedKey = GlobalKey<PooledVideoFeedState>();
  final _webFeedKey = GlobalKey<WebVideoFeedState>();

  /// Feed-scoped Auto playback state; exposed to descendants via
  /// `BlocProvider.value` in [build].
  final FeedAutoAdvanceCubit _autoAdvanceCubit = FeedAutoAdvanceCubit();

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
    WidgetsBinding.instance.addObserver(this);
    final initialIndex = context.read<FullscreenFeedBloc>().state.currentIndex;
    _pagePosition = ValueNotifier<double>(initialIndex.toDouble());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _controller?.dispose();
    _pagePosition.dispose();
    unawaited(_autoAdvanceCubit.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _controller?.setActive(active: true);
    }
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

    final previousVideos = _lastPooledVideos!;
    final nextVideos = state.pooledVideos;
    final previousIds = previousVideos.map((v) => v.id).toList();
    final nextIds = nextVideos.map((v) => v.id).toList();
    final isAppendOnly =
        nextIds.length >= previousIds.length &&
        listEquals(nextIds.take(previousIds.length).toList(), previousIds);

    if (isAppendOnly) {
      final newVideos = nextVideos.skip(previousVideos.length).toList();
      if (newVideos.isNotEmpty) {
        controller.addVideos(newVideos);
      }
    } else {
      controller.replaceVideos(nextVideos, currentIndex: state.currentIndex);
    }
    _lastPooledVideos = nextVideos;
  }

  /// Whether auto-advance is available on this build. Reduced-motion users
  /// keep the control and runtime disabled regardless of in-app toggle state.
  bool _isAutoAdvanceAvailable() {
    if (!mounted) return false;
    return !MediaQuery.disableAnimationsOf(context);
  }

  void _toggleAutoAdvance() {
    if (!_isAutoAdvanceAvailable()) return;

    _autoAdvanceCubit.toggle();
    if (!_autoAdvanceCubit.state.isEffectivelyActive) {
      _autoAdvanceCubit.clearPendingPaginationAdvance();
    }
    announceAutoAdvanceToggle(
      context,
      enabled: _autoAdvanceCubit.state.enabled,
    );
  }

  void _suppressAutoAdvance() => _autoAdvanceCubit.suppressForInteraction();

  void _resumeAutoAdvanceAfterSwipe() => _autoAdvanceCubit.resumeAfterSwipe();

  void _animateToPage(int index) {
    if (kIsWeb) {
      final webFeedState = _webFeedKey.currentState;
      if (webFeedState == null || webFeedState.videoCount == 0) return;

      final targetIndex = index.clamp(0, webFeedState.videoCount - 1);
      if (targetIndex == webFeedState.currentIndex) return;

      unawaited(webFeedState.animateToPage(targetIndex));
      return;
    }

    final feedState = _feedKey.currentState;
    if (feedState == null || feedState.controller.videoCount == 0) return;

    final targetIndex = index.clamp(0, feedState.controller.videoCount - 1);
    if (targetIndex == feedState.controller.currentIndex) return;

    unawaited(feedState.animateToPage(targetIndex));
  }

  FeedAutoAdvanceSnapshot _autoAdvanceSnapshot(FullscreenFeedState state) {
    return FeedAutoAdvanceSnapshot(
      currentIndex: state.currentIndex,
      itemCount: state.videos.length,
      hasMore: state.canLoadMore,
      isLoadingMore: state.isLoadingMore,
    );
  }

  void _handleAutoAdvanceCompleted() {
    handleFeedAutoAdvanceCompleted(
      cubit: _autoAdvanceCubit,
      snapshot: _autoAdvanceSnapshot(context.read<FullscreenFeedBloc>().state),
      animateToPage: _animateToPage,
      requestLoadMore: _triggerLoadMore,
    );
  }

  /// Treat a failed web player as "completed" so Auto skips past broken
  /// videos. Only fires for the currently-active page to avoid advancing
  /// when a background/preloaded player fails.
  ///
  /// Also dispatches [FullscreenFeedVideoUnavailable] so the BLoC can
  /// HEAD-confirm whether the asset is permanently missing (404) and, if so,
  /// remove it from the feed for the rest of the session.
  void _handleWebPlayerErrored(int index) {
    final bloc = context.read<FullscreenFeedBloc>();
    if (index != bloc.state.currentIndex) return;
    final video = bloc.state.currentVideo;
    if (video != null) {
      bloc.add(FullscreenFeedVideoUnavailable(video.id));
    }
    _handleAutoAdvanceCompleted();
  }

  /// Treat auth-gated web playback as the existing age-restricted state,
  /// not as a broken video. This keeps 401/403 out of the #3107 404-removal
  /// path, which is only for confirmed missing assets.
  void _handleWebPlayerRequiresAuth(VideoEvent video, int index) {
    final bloc = context.read<FullscreenFeedBloc>();
    if (index != bloc.state.currentIndex) return;
    context.read<VideoPlaybackStatusCubit>().report(
      video.id,
      PlaybackStatus.ageRestricted,
    );
  }

  /// Dispatch a [FullscreenFeedVideoUnavailable] event for the active video
  /// when the cubit reports [PlaybackStatus.notFound]. Replaces the prior
  /// per-item post-frame callback that violated the "no business logic in
  /// widgets" rule.
  void _dispatchVideoUnavailableIfActive(VideoPlaybackStatusState state) {
    final bloc = context.read<FullscreenFeedBloc>();
    final activeVideo = bloc.state.currentVideo;
    if (activeVideo == null) return;
    if (state.statusFor(activeVideo.id) != PlaybackStatus.notFound) return;
    if (bloc.state.removedVideoIds.contains(activeVideo.id)) return;
    bloc.add(FullscreenFeedVideoUnavailable(activeVideo.id));
  }

  /// React to a pending skip target emitted by the BLoC after a confirmed
  /// 404. Animates the active feed (pooled on native, page controller on
  /// web) and acknowledges the signal so the BLoC clears it.
  Future<void> _handlePendingSkip(int nextIndex) async {
    try {
      _animateToPage(nextIndex);
    } on Exception catch (error, stackTrace) {
      Log.error(
        'FullscreenFeedContent: animateToPage failed during skip',
        name: 'FullscreenFeedContent',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    context.read<FullscreenFeedBloc>().add(
      const FullscreenFeedSkipAcknowledged(),
    );
  }

  void _continuePendingAutoAdvance(FullscreenFeedState state) {
    continueFeedAutoAdvanceAfterPagination(
      cubit: _autoAdvanceCubit,
      snapshot: _autoAdvanceSnapshot(state),
      animateToPage: _animateToPage,
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
      initialVolume: context.read<VideoVolumeCubit>().state.volume,
      onVolumeChanged: context.read<VideoVolumeCubit>().onPlaybackVolumeChanged,
      // Hook: Dispatch event for background caching when video is ready
      onVideoReady: (index, player) {
        if (!mounted) return;
        context.read<FullscreenFeedBloc>().add(
          FullscreenFeedVideoCacheStarted(index: index),
        );
      },
      maxLoopDuration: VideoEditorConstants.maxDuration,
      onLog: pooledPlayerLogCallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _autoAdvanceCubit,
      child: MultiBlocListener(
        listeners: [
          // Sync volume when hardware buttons change system volume.
          BlocListener<VideoVolumeCubit, VideoVolumeState>(
            listener: (_, state) {
              _controller?.setVolume(state.volume);
            },
          ),
          // Initialize controller when videos first become available
          BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
            listenWhen: (prev, curr) =>
                !prev.hasPooledVideos && curr.hasPooledVideos,
            listener: (context, state) =>
                _initializeControllerIfNeeded(triggerRebuild: true),
          ),
          // Handle new videos from pagination
          BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
            listenWhen: (prev, curr) =>
                prev.videos.length != curr.videos.length,
            listener: (context, state) => _handleVideosChanged(state),
          ),
          BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
            listenWhen: (prev, curr) =>
                prev.videos.length != curr.videos.length ||
                prev.isLoadingMore != curr.isLoadingMore ||
                prev.canLoadMore != curr.canLoadMore,
            listener: (context, state) => _continuePendingAutoAdvance(state),
          ),
          // Open comments sheet once the first video is ready (notification deep-link)
          if (widget.autoOpenComments)
            BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
              listenWhen: (prev, curr) =>
                  prev.currentVideo == null && curr.currentVideo != null,
              listener: (context, state) {
                final video = state.currentVideo;
                if (video != null) CommentsScreen.show(context, video);
              },
            ),
          // Dispatch FullscreenFeedVideoUnavailable when the active video's
          // playback status becomes notFound. The BLoC owns the HEAD-confirm,
          // removal, and dedupe logic — this listener is the screen-level
          // bridge that replaces the per-item post-frame callback.
          BlocListener<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
            listener: (context, state) =>
                _dispatchVideoUnavailableIfActive(state),
          ),
          // Animate the feed when the BLoC signals a pending skip after a
          // confirmed 404 removal.
          BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
            listenWhen: (prev, curr) =>
                prev.pendingSkipTarget != curr.pendingSkipTarget &&
                curr.pendingSkipTarget != null,
            listener: (context, state) {
              final target = state.pendingSkipTarget;
              if (target != null) unawaited(_handlePendingSkip(target));
            },
          ),
          // Pop the route when the last visible video has been removed
          // by deletion (or, soon, block / mute). When `maybePop`
          // returns false (cold deep-link into the fullscreen with no
          // parent route in the stack), the BlocBuilder below renders
          // an explicit `emptyAfterRemoval` branch so the user is not
          // left looking at a perpetual loading spinner.
          BlocListener<FullscreenFeedBloc, FullscreenFeedState>(
            listenWhen: (prev, curr) =>
                prev.status != curr.status &&
                curr.status == FullscreenFeedStatus.emptyAfterRemoval,
            listener: (context, _) {
              unawaited(Navigator.of(context).maybePop());
            },
          ),
        ],
        child: BlocBuilder<FullscreenFeedBloc, FullscreenFeedState>(
          builder: (context, state) {
            // The BlocListener above tries to pop on this status; when
            // it can (parent route exists) the route is gone before this
            // branch renders. When `maybePop` is a no-op, we land here
            // and show an explicit empty-state with a back button rather
            // than the loading spinner below.
            if (state.status == FullscreenFeedStatus.emptyAfterRemoval) {
              return Scaffold(
                backgroundColor: VineTheme.backgroundColor,
                appBar: DiVineAppBar(
                  title: widget.contextTitle ?? '',
                  showBackButton: true,
                  // The BlocListener above already tried `maybePop` and
                  // failed (otherwise we wouldn't be rendering this
                  // branch). The same `pop` from the appbar back button
                  // would also be a no-op, so fall back to the home
                  // shell to avoid a dead-end UX.
                  onBackPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                  backgroundMode: DiVineAppBarBackgroundMode.transparent,
                  forceMaterialTransparency: true,
                ),
                body: Center(
                  child: Text(
                    context.l10n.fullscreenFeedRemovedMessage,
                    style: VineTheme.bodyMediumFont(),
                  ),
                ),
              );
            }

            if (state.status == FullscreenFeedStatus.initial ||
                !state.hasVideos) {
              return Scaffold(
                backgroundColor: VineTheme.backgroundColor,
                appBar: DiVineAppBar(
                  title: widget.contextTitle ?? '',
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
                  title: widget.contextTitle ?? '',
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
            // Subscribe to Auto state so items rebuild on toggle/suppress/resume.
            final autoState = context.watch<FeedAutoAdvanceCubit>().state;

            // Gate the rail + runtime on the user's reduced-motion
            // preference. When Auto is unavailable,
            // force it "off" at the view layer regardless of cubit state.
            final autoAdvanceAvailable = !MediaQuery.disableAnimationsOf(
              context,
            );
            final effectiveAutoEnabled =
                autoAdvanceAvailable && autoState.enabled;
            final effectiveAutoActive =
                autoAdvanceAvailable && autoState.isEffectivelyActive;

            final currentVideo = state.currentVideo;
            final editAction =
                isEditorEnabled && isOwnVideo && currentVideo != null
                ? DiVineAppBarAction(
                    icon: SvgIconSource(
                      DivineIconName.pencilSimpleLine.assetPath,
                    ),
                    onPressed: () =>
                        showEditDialogForVideo(context, currentVideo),
                    semanticLabel: 'Edit video',
                  )
                : null;

            // Wire the NIP-98 auth header provider into WebVideoFeed only
            // when running on web AND the HLS auth web player flag is on.
            // When either condition is false, authHeaderProvider stays null
            // and the legacy VideoPlayerController path is used unchanged.
            final hlsAuthWebPlayerEnabled = ref.watch(
              isFeatureEnabledProvider(FeatureFlag.hlsAuthWebPlayer),
            );
            final webAuthHeaderProvider = kIsWeb && hlsAuthWebPlayerEnabled
                ? buildWebVideoAuthHeaderProvider(
                    ref.watch(mediaViewerAuthServiceProvider),
                  )
                : null;

            return Scaffold(
              backgroundColor: VineTheme.backgroundColor,
              extendBodyBehindAppBar: true,
              appBar: DiVineAppBar(
                title: widget.contextTitle ?? '',
                showBackButton: true,
                onBackPressed: context.pop,
                backgroundMode: DiVineAppBarBackgroundMode.transparent,
                forceMaterialTransparency: true,
                actions: [?editAction],
              ),
              body: kIsWeb
                  ? WebVideoFeed(
                      key: _webFeedKey,
                      videos: state.videos
                          .where((v) => v.videoUrl != null)
                          .toList(),
                      initialIndex: state.currentIndex,
                      controllerFactory:
                          widget.webControllerFactory ??
                          defaultWebVideoPlayerControllerFactory,
                      authHeaderProvider: webAuthHeaderProvider,
                      onActiveVideoChanged: (video, index) {
                        _pagePosition.value = index.toDouble();
                        _resumeAutoAdvanceAfterSwipe();
                        FeedPerformanceTracker().startVideoSwipeTracking(
                          video.id,
                        );
                        context.read<FullscreenFeedBloc>().add(
                          FullscreenFeedIndexChanged(index),
                        );
                        widget.onPageChanged?.call(index);
                      },
                      onCompleted: (_) => _handleAutoAdvanceCompleted(),
                      onErrored: _handleWebPlayerErrored,
                      onRequiresAuth: _handleWebPlayerRequiresAuth,
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
                              controller: controller,
                              contextTitle: widget.contextTitle,
                              showAutoButton: autoAdvanceAvailable,
                              isAutoEnabled: effectiveAutoEnabled,
                              onAutoPressed: _toggleAutoAdvance,
                              onInteracted: _suppressAutoAdvance,
                            );
                          },
                    )
                  : PooledVideoFeed(
                      key: _feedKey,
                      videos: state.pooledVideos,
                      controller: _controller,
                      initialIndex: state.currentIndex,
                      onActiveVideoChanged: (video, index) {
                        _resumeAutoAdvanceAfterSwipe();
                        FeedPerformanceTracker().startVideoSwipeTracking(
                          video.id,
                        );
                        context.read<FullscreenFeedBloc>().add(
                          FullscreenFeedIndexChanged(index),
                        );
                        widget.onPageChanged?.call(index);
                      },
                      onNearEnd: (index) => _onNearEnd(state, index),
                      nearEndThreshold: 0,
                      onScrollOffsetChanged: (page) =>
                          _pagePosition.value = page,
                      maxLoopDuration: VideoEditorConstants.maxDuration,
                      itemBuilder:
                          (context, video, index, {required isActive}) {
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
                              showAutoButton: autoAdvanceAvailable,
                              isAutoEnabled: effectiveAutoEnabled,
                              isAutoAdvanceActive: effectiveAutoActive,
                              onAutoPressed: _toggleAutoAdvance,
                              onInteracted: _suppressAutoAdvance,
                              onAutoAdvanceCompleted:
                                  _handleAutoAdvanceCompleted,
                            );
                          },
                    ),
            );
          },
        ),
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
    required this.showAutoButton,
    required this.isAutoEnabled,
    required this.isAutoAdvanceActive,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.onAutoPressed,
    this.onInteracted,
    this.onAutoAdvanceCompleted,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool isOwnVideo;
  final ValueNotifier<double> pagePosition;
  final bool showAutoButton;
  final bool isAutoEnabled;
  final bool isAutoAdvanceActive;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;
  final VoidCallback? onAutoPressed;
  final VoidCallback? onInteracted;
  final VoidCallback? onAutoAdvanceCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch + record key: see video_feed_page.dart for rationale.
    // Without this, a fullscreen entry that mounts during the auth-flip
    // window (warm-up materialized providers pre-auth, then provider
    // graph rebuilds) snapshots a stale LikesRepository whose underlying
    // Nostr instance has an empty cached pubkey — every sendLike then
    // throws StateError. See #3503.
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);

    final addressableId = video.addressableId;

    return BlocProvider<VideoInteractionsBloc>(
      key: ValueKey((likesRepository, commentsRepository, repostsRepository)),
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
        showAutoButton: showAutoButton,
        isAutoEnabled: isAutoEnabled,
        isAutoAdvanceActive: isAutoAdvanceActive,
        onAutoPressed: onAutoPressed,
        onInteracted: onInteracted,
        onAutoAdvanceCompleted: onAutoAdvanceCompleted,
      ),
    );
  }
}

class _WebFullscreenItem extends ConsumerWidget {
  const _WebFullscreenItem({
    required this.video,
    required this.isActive,
    required this.isOwnVideo,
    required this.showAutoButton,
    required this.isAutoEnabled,
    this.controller,
    this.contextTitle,
    this.onAutoPressed,
    this.onInteracted,
  });

  final VideoEvent video;
  final bool isActive;
  final bool isOwnVideo;
  final bool showAutoButton;
  final bool isAutoEnabled;
  final VideoPlayerController? controller;
  final String? contextTitle;
  final VoidCallback? onAutoPressed;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // See _PooledFullscreenItem.build for the rationale on watch + key. #3503.
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);

    return BlocProvider<VideoInteractionsBloc>(
      key: ValueKey((likesRepository, commentsRepository, repostsRepository)),
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
      child: Stack(
        children: [
          if (isActive && video.hasSubtitles && controller != null)
            Positioned.fill(
              child: VideoPlayerSubtitleLayer(
                video: video,
                controller: controller!,
              ),
            ),
          VideoOverlayActions(
            video: video,
            isVisible: true,
            isActive: isActive,
            hasBottomNavigation: false,
            contextTitle: contextTitle,
            isFullscreen: true,
            topOffset: isOwnVideo ? 64 : 8,
            showAutoButton: showAutoButton,
            isAutoEnabled: isAutoEnabled,
            onAutoPressed: onAutoPressed,
            onInteracted: onInteracted,
          ),
        ],
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
    required this.showAutoButton,
    required this.isAutoEnabled,
    required this.isAutoAdvanceActive,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.onAutoPressed,
    this.onInteracted,
    this.onAutoAdvanceCompleted,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool isOwnVideo;
  final ValueNotifier<double> pagePosition;
  final bool showAutoButton;
  final bool isAutoEnabled;
  final bool isAutoAdvanceActive;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;
  final VoidCallback? onAutoPressed;
  final VoidCallback? onInteracted;
  final VoidCallback? onAutoAdvanceCompleted;

  @override
  ConsumerState<_PooledFullscreenItemContent> createState() =>
      _PooledFullscreenItemContentState();
}

class _PooledFullscreenItemContentState
    extends ConsumerState<_PooledFullscreenItemContent> {
  final _heartTrigger = ValueNotifier<HeartTrigger?>(null);
  int _heartTriggerId = 0;
  bool _contentWarningRevealed = false;

  void _handleDoubleTapLike(TapDownDetails details) {
    final showWarning = shouldShowContentWarningOverlay(
      contentWarningLabels: widget.video.contentWarningLabels,
      warnLabels: widget.video.warnLabels,
    );
    if (showWarning && !_contentWarningRevealed) return;

    final bloc = context.read<VideoInteractionsBloc>();
    final state = bloc.state;
    if (!state.isLiked) {
      bloc.add(const VideoInteractionsLikeToggled());
    }

    // Always show heart animation at tap position (even if already liked)
    _heartTrigger.value = (
      offset: details.localPosition,
      id: ++_heartTriggerId,
    );
  }

  void _handlePlayerTap() {
    widget.onInteracted?.call();
    VideoPoolProvider.feedOf(context).togglePlayPause();
  }

  @override
  void dispose() {
    _heartTrigger.dispose();
    super.dispose();
  }

  /// Advances the feed to the next page by finding the nearest
  /// [PooledVideoFeedState] ancestor and calling its public
  /// [PooledVideoFeedState.animateToPage].
  void _skipToNextVideo(BuildContext context) {
    final feedState = context.findAncestorStateOfType<PooledVideoFeedState>();
    assert(
      feedState != null,
      'ModeratedContentOverlay must be mounted inside PooledVideoFeed',
    );
    if (feedState == null) return;
    unawaited(feedState.animateToPage(widget.index + 1));
  }

  /// Triggers age verification and retries pooled playback with viewer auth.
  Future<void> _verifyAgeForVideo(
    BuildContext context,
    VideoEvent video,
  ) async {
    await retryAgeRestrictedPooledVideo(
      context: context,
      ref: ref,
      video: video,
      index: widget.index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final isPortrait = video.dimensions != null && video.isPortrait;
    final overlayLabels = contentWarningOverlayLabels(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );
    final showContentWarningOverlay = shouldShowContentWarningOverlay(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );

    return FeedAutoAdvancePastErrorListener(
      videoId: video.id,
      isActive: widget.isActive,
      isAutoAdvanceActive: widget.isAutoAdvanceActive,
      onSkipBrokenVideo: widget.onAutoAdvanceCompleted ?? () {},
      child: ColoredBox(
        color: VineTheme.backgroundColor,
        child: PooledVideoPlayer(
          index: widget.index,
          isActive: widget.isActive,
          thumbnailUrl: video.thumbnailUrl,
          enableTapToPause: widget.isActive,
          onTap: _handlePlayerTap,
          onDoubleTap: _handleDoubleTapLike,
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
                  videoWidth: video.width?.toDouble(),
                  videoHeight: video.height?.toDouble(),
                ),
              ),
          loadingBuilder: (context) => _VideoLoadingPlaceholder(
            thumbnailUrl: video.thumbnailUrl,
            isPortrait: isPortrait,
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
          overlayBuilder: (context, videoController, player, feedController) {
            final playbackStatus = context.select(
              (VideoPlaybackStatusCubit cubit) =>
                  cubit.state.statusFor(video.id),
            );
            if (playbackStatus == PlaybackStatus.forbidden ||
                playbackStatus == PlaybackStatus.ageRestricted) {
              return ModeratedContentOverlay(
                status: playbackStatus,
                onSkip: () => _skipToNextVideo(context),
                onVerifyAge: playbackStatus == PlaybackStatus.ageRestricted
                    ? () => _verifyAgeForVideo(context, video)
                    : null,
              );
            }
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
              child: FeedAutoAdvanceCompletionListener(
                player: player,
                isEnabled: widget.isActive && widget.isAutoAdvanceActive,
                onCompleted: widget.onAutoAdvanceCompleted ?? () {},
                child: Stack(
                  children: [
                    if (player != null)
                      PausedVideoPlayOverlay(
                        onToggleMuteState: () =>
                            feedController?.toggleMuteState(),
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
                          showAutoButton: widget.showAutoButton,
                          isAutoEnabled: widget.isAutoEnabled,
                          onAutoPressed: widget.onAutoPressed,
                          onInteracted: widget.onInteracted,
                        );
                      },
                    ),
                    Positioned.fill(
                      child: DoubleTapHeartOverlay(trigger: _heartTrigger),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FittedVideoPlayer extends StatelessWidget {
  const _FittedVideoPlayer({
    required this.videoController,
    this.isPortrait = true,
    this.videoWidth,
    this.videoHeight,
  });

  final VideoController videoController;
  final bool isPortrait;
  final double? videoWidth;
  final double? videoHeight;

  @override
  Widget build(BuildContext context) {
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    // Do not set filterQuality to high — on Android the bicubic
    // interpolation causes visible blur on the Texture widget when
    // the video resolution doesn't match the display size exactly.
    return Video(
      controller: videoController,
      fit: boxFit,
      controls: null,
      width: videoWidth,
      height: videoHeight,
      fill: const Color(0x00000000),
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
