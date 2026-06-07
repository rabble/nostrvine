// ABOUTME: Fullscreen video feed using the shared native feed player
// ABOUTME: Displays videos with swipe navigation and shared feed chrome
// ABOUTME: Uses FullscreenFeedBloc for state management

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/comments/comments_screen.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_settings_menu.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/nav_rounded_shell.dart';
import 'package:openvine/widgets/video_feed_item/feed_videos.dart';
import 'package:openvine/widgets/video_feed_item/inline_comment_composer_bar.dart';
import 'package:unified_logger/unified_logger.dart';

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
/// subscribed directly to the profile feed cubit so profile-specific metadata
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

/// Fullscreen video feed screen using FeedVideos.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation.
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

/// Content widget for the fullscreen video feed.
///
/// Wires feed playback hooks to dispatch BLoC events for caching and loop
/// enforcement.
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

  @override
  ConsumerState<FullscreenFeedContent> createState() =>
      _FullscreenFeedContentState();
}

class _FullscreenFeedContentState extends ConsumerState<FullscreenFeedContent>
    with RouteAware, WidgetsBindingObserver {
  late final ValueNotifier<double> _pagePosition;
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
    _pagePosition.dispose();
    unawaited(_autoAdvanceCubit.close());
    super.dispose();
  }

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

  void _resumeAutoAdvanceAfterSwipe() => _autoAdvanceCubit.resumeAfterSwipe();

  void _animateToPage(int index) {
    // New native player path.
    final feedVideosState = _feedVideosKey.currentState;
    if (feedVideosState != null) {
      unawaited(feedVideosState.animateToPage(index));
      return;
    }
  }

  FeedAutoAdvanceSnapshot _autoAdvanceSnapshot(FullscreenFeedState state) {
    return FeedAutoAdvanceSnapshot(
      currentIndex: state.currentIndex,
      itemCount: state.videos.length,
      hasMore: state.canLoadMore,
      isLoadingMore: state.isLoadingMore,
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

              final authService = ref.watch(authServiceProvider);
              final currentUserPubkey = authService.currentPublicKeyHex;

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
                      child: Stack(
                        children: [
                          VideoTapShield(
                            child: _MaybeRoundFeedBottom(
                              roundCorners: showCommentBar,
                              child: MediaQuery.removePadding(
                                context: context,
                                removeBottom: true,
                                child: FeedVideos(
                                  key: _feedVideosKey,
                                  videos: state.videos,
                                  contextTitle: widget.contextTitle,
                                  currentIndex: state.currentIndex,
                                  hasMore: state.canLoadMore,
                                  isLoadingMore: state.isLoadingMore,
                                  trafficSource: widget.trafficSource,
                                  sourceDetail: widget.sourceDetail,
                                  onActiveVideoChanged: (video, index) {
                                    _resumeAutoAdvanceAfterSwipe();
                                    FeedPerformanceTracker()
                                        .startVideoSwipeTracking(video.id);
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
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 16,
                            child: LoadingMorePill(
                              isVisible:
                                  state.isLoadingMore &&
                                  state.currentIndex >= state.videos.length - 1,
                            ),
                          ),
                        ],
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

/// Bottom-center pill shown while the fullscreen feed is fetching the
/// next page of videos and the user is already on the last item.
/// Hidden (with a short fade) otherwise so it doesn't sit on top of
/// the video chrome during normal scrolling.
@visibleForTesting
class LoadingMorePill extends StatelessWidget {
  @visibleForTesting
  const LoadingMorePill({required this.isVisible, super.key});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isVisible ? 1 : 0,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: VineTheme.surfaceBackground.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 10,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: BrandedLoadingIndicator(size: 16),
                  ),
                  Text(
                    context.l10n.feedLoadingMore,
                    style: VineTheme.bodyMediumFont(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
