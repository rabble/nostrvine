// ABOUTME: Fullscreen video feed using pooled_video_player package
// ABOUTME: Displays videos with swipe navigation using managed player pool
// ABOUTME: Uses FullscreenFeedBloc for state management

import 'dart:async';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show InfiniteVideoFeed, VideoErrorType;
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/feed/feed_auto_advance_completion_listener.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_auto_advance_error_listener.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/pooled_player_logger.dart';
import 'package:openvine/utils/scroll_driven_opacity.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/nav_rounded_shell.dart';
import 'package:openvine/widgets/pooled_video_metrics_tracker.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:openvine/widgets/video_feed_item/inline_comment_composer_bar.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_author_info_section.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_interactions_bloc_key.dart';
import 'package:openvine/widgets/video_feed_item/video_player_subtitle_layer.dart';
import 'package:openvine/widgets/web_video_auth_header_provider.dart';
import 'package:openvine/widgets/web_video_feed.dart';
import 'package:openvine/widgets/web_video_player.dart';
import 'package:pooled_video_player/pooled_video_player.dart'
    as pvp
    show VideoErrorType;
import 'package:pooled_video_player/pooled_video_player.dart'
    hide VideoErrorType;
import 'package:unified_logger/unified_logger.dart';
import 'package:video_player/video_player.dart';

/// Always centers — including contain-fit (non-portrait) videos.
/// Returning [Alignment.topCenter] for non-portrait used to jam 1 × 1
/// classic Vine reposts against the AppBar; centering keeps them
/// symmetric with the bands the caller paints around them (see
/// [_MaybeRoundFeedBottom] / [_PooledFullscreenItemContent] for the
/// canvas and [_BlurredVideoBackdrop] for the blurred-thumbnail
/// layer). Portrait videos cover the whole viewport so alignment is
/// a no-op for them.
@visibleForTesting
Alignment fullscreenVideoMediaAlignment({required bool isPortrait}) {
  return Alignment.center;
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

/// Profile-backed arguments for fullscreen playback.
///
/// Unlike [PooledFullscreenVideoFeedArgs], this keeps the fullscreen route
/// subscribed directly to [profileFeedProvider] so profile-specific metadata
/// updates (like loop counts) are not lost when the launching grid unmounts.
class ProfilePooledFullscreenVideoFeedArgs {
  const ProfilePooledFullscreenVideoFeedArgs({
    required this.userIdHex,
    required this.initialIndex,
    this.initialVideoId,
    this.initialStableId,
    this.contextTitle,
    this.onPageChanged,
  });

  final String userIdHex;
  final int initialIndex;
  final String? initialVideoId;
  final String? initialStableId;
  final String? contextTitle;
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
  final _feedVideosKey = GlobalKey<FeedVideosState>();

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
    if (InfiniteVideoFeed.isSupported &&
        ref.read(isFeatureEnabledProvider(.nativeFeedPlayer))) {
      return;
    }

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

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
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

    // New native player path.
    final feedVideosState = _feedVideosKey.currentState;
    if (feedVideosState != null) {
      unawaited(feedVideosState.animateToPage(index));
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
    // Owned at the screen level so the inline comment composer bar at the
    // bottom of the Scaffold has a single cubit shared across page swipes —
    // re-creating it per-item would lose any in-flight publish during a
    // swipe. Keyed on the comments repository so an auth flip / account
    // switch closes the cubit and a fresh one captures the new repo
    // identity (see `rules/state_management.md`).
    final commentsRepository = ref.watch(commentsRepositoryProvider);

    return BlocProvider<InlineCommentComposerCubit>(
      key: ValueKey(commentsRepository),
      create: (_) =>
          InlineCommentComposerCubit(commentsRepository: commentsRepository),
      child: BlocProvider.value(
        value: _autoAdvanceCubit,
        child: MultiBlocListener(
          listeners: [
            // Sync volume when hardware buttons change system volume.
            // Also forward to the web feed so the in-pause mute toggle in
            // the paused overlay reaches WebVideoPlayer instances.
            BlocListener<VideoVolumeCubit, VideoVolumeState>(
              listener: (_, state) {
                _controller?.setVolume(state.volume);
                _webFeedKey.currentState?.setVolume(state.volume);
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
                  prev.videoUpdateSignature != curr.videoUpdateSignature,
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
                    // branch). Keep the same root-route fallback here so
                    // cold-start deep links never strand the user.
                    onBackPressed: () => _handleBack(context),
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
                    onBackPressed: () => _handleBack(context),
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
                    onBackPressed: () => _handleBack(context),
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

              // The inline comment composer bar sits at the bottom of the
              // Scaffold body (inside a Column with `Expanded(child:
              // feed)`) whenever there's an active video AND a signed-in
              // user. The bar lives in the body — NOT in
              // `Scaffold.bottomNavigationBar` — because Scaffold pins
              // bottomNavigationBar to `size.height - barHeight` and does
              // not push it above the keyboard. Putting the bar inside
              // the body lets Scaffold's default `resizeToAvoidBottomInset`
              // shrink the body when the keyboard opens, which slides the
              // bar up with it. The feed's MediaQuery is intentionally
              // left untouched: the home feed's overlays sit at
              // `bottom: 20 + viewPadding.bottom (= 34) = 54` above the
              // nav bar, and the fullscreen overlays use the same formula
              // so the action column / author info land at the same gap
              // above the comment bar. The bar's own `SafeArea`-style
              // padding handles the home-indicator visually.
              final showCommentBar =
                  currentUserPubkey != null && state.currentVideo != null;

              // Subscribe to Auto state so items rebuild on toggle/suppress/resume.
              final autoState = context.watch<FeedAutoAdvanceCubit>().state;

              // Gate the rail + runtime on the user's reduced-motion
              // preference. When Auto is unavailable,
              // force it "off" at the view layer regardless of cubit state.
              final autoAdvanceAvailable = !MediaQuery.disableAnimationsOf(
                context,
              );
              final effectiveAutoActive =
                  autoAdvanceAvailable && autoState.isEffectivelyActive;

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

              final appBar = DiVineAppBar(
                title: widget.contextTitle ?? '',
                showBackButton: true,
                onBackPressed: () => _handleBack(context),
                backgroundMode: DiVineAppBarBackgroundMode.transparent,
                forceMaterialTransparency: true,
                // Stretch the back-button tap target to the full
                // leading slot. The fullscreen feed sits over playing
                // video so a small icon hit-target is easy to miss.
                expandLeadingHitArea: true,
                customActions: const [FeedSettingsMenu()],
                style: DiVineAppBarStyle.transparentStyle.copyWith(
                  horizontalPadding: 12,
                  // With the default 48 px icon button and 12 px
                  // [horizontalPadding], a 72 px leading slot leaves
                  // 12 px between the back button's right edge and
                  // the title text (72 − 12 − 48 = 12).
                  leadingWidth: 72,
                  // Figma `title/medium` token (Bricolage Grotesque
                  // 800, 16 / 24 / 0.15) — overrides the default
                  // [VineTheme.titleLargeFont] (22) used by the
                  // shared app bar.
                  titleStyle: VineTheme.titleMediumFont(),
                ),
              );

              return Scaffold(
                // Paint the Scaffold with [VineTheme.surfaceBackground]
                // (`#00150D`, the same green the comment bar uses).
                // This is what shows wherever the Scaffold body leaks
                // around its content — most importantly the strip
                // below the soft keyboard (above the home indicator)
                // and the device's curved-corner cutouts at the
                // bottom edges. Keeping it green continues the comment
                // bar's surface visually around the keyboard. The
                // video item's own [ColoredBox] paints
                // [VineTheme.surfaceContainerHigh] on top of this so
                // the video area itself reads as a darker canvas.
                backgroundColor: VineTheme.surfaceBackground,
                // Always edge-to-edge: the video fills the screen and the
                // (transparent) AppBar overlays it, matching the home feed.
                // 1 × 1 / landscape / dimensions-less videos are rendered
                // with `BoxFit.contain`, so their letterbox bars sit on
                // the [VineTheme.surfaceContainerHigh] above — the
                // transparent AppBar reads cleanly against that surface
                // colour, no carve-out needed.
                extendBodyBehindAppBar: true,
                // Wrap the AppBar in a [TextFieldTapRegion] so taps on
                // the back button / title / [FeedSettingsMenu] popover
                // trigger don't dismiss the inline composer's keyboard.
                // That lets users toggle playback (mute, captions, ...)
                // mid-comment without losing what they're typing.
                // [TapRegion] is independent of the gesture arena, so
                // the back button and the More popover still fire their
                // own handlers — only the "tap outside" unfocus
                // callback is suppressed for taps inside this region.
                // The popover's pill content is wrapped in its own
                // [TextFieldTapRegion] inside [_FeedSettingsOverlay] so
                // taps on the playback controls (which render outside
                // this widget tree via [OverlayPortal]) are covered too.
                appBar: PreferredSize(
                  preferredSize: appBar.preferredSize,
                  child: TextFieldTapRegion(child: appBar),
                ),
                body: Column(
                  children: [
                    Expanded(
                      // Match the home feed: when the comment bar is on
                      // screen, the video carries the same rounded
                      // bottom corners as `video_feed_page.dart`, so
                      // the corners reveal [VineTheme.navGreen] (the
                      // outer color [NavRoundedShell] paints). It
                      // shares its hex (`#00150D`) with the comment
                      // bar's [VineTheme.surfaceBackground], so the
                      // rounded cutouts seam continuously into the bar.
                      child: VideoTapShield(
                        child: _MaybeRoundFeedBottom(
                          roundCorners: showCommentBar,
                          child:
                              InfiniteVideoFeed.isSupported &&
                                  ref.watch(
                                    isFeatureEnabledProvider(
                                      .nativeFeedPlayer,
                                    ),
                                  )
                              ? FeedVideos(
                                  key: _feedVideosKey,
                                  videos: state.videos,
                                  contextTitle: widget.contextTitle,
                                  currentIndex: state.currentIndex,
                                  shouldPortraitExpand: false,
                                  hasMore: state.canLoadMore,
                                  isLoadingMore: state.isLoadingMore,
                                  onActiveVideoChanged: (video, index) {
                                    _resumeAutoAdvanceAfterSwipe();
                                    FeedPerformanceTracker()
                                        .startVideoSwipeTracking(
                                          video.id,
                                        );
                                    context.read<FullscreenFeedBloc>().add(
                                      FullscreenFeedIndexChanged(index),
                                    );
                                    widget.onPageChanged?.call(index);
                                  },
                                  onNearEnd: () {
                                    if (state.canLoadMore) {
                                      _triggerLoadMore();
                                    }
                                  },
                                )
                              : kIsWeb
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
                                  initialVolume: context
                                      .read<VideoVolumeCubit>()
                                      .state
                                      .volume,
                                  onActiveVideoChanged: (video, index) {
                                    _pagePosition.value = index.toDouble();
                                    _resumeAutoAdvanceAfterSwipe();
                                    FeedPerformanceTracker()
                                        .startVideoSwipeTracking(
                                          video.id,
                                        );
                                    context.read<FullscreenFeedBloc>().add(
                                      FullscreenFeedIndexChanged(index),
                                    );
                                    widget.onPageChanged?.call(index);
                                  },
                                  onCompleted: (_) =>
                                      _handleAutoAdvanceCompleted(),
                                  onErrored: _handleWebPlayerErrored,
                                  onRequiresAuth: _handleWebPlayerRequiresAuth,
                                  onNearEnd: (index) =>
                                      _onNearEnd(state, index),
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
                                          isOwnVideo:
                                              currentUserPubkey == video.pubkey,
                                          controller: controller,
                                          contextTitle: widget.contextTitle,
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
                                    FeedPerformanceTracker()
                                        .startVideoSwipeTracking(
                                          video.id,
                                        );
                                    context.read<FullscreenFeedBloc>().add(
                                      FullscreenFeedIndexChanged(index),
                                    );
                                    widget.onPageChanged?.call(index);
                                  },
                                  onNearEnd: (index) =>
                                      _onNearEnd(state, index),
                                  nearEndThreshold: 0,
                                  onScrollOffsetChanged: (page) =>
                                      _pagePosition.value = page,
                                  maxLoopDuration:
                                      VideoEditorConstants.maxDuration,
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
                                      isAutoAdvanceActive: effectiveAutoActive,
                                      onInteracted: _suppressAutoAdvance,
                                      onAutoAdvanceCompleted:
                                          _handleAutoAdvanceCompleted,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                    if (showCommentBar) const InlineCommentComposerBar(),
                  ],
                ),
              );
            },
          ),
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
    required this.isAutoAdvanceActive,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.onInteracted,
    this.onAutoAdvanceCompleted,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool isOwnVideo;
  final ValueNotifier<double> pagePosition;
  final bool isAutoAdvanceActive;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;
  final VoidCallback? onInteracted;
  final VoidCallback? onAutoAdvanceCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.watch + record key: repository identity swaps and feed-cell reuse
    // must both recreate the per-video bloc so counts never leak between
    // videos. See #3503.
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final showVideoReplies = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.videoReplies),
    );

    final addressableId = video.addressableId;

    return BlocProvider<VideoInteractionsBloc>(
      key: videoInteractionsBlocKey(
        likesRepository: likesRepository,
        commentsRepository: commentsRepository,
        repostsRepository: repostsRepository,
        video: video,
        includeVideoReplies: showVideoReplies,
      ),
      create: (_) =>
          VideoInteractionsBloc(
              eventId: video.id,
              authorPubkey: video.pubkey,
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
              addressableId: addressableId,
              includeVideoReplies: showVideoReplies,
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
        isAutoAdvanceActive: isAutoAdvanceActive,
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
    this.controller,
    this.contextTitle,
    this.onInteracted,
  });

  final VideoEvent video;
  final bool isActive;
  final bool isOwnVideo;
  final VideoPlayerController? controller;
  final String? contextTitle;
  final VoidCallback? onInteracted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // See _PooledFullscreenItem.build for the watch + key rationale. #3503.
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final addressableId = video.addressableId;

    return BlocProvider<VideoInteractionsBloc>(
      key: videoInteractionsBlocKey(
        likesRepository: likesRepository,
        commentsRepository: commentsRepository,
        repostsRepository: repostsRepository,
        video: video,
      ),
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
      child: Stack(
        children: [
          VideoOverlayActions(
            video: video,
            isVisible: true,
            isActive: isActive,
            hasBottomNavigation: false,
            contextTitle: contextTitle,
            isFullscreen: true,
            topOffset: isOwnVideo ? 64 : 8,
            onInteracted: onInteracted,
            omitAuthorBlock: true,
            // See _PooledFullscreenItemContent.build for the rationale —
            // the action column lives in this outer Stack so it shares the
            // same bottom anchor as the author info below and the two
            // cannot vertically drift apart.
            omitActionColumn: true,
            // Top-of-screen scrim so the transparent app bar's white
            // title / back button / More popover stay readable over
            // light video frames.
            showTopGradient: true,
          ),
          // 20 px above the Stack bottom (= comment-bar top). See
          // _PooledFullscreenItemContent.build for why we drop the
          // `viewPadding.bottom` term that the home feed uses.
          PositionedDirectional(
            bottom: 20,
            start: 16,
            end: 80,
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: VideoAuthorInfoSection(
                video: video,
                hasTextContent:
                    video.content.isNotEmpty ||
                    (video.title != null && video.title!.isNotEmpty),
                subtitleLayer: video.hasSubtitles && controller != null
                    ? VideoPlayerSubtitleLayer(
                        video: video,
                        controller: controller!,
                      )
                    : null,
                onInteracted: onInteracted,
              ),
            ),
          ),
          PositionedDirectional(
            bottom: 20,
            end: 12,
            child: AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: KeyboardAwareTopFade(
                child: VideoOverlayActionColumn(
                  video: video,
                  isFullscreen: true,
                  onInteracted: onInteracted,
                ),
              ),
            ),
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
    required this.isAutoAdvanceActive,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    this.onInteracted,
    this.onAutoAdvanceCompleted,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;
  final bool isOwnVideo;
  final ValueNotifier<double> pagePosition;
  final bool isAutoAdvanceActive;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;
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

  /// Last error type reported to [VideoPlaybackStatusCubit] for this
  /// item's video. Dedupes at the call site so `errorBuilder` rebuilds
  /// (orientation change, parent rebuild) don't schedule a post-frame
  /// callback every frame. The cubit also dedupes internally, but
  /// skipping the callback entirely avoids per-frame scheduler churn.
  VideoErrorType? _lastReportedError;

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
    // Use [BoxFit.cover] *only* for videos we can prove are portrait
    // — i.e. ones with a dimensions tag whose height > width. Anything
    // else (1 × 1 classic Vine reposts, landscape videos, posts with
    // no dimensions metadata at all) falls into [BoxFit.contain] so it
    // sits centered on the screen instead of being stretched. Classic
    // 1 × 1 reposts arrive without dimensions; rendering them as
    // [BoxFit.cover] previously stretched the frame vertically to
    // fill the available height, distorting the image. Letterboxing
    // (the alternative) keeps the source proportions intact and
    // matches user expectations for square content.
    final isPortrait = video.isPortrait;
    final overlayLabels = contentWarningOverlayLabels(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );
    final showContentWarningOverlay = shouldShowContentWarningOverlay(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );

    final thumbnailUrl = video.thumbnailUrl;
    final showBlurBackdrop =
        !isPortrait && thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return FeedAutoAdvancePastErrorListener(
      videoId: video.id,
      isActive: widget.isActive,
      isAutoAdvanceActive: widget.isAutoAdvanceActive,
      onSkipBrokenVideo: widget.onAutoAdvanceCompleted ?? () {},
      child: ColoredBox(
        // [VineTheme.surfaceContainerHigh] (`#000A06`) — the canvas
        // colour we want behind contain-fit videos (1 × 1 / landscape
        // / dimensions-less). The previous `VineTheme.backgroundColor`
        // (`#000000`) was overpainting the Scaffold + NavRoundedShell
        // background here, so the surrounding letterbox bands always
        // rendered pure black regardless of what the outer surfaces
        // were set to.
        color: VineTheme.surfaceContainerHigh,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred thumbnail backdrop for contain-fit videos. The
            // thumbnail fills the screen (BoxFit.cover) and is heavily
            // blurred, so 1 × 1 / landscape sources are surrounded by
            // a diffused colour-cloud derived from their own first
            // frame — much closer to the Instagram / TikTok "blurred
            // poster" look than a flat dark surface. One image decode
            // + one GPU blur pass, no ongoing cost. Portrait videos
            // cover the screen entirely and would never reveal the
            // backdrop, so we skip it for them.
            if (showBlurBackdrop)
              Positioned.fill(
                child: _BlurredVideoBackdrop(url: thumbnailUrl),
              ),
            PooledVideoPlayer(
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
                // Map pooled_video_player.VideoErrorType to the canonical
                // infinite_video_feed.VideoErrorType used by playbackStatusFromError
                // and PooledVideoErrorOverlay.
                final feedErrorType = _toFeedErrorType(errorType);
                // Dedupe at the call site so rebuilds don't schedule a
                // post-frame callback every frame. See _lastReportedError doc.
                if (_lastReportedError != feedErrorType) {
                  _lastReportedError = feedErrorType;
                  // Capture the cubit eagerly so the post-frame callback doesn't
                  // walk the ancestor tree on a potentially-deactivated element.
                  final cubit = context.read<VideoPlaybackStatusCubit>();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    cubit.report(
                      video.id,
                      playbackStatusFromError(feedErrorType),
                    );
                  });
                }
                return PooledVideoErrorOverlay(
                  video: video,
                  onRetry: onRetry,
                  errorType: feedErrorType,
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
                // No `MediaQuery(data: MediaQueryData.fromView(...))` wrap
                // here: `MediaQueryData.fromView` is a *snapshot* taken when
                // this builder runs, so the subtree wouldn't see live
                // `viewInsets` updates when the soft keyboard slides up or
                // down. That breaks any descendant that needs to react to
                // the keyboard (e.g. [KeyboardAwareTopFade]). The inherited
                // MediaQuery from above is already correct — Scaffold only
                // modifies `padding`, not `viewInsets`.
                return FeedAutoAdvanceCompletionListener(
                  player: player,
                  isEnabled: widget.isActive && widget.isAutoAdvanceActive,
                  onCompleted: widget.onAutoAdvanceCompleted ?? () {},
                  child: Stack(
                    children: [
                      if (player != null)
                        PausedVideoPlayOverlay(
                          player: player,
                          firstFrameFuture:
                              videoController?.waitUntilFirstFrameRendered,
                          isVisible: widget.isActive,
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
                            overlayOpacity: scrollDrivenOpacity(distance),
                            hasBottomNavigation: false,
                            contextTitle: widget.contextTitle,
                            isFullscreen: true,
                            topOffset: widget.isOwnVideo ? 64 : 8,
                            onInteracted: widget.onInteracted,
                            // The shared [VideoAuthorInfoSection] below renders
                            // the author block + inline caption pill, matching
                            // the home feed overlay exactly. Suppress the
                            // legacy inline column so they don't double up.
                            omitAuthorBlock: true,
                            // The action column lives in this widget's outer
                            // Stack alongside the author info so both are
                            // anchored to the same Stack bottom — matches the
                            // home feed pattern in [FeedVideoOverlay] and
                            // keeps "About" vertically aligned with the
                            // bottom of the caption block.
                            omitActionColumn: true,
                            // Top-of-screen scrim so the transparent app
                            // bar's white title / back button / More
                            // popover stay readable over light video
                            // frames.
                            showTopGradient: true,
                          );
                        },
                      ),
                      // Bottom-left metadata container — author avatar/name,
                      // optional inline caption pill, and title/description.
                      // 20 px above the Stack bottom (= comment-bar top). No
                      // `viewPadding.bottom` term: the [InlineCommentComposerBar]
                      // already absorbs the device home-indicator inset, so
                      // adding it here would double-pad. The home feed's
                      // matching `bottom: 20 + safeAreaBottom` line works
                      // because there the inherited `viewPadding.bottom`
                      // collapses to 0 below the [VineBottomNav]'s `SafeArea`.
                      PositionedDirectional(
                        bottom: 20,
                        start: 16,
                        end: 80,
                        child: AnimatedOpacity(
                          opacity: widget.isActive ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: VideoAuthorInfoSection(
                            video: video,
                            hasTextContent:
                                video.content.isNotEmpty ||
                                (video.title != null &&
                                    video.title!.isNotEmpty),
                            player: player,
                            onInteracted: widget.onInteracted,
                          ),
                        ),
                      ),
                      // Action column — sibling of the author info, both
                      // anchored to the same Stack bottom at `bottom: 20`.
                      PositionedDirectional(
                        bottom: 20,
                        end: 12,
                        child: AnimatedOpacity(
                          opacity: widget.isActive ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: KeyboardAwareTopFade(
                            child: VideoOverlayActionColumn(
                              video: video,
                              isFullscreen: true,
                              onInteracted: widget.onInteracted,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DoubleTapHeartOverlay(trigger: _heartTrigger),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Heavily-blurred copy of a video's poster thumbnail, stretched to
/// `BoxFit.cover` the entire fullscreen area. Painted behind the video
/// in `_PooledFullscreenItemContent` so contain-fit videos (1 × 1 /
/// landscape) sit on a diffused colour cloud derived from their own
/// first frame instead of a flat dark surface — matches the
/// Instagram / TikTok "blurred poster" look.
///
/// Cost: one image decode + one GPU blur pass via [ImageFiltered].
/// The decoded image lives in Flutter's image cache, so revisiting
/// the same video re-uses it. No ongoing per-frame cost once the
/// image is rasterised.
class _BlurredVideoBackdrop extends StatelessWidget {
  const _BlurredVideoBackdrop({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // `ImageFiltered` applies the blur on the GPU side; `ClipRect`
      // keeps the bleeding edge of the blur kernel from leaking
      // outside the widget's box and over the surrounding chrome.
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          // 50 % opacity via [Image.opacity] (an animation) rather
          // than an [Opacity] wrapper — the latter forces a full-
          // screen save-layer, the former blends per-pixel during
          // paint and is essentially free.
          opacity: const AlwaysStoppedAnimation(0.5),
          // Fall back to nothing on error — the parent
          // [ColoredBox(VineTheme.surfaceContainerHigh)] shows through.
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
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

  /// Metadata-derived hint used until the controller reports the
  /// actual decoded video's rect. We can't trust the VideoEvent
  /// dimensions alone: classic Vine reposts arrive with no
  /// dimensions, and some new posts have stale / incorrect tags.
  /// The reactive [VideoController.rect] in [build] is the source
  /// of truth once the first frame lands.
  final bool isPortrait;

  final double? videoWidth;
  final double? videoHeight;

  @override
  Widget build(BuildContext context) {
    // [VideoController.rect] is a `ValueNotifier<Rect?>` populated
    // once the platform side reports the texture rect (i.e., once
    // the video is decoded and known). Listening here lets the
    // [BoxFit] decision react to the actual aspect ratio: 1 × 1 →
    // [BoxFit.contain] (centered with bands), portrait (height >
    // width) → [BoxFit.cover] (fills the screen), landscape →
    // [BoxFit.contain]. Until `rect` lands we fall back to the
    // metadata hint in [isPortrait].
    return ValueListenableBuilder<Rect?>(
      valueListenable: videoController.rect,
      builder: (context, rect, _) {
        final detected = _detectPortrait(rect, fallback: isPortrait);
        final boxFit = detected ? BoxFit.cover : BoxFit.contain;
        final alignment = fullscreenVideoMediaAlignment(
          isPortrait: detected,
        );
        // Do not set filterQuality to high — on Android the bicubic
        // interpolation causes visible blur on the Texture widget
        // when the video resolution doesn't match the display size
        // exactly.
        return Video(
          controller: videoController,
          fit: boxFit,
          alignment: alignment,
          controls: null,
          width: videoWidth,
          height: videoHeight,
          fill: const Color(0x00000000),
        );
      },
    );
  }

  static bool _detectPortrait(Rect? rect, {required bool fallback}) {
    if (rect == null) return fallback;
    if (rect.width <= 0 || rect.height <= 0) return fallback;
    return rect.height > rect.width;
  }
}

class _VideoLoadingPlaceholder extends StatelessWidget {
  const _VideoLoadingPlaceholder({
    this.thumbnailUrl,
    this.isPortrait = true,
  });

  final String? thumbnailUrl;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;
    final alignment = fullscreenVideoMediaAlignment(isPortrait: isPortrait);
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

/// Converts a [pvp.VideoErrorType] from [PooledVideoPlayer]'s error callback
/// to the canonical [VideoErrorType] from [infinite_video_feed].
VideoErrorType? _toFeedErrorType(pvp.VideoErrorType? t) => switch (t) {
  null => null,
  pvp.VideoErrorType.ageRestricted => VideoErrorType.ageRestricted,
  pvp.VideoErrorType.forbidden => VideoErrorType.forbidden,
  pvp.VideoErrorType.notFound => VideoErrorType.notFound,
  pvp.VideoErrorType.generic => VideoErrorType.generic,
};

/// Wraps the fullscreen video feed in a [NavRoundedShell] when the
/// inline comment composer bar is on screen, so the bottom of the
/// video carries the same rounded-corner treatment as the home feed.
/// Without the bar there's nothing to seam into, so the shell is
/// skipped and the feed renders edge-to-edge.
class _MaybeRoundFeedBottom extends StatelessWidget {
  const _MaybeRoundFeedBottom({
    required this.roundCorners,
    required this.child,
  });

  final bool roundCorners;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!roundCorners) return child;
    // Inside the rounded shell, paint
    // [VineTheme.surfaceContainerHigh] (`#000A06`) — a near-black with
    // a faint green tint. That's the canvas around contain-fit videos
    // (1 × 1 classics, landscape, anything without dimensions
    // metadata) which leave letterbox bands the user can see. The
    // shell's outer colour is [VineTheme.navGreen] (the color
    // [NavRoundedShell] paints by construction); it shares its hex
    // (`#00150D`) with the comment bar's [VineTheme.surfaceBackground],
    // so the rounded bottom corners reveal a colour that seams
    // continuously into the bar.
    return NavRoundedShell(
      innerColor: VineTheme.surfaceContainerHigh,
      child: child,
    );
  }
}

/// Wraps the video feed so that taps on the video are *consumed*
/// while a text input on this screen has primary focus.
///
/// Without this shield, tapping outside the inline comment composer's
/// text field while the keyboard is up both (a) dismisses the
/// keyboard — the intended effect — and (b) reaches the video's
/// play / pause gesture recognizer underneath, toggling playback as
/// a side-effect of typing.
///
/// The fix is layered:
///
/// * The shield's `GestureDetector(behavior: opaque)` claims the tap
///   in the gesture arena, so the video's recognizer never sees it.
/// * Keyboard dismissal still happens because [TextField.onTapOutside]
///   is wired through [TapRegion] / `TapRegionSurface`, which reads
///   pointer events at the surface level *independent* of the
///   gesture arena — so the claim above does not prevent the
///   onTapOutside callback from firing on the inline composer.
///
/// The shield only mounts the overlay while a text input has primary
/// focus, so it's a passthrough on the steady-state feed.
@visibleForTesting
class VideoTapShield extends StatefulWidget {
  @visibleForTesting
  const VideoTapShield({required this.child, super.key});

  final Widget child;

  @override
  State<VideoTapShield> createState() => _VideoTapShieldState();
}

class _VideoTapShieldState extends State<VideoTapShield> {
  bool _textInputFocused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    // Sync initial state in case a text input is already focused
    // when this widget mounts (rare — e.g. screen recreated mid-
    // composition).
    _onFocusChanged();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    final focused = _primaryFocusIsTextInput();
    if (focused == _textInputFocused) return;
    setState(() => _textInputFocused = focused);
  }

  /// Mirror the check used by [KeyboardAwareTopFade] /
  /// `_primaryFocusIsTextInput` over in this file's other helpers:
  /// the primary focus is "text input" iff its FocusNode's context
  /// has an [EditableText] ancestor (the widget that actually owns
  /// the platform TextInput connection).
  static bool _primaryFocusIsTextInput() {
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_textInputFocused)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Empty handler — see class docstring. The GD's job
              // is to claim the tap so the video's play / pause
              // recognizer never sees it; keyboard dismissal is
              // delivered by the composer's onTapOutside via
              // TapRegionSurface.
              onTap: () {},
            ),
          ),
      ],
    );
  }
}

/// Wraps the right-side action column so that its top fades to
/// transparent while the soft keyboard is on screen.
///
/// When the inline comment composer pulls the keyboard up,
/// [Scaffold.resizeToAvoidBottomInset] shrinks the body and the action
/// column slides up toward the transparent app bar — the Like button
/// can end up sitting under the More popover and the back button. The
/// [ShaderMask] erases the top of the column with a [BlendMode.dstIn]
/// gradient: fully transparent through the top 20 %, then a linear
/// fade to fully opaque at the bottom edge. The mask snaps on when
/// the keyboard begins to show, and fades out linearly over 100 ms
/// the moment the keyboard begins to hide, then drops the ShaderMask
/// wrapper entirely so the steady-state feed doesn't carry a save
/// layer.
///
/// The trigger is the *direction* of `viewInsets.bottom`, not whether
/// it's zero. On iOS and Android the platform animates the keyboard
/// inset over the OS's own animation curve (~250 ms) and Flutter
/// fires [WidgetsBindingObserver.didChangeMetrics] each frame.
/// "First decrease after a steady non-zero" is the start of the hide
/// animation, "first rise from zero" is the start of the show
/// animation — that lines the column fade up with the platform
/// keyboard animation in parallel rather than running it sequentially
/// after the keyboard is already gone.
///
/// Focus alone isn't a usable signal: on macOS / desktop a text
/// input can take focus by click without the platform keyboard ever
/// appearing, so a focus-driven mask would activate when the column
/// hasn't actually slid up.
///
/// We read the inset off the [FlutterView] rather than `MediaQuery`
/// because Scaffold's `resizeToAvoidBottomInset: true` strips
/// `viewInsets.bottom` from the body's MediaQuery (the body has
/// already shrunk to avoid the keyboard, so "the body shouldn't need
/// to know").
@visibleForTesting
class KeyboardAwareTopFade extends StatefulWidget {
  @visibleForTesting
  const KeyboardAwareTopFade({required this.child, super.key});

  final Widget child;

  @override
  State<KeyboardAwareTopFade> createState() => _KeyboardAwareTopFadeState();
}

class _KeyboardAwareTopFadeState extends State<KeyboardAwareTopFade>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Linear fade-out applied to the mask when the keyboard begins to
  /// hide. Picked to overlap the platform keyboard's dismiss
  /// animation (~250 ms) — the column is fully unmasked well before
  /// the keyboard finishes sliding off-screen. The fade-in is
  /// instantaneous because the AppBar collision happens immediately
  /// as the column slides up.
  static const Duration _fadeOutDuration = Duration(milliseconds: 100);

  /// Last sampled keyboard inset, used to infer the direction of
  /// change between [didChangeMetrics] frames.
  double _lastInset = 0;

  /// Whether the keyboard is currently visible (or animating in).
  /// Flips back to `false` the moment the inset starts decreasing
  /// from a non-zero value.
  bool _keyboardVisible = false;

  late final AnimationController _maskStrength;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _maskStrength = AnimationController(
      vsync: this,
      duration: _fadeOutDuration,
      value: 0,
    )..addStatusListener(_onMaskStatusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync initial state in case the keyboard is already up when
    // this widget mounts (rare — screen recreated mid-animation).
    final inset = View.of(context).viewInsets.bottom;
    if (inset > 0 && !_keyboardVisible) {
      _lastInset = inset;
      _keyboardVisible = true;
      _maskStrength.value = 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _maskStrength
      ..removeStatusListener(_onMaskStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final inset = View.of(context).viewInsets.bottom;
    final previous = _lastInset;
    _lastInset = inset;

    if (_keyboardVisible) {
      // Already up — only react to the first decrease, which is the
      // start of the hide animation. Subsequent decreasing frames
      // during the same animation no-op.
      if (inset < previous) {
        setState(() => _keyboardVisible = false);
        _maskStrength.reverse();
      }
    } else {
      // Hidden — any rise from a lower value into the positive range
      // is the start of the show animation. Snap the mask on so the
      // column is masked by the time it finishes sliding up.
      if (inset > previous && inset > 0) {
        setState(() => _keyboardVisible = true);
        _maskStrength.value = 1;
      }
    }
  }

  void _onMaskStatusChanged(AnimationStatus status) {
    // Drop the ShaderMask wrapper once the fade-out completes so the
    // steady-state feed isn't paying for an idle save layer.
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_maskStrength.value == 0) return widget.child;

    return AnimatedBuilder(
      animation: _maskStrength,
      child: widget.child,
      builder: (context, child) {
        // Only the alpha matters with BlendMode.dstIn. Interpolating the
        // top stop between opaque-white (no fade) and transparent
        // (full fade) lets a single animation value drive the strength
        // of the mask without changing the gradient shape.
        final topColor = Color.lerp(
          VineTheme.whiteText,
          Colors.transparent,
          _maskStrength.value,
        )!;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, VineTheme.whiteText],
              stops: const [0.2, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}
