import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart'
    hide PlaybackStatus;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_cubit.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_auto_advance_error_listener.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/services/view_event_publisher.dart'
    show ViewTrafficSource;
import 'package:openvine/utils/scroll_driven_opacity.dart';
import 'package:openvine/widgets/divine_video_metrics_tracker.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';
import 'package:openvine/widgets/video_feed_item/live_engagement_counts.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_overlay.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_interactions_bloc_key.dart';
import 'package:openvine/widgets/video_feed_item/video_loading_placeholder.dart';

class FeedVideos extends ConsumerStatefulWidget {
  const FeedVideos({
    required this.videos,
    required this.onNearEnd,
    this.contextTitle,
    this.currentIndex = 0,
    this.shouldPortraitExpand = true,
    this.isActive = true,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onActiveVideoChanged,
    this.trafficSource = ViewTrafficSource.unknown,
    this.sourceDetail,
    super.key,
  });

  final List<VideoEvent> videos;
  final VoidCallback onNearEnd;
  final int currentIndex;
  final String? contextTitle;
  final bool shouldPortraitExpand;

  /// Whether this feed should be playing. Set to `false` when the owning
  /// screen is obscured (tab switch, overlay open) to pause the active video
  /// without tearing down the widget tree.
  final bool isActive;

  /// Whether more videos can be loaded from the source.
  ///
  /// Used to build the [FeedAutoAdvanceSnapshot] passed to
  /// [handleFeedAutoAdvanceCompleted] and
  /// [continueFeedAutoAdvanceAfterPagination].
  final bool hasMore;

  /// Whether a pagination load is currently in progress.
  ///
  /// Used together with [hasMore] to decide whether auto-advance should
  /// wait for more content before advancing.
  final bool isLoadingMore;

  /// Called when the active (visible) video changes.
  final void Function(VideoEvent video, int index)? onActiveVideoChanged;

  final ViewTrafficSource trafficSource;
  final String? sourceDetail;

  @override
  ConsumerState<FeedVideos> createState() => FeedVideosState();
}

class FeedVideosState extends ConsumerState<FeedVideos> with RouteAware {
  /// Reads the page-scoped [FeedAutoAdvanceCubit] from context.
  ///
  /// The cubit is owned and provided by the enclosing page surface
  /// ([VideoFeedPage] / [PooledFullscreenVideoFeedScreen]) so the home
  /// feed's top-bar [FeedSettingsMenu] and this widget's internal
  /// auto-advance flow share a single instance. Creating a second cubit
  /// here would silently shadow the page-scoped one for the inner subtree
  /// and make the popover toggle a no-op.
  FeedAutoAdvanceCubit get _autoAdvanceCubit =>
      context.read<FeedAutoAdvanceCubit>();
  final _feedKey = GlobalKey<InfiniteVideoFeedState>();
  bool _routeAllowsPlayback = true;

  /// Last error type reported per video.id to
  /// [VideoPlaybackStatusCubit]. Used to dedupe at the call site so
  /// `errorBuilder` rebuilds (orientation change, parent rebuild) don't
  /// schedule a post-frame callback every frame. The cubit also dedupes
  /// internally, but skipping the callback entirely avoids the per-frame
  /// scheduler churn.
  final Map<String, VideoErrorType> _lastReportedError = {};

  /// Video ids whose content warning the user dismissed via "View Anyway".
  ///
  /// Lives at the feed level (not in the per-item overlay state) because
  /// [InfiniteVideoFeed.canAutoPlay] must consult it before starting
  /// playback — a warned video must stay paused until revealed.
  final Set<String> _revealedContentWarningVideoIds = <String>{};

  /// Whether [video] may start playing: either it has no content-warning
  /// gate, or the user already chose "View Anyway" for it.
  bool _canAutoPlayVideo(VideoEvent video) =>
      !shouldShowContentWarningOverlay(
        contentWarningLabels: video.contentWarningLabels,
        warnLabels: video.warnLabels,
      ) ||
      _revealedContentWarningVideoIds.contains(video.id);

  /// Marks [videoId] as revealed and starts playback of the active video.
  void _revealContentWarning(String videoId) {
    setState(() {
      _revealedContentWarningVideoIds.add(videoId);
    });
    _feedKey.currentState?.resumeCurrentPlayback();
  }

  /// Animates the underlying feed to [index].
  ///
  /// Used by parent screens that hold a [GlobalKey<FeedVideosState>] to
  /// programmatically skip to a specific video (e.g. after a 404 removal).
  Future<void> animateToPage(int index) =>
      _feedKey.currentState?.animateToPage(index) ?? Future.value();

  Future<bool> _retryPooledVideoAt(
    int index,
    Map<String, String> httpHeaders,
  ) =>
      _feedKey.currentState?.retryAt(index, httpHeaders: httpHeaders) ??
      Future.value(false);

  @override
  void didUpdateWidget(covariant FeedVideos oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When pagination settles (hasMore / isLoadingMore changed), flush any
    // pending auto-advance that was waiting on more content.
    if (widget.hasMore != oldWidget.hasMore ||
        widget.isLoadingMore != oldWidget.isLoadingMore) {
      final currentIndex = _feedKey.currentState?.currentIndex ?? 0;
      continueFeedAutoAdvanceAfterPagination(
        cubit: _autoAdvanceCubit,
        snapshot: FeedAutoAdvanceSnapshot(
          currentIndex: currentIndex,
          itemCount: widget.videos.length,
          hasMore: widget.hasMore,
          isLoadingMore: widget.isLoadingMore,
        ),
        animateToPage: (index) =>
            unawaited(_feedKey.currentState?.animateToPage(index)),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_routeAllowsPlayback) return;
    setState(() => _routeAllowsPlayback = false);
  }

  @override
  void didPopNext() {
    if (_routeAllowsPlayback) return;
    setState(() => _routeAllowsPlayback = true);
  }

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

  void _handleAutoAdvanceCompleted(int currentIndex) {
    handleFeedAutoAdvanceCompleted(
      cubit: _autoAdvanceCubit,
      snapshot: FeedAutoAdvanceSnapshot(
        currentIndex: currentIndex,
        itemCount: widget.videos.length,
        hasMore: widget.hasMore,
        isLoadingMore: widget.isLoadingMore,
      ),
      animateToPage: (index) =>
          unawaited(_feedKey.currentState?.animateToPage(index)),
      requestLoadMore: widget.onNearEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFeedActive = widget.isActive && _routeAllowsPlayback;
    return MultiBlocListener(
      listeners: [
        BlocListener<VideoVolumeCubit, VideoVolumeState>(
          // Sync volume when hardware buttons change system volume.
          listener: (_, state) {
            _feedKey.currentState?.setVolume(state.volume);
          },
        ),
        BlocListener<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
          listenWhen: (previous, current) => previous != current,
          // Once a video recovers to `ready` (e.g. after age verification),
          // forget its last reported error so a later re-error re-surfaces
          // through the errorBuilder dedupe instead of being suppressed.
          listener: (_, state) {
            _lastReportedError.removeWhere(
              (videoId, _) => state.statusFor(videoId) == PlaybackStatus.ready,
            );
          },
        ),
      ],
      child: InfiniteVideoFeed(
        key: _feedKey,
        videos: widget.videos,
        isActive: isFeedActive,
        // mediaCacheProvider is a keepAlive singleton; identity is stable for
        // the app lifetime, so ref.read is safe here. See
        // .claude/rules/state_management.md → "Bridging Riverpod-provided
        // dependencies into BlocProvider" → exception #1.
        cache: ref.read(mediaCacheProvider),
        urlResolver: (video) => video.getOptimalVideoUrlForPlatform(),
        initialIndex: widget.currentIndex,
        onNearEnd: widget.onNearEnd,
        initialVolume: context.read<VideoVolumeCubit>().state.volume,
        onVolumeChanged: context
            .read<VideoVolumeCubit>()
            .onPlaybackVolumeChanged,
        onActiveVideoChanged: (video, index) {
          _resumeAutoAdvanceAfterSwipe();
          widget.onActiveVideoChanged?.call(video, index);
        },
        onVideoLoopCompleted: _handleAutoAdvanceCompleted,
        shouldPortraitExpand: widget.shouldPortraitExpand,
        maxLoopDuration: VideoEditorConstants.maxDuration,
        canAutoPlay: _canAutoPlayVideo,
        videoBuilder: (context, child, index, controller) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];

          final thumbnailUrl = video.thumbnailUrl;
          final showBlurBackdrop =
              !video.isPortrait &&
              thumbnailUrl != null &&
              thumbnailUrl.isNotEmpty;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (showBlurBackdrop)
                Positioned.fill(child: BlurredVideoBackdrop(url: thumbnailUrl)),
              child,
            ],
          );
        },
        loadingBuilder: (context, index, {required bool isSquare}) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];
          return _FeedLoadingOrRestrictedOverlay(
            video: video,
            index: index,
            feedMode: widget.contextTitle,
            isSquare: isSquare,
            shouldPortraitExpand: widget.shouldPortraitExpand,
          );
        },
        errorBuilder: (context, index, onRetry, errorType) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];

          // Dedupe at the call site so `errorBuilder` rebuilds don't
          // schedule a post-frame callback every frame. See
          // _lastReportedError doc above.
          if (_lastReportedError[video.id] != errorType) {
            _lastReportedError[video.id] = errorType;
            // Capture the cubit eagerly so the post-frame callback doesn't
            // walk the ancestor tree on a potentially-deactivated element.
            final cubit = context.read<VideoPlaybackStatusCubit>();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              cubit.report(video.id, playbackStatusFromError(errorType));
            });
          }
          // Mirror the BoxFit logic of VideoLoadingPlaceholder /
          // VideoItemWidget so the error thumbnail respects the same
          // square / portrait-expand rules as the live video.
          final width = video.width;
          final height = video.height;
          final isSquare = width != null && height != null && width == height;
          return PooledVideoErrorOverlay(
            video: video,
            onRetry: onRetry,
            onVerifyAge: () => retryAgeRestrictedPooledVideo(
              context: context,
              ref: ref,
              video: video,
              index: index,
              retryPlayback: (httpHeaders) =>
                  _retryPooledVideoAt(index, httpHeaders),
            ),
            errorType: errorType,
            shouldPortraitExpand: widget.shouldPortraitExpand,
            isSquare: isSquare,
          );
        },
        overlayBuilder: (context, index, controller, {required bool isActive}) {
          if (index < 0 || index >= widget.videos.length) {
            return const SizedBox.shrink();
          }
          final video = widget.videos[index];
          return DivineVideoMetricsTracker(
            video: video,
            controller: controller,
            isActive: isFeedActive && isActive,
            trafficSource: widget.trafficSource,
            sourceDetail: widget.sourceDetail,
            child: _Overlay(
              controller: controller,
              video: video,
              index: index,
              isActive: isActive,
              contextTitle: widget.contextTitle,
              contentWarningRevealed: _revealedContentWarningVideoIds.contains(
                video.id,
              ),
              onContentWarningRevealed: () => _revealContentWarning(video.id),
              onToggleAutoAdvance: _toggleAutoAdvance,
              onSuppressAutoAdvance: _suppressAutoAdvance,
            ),
          );
        },
      ),
    );
  }
}

class _Overlay extends ConsumerStatefulWidget {
  const _Overlay({
    required this.contextTitle,
    required this.controller,
    required this.video,
    required this.index,
    required this.isActive,
    required this.contentWarningRevealed,
    required this.onContentWarningRevealed,
    this.onToggleAutoAdvance,
    this.onSuppressAutoAdvance,
  });

  final String? contextTitle;
  final DivineVideoPlayerController? controller;
  final VideoEvent video;
  final int index;
  final bool isActive;

  /// Whether the user already dismissed this video's content warning.
  /// Owned by [FeedVideosState] so the autoplay gate can read it too.
  final bool contentWarningRevealed;

  /// Called when the user taps "View Anyway" on the content warning.
  final VoidCallback onContentWarningRevealed;

  final VoidCallback? onToggleAutoAdvance;
  final VoidCallback? onSuppressAutoAdvance;

  @override
  ConsumerState<_Overlay> createState() => __OverlayState();
}

sealed class _OverlayMode {
  const _OverlayMode();
}

class _OverlayForbiddenMode extends _OverlayMode {
  const _OverlayForbiddenMode();
}

class _OverlayAgeRestrictedMode extends _OverlayMode {
  const _OverlayAgeRestrictedMode();
}

class _OverlayContentWarningMode extends _OverlayMode {
  const _OverlayContentWarningMode(this.labels);

  final List<String> labels;
}

class _OverlayInteractiveMode extends _OverlayMode {
  const _OverlayInteractiveMode({required this.isReady});

  final bool isReady;
}

class __OverlayState extends ConsumerState<_Overlay> {
  final _heartTrigger = ValueNotifier<HeartTrigger?>(null);
  int _heartTriggerId = 0;
  InfiniteVideoFeedState? _feedState;
  ValueListenable<double>? _pagePositionListenable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedState = context.findAncestorStateOfType<InfiniteVideoFeedState>();
    _pagePositionListenable = _feedState?.pagePositionListenable;
  }

  @override
  void dispose() {
    _heartTrigger.dispose();
    super.dispose();
  }

  void _handleDoubleTapLike(BuildContext context, TapDownDetails details) {
    final showWarning = shouldShowContentWarningOverlay(
      contentWarningLabels: widget.video.contentWarningLabels,
      warnLabels: widget.video.warnLabels,
    );
    if (showWarning && !widget.contentWarningRevealed) return;

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
    widget.onSuppressAutoAdvance?.call();

    if (widget.controller != null) {
      if (widget.controller!.state.isPaused) {
        widget.controller!.play();
      } else {
        widget.controller!.pause();
      }
    }
  }

  /// Advances the feed to the next page via the cached
  /// [InfiniteVideoFeedState] reference.
  void _skipToNextVideo() {
    final feedState = _feedState;
    assert(
      feedState != null,
      'ModeratedContentOverlay must be mounted inside InfiniteVideoFeed',
    );
    if (feedState == null) return;
    unawaited(feedState.animateToPage(widget.index + 1));
  }

  /// Triggers age verification and retries playback with viewer auth.
  Future<void> _verifyAgeForVideo() async {
    await retryAgeRestrictedPooledVideo(
      context: context,
      ref: ref,
      video: widget.video,
      index: widget.index,
      retryPlayback: (httpHeaders) =>
          _feedState?.retryAt(widget.index, httpHeaders: httpHeaders) ??
          Future.value(false),
    );
  }

  _OverlayMode _resolveOverlayMode({
    required PlaybackStatus playbackStatus,
    required List<String> overlayLabels,
    required bool showContentWarningOverlay,
    required bool isReady,
  }) {
    return switch (playbackStatus) {
      PlaybackStatus.forbidden => const _OverlayForbiddenMode(),
      PlaybackStatus.ageRestricted => const _OverlayAgeRestrictedMode(),
      _ =>
        showContentWarningOverlay && !widget.contentWarningRevealed
            ? _OverlayContentWarningMode(overlayLabels)
            : _OverlayInteractiveMode(isReady: isReady),
    };
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final pagePositionListenable = _pagePositionListenable;

    // Keep the BlocProvider keyed by repository identities. #3503.
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);
    final addressableId = video.addressableId;

    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == widget.video.pubkey;

    // Subscribe to Auto state so the items rebuild when the rail is
    // toggled / suppressed / resumed.
    final autoState = context.watch<FeedAutoAdvanceCubit>().state;

    // Gate the rail + runtime on both the feature flag and the
    // user's reduced-motion preference. When Auto is unavailable,
    // force it "off" at the view layer regardless of cubit state.
    final autoAdvanceAvailable = !MediaQuery.disableAnimationsOf(context);
    final effectiveAutoEnabled = autoAdvanceAvailable && autoState.enabled;

    final overlayLabels = contentWarningOverlayLabels(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );
    final showContentWarningOverlay = shouldShowContentWarningOverlay(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );

    final effectiveAutoActive =
        autoAdvanceAvailable && autoState.isEffectivelyActive;

    final playbackStatus = context.select(
      (VideoPlaybackStatusCubit cubit) => cubit.state.statusFor(video.id),
    );

    final isReady =
        widget.controller != null &&
        widget.controller?.state.isFirstFrameRendered == true &&
        widget.controller?.state.hasError == false;
    final mode = _resolveOverlayMode(
      playbackStatus: playbackStatus,
      overlayLabels: overlayLabels,
      showContentWarningOverlay: showContentWarningOverlay,
      isReady: isReady,
    );

    switch (mode) {
      case _OverlayForbiddenMode():
        return ModeratedContentOverlay(
          status: playbackStatus,
          onSkip: _skipToNextVideo,
        );
      case _OverlayAgeRestrictedMode():
        return ModeratedContentOverlay(
          status: playbackStatus,
          onSkip: _skipToNextVideo,
          onVerifyAge: _verifyAgeForVideo,
        );
      case _OverlayContentWarningMode(:final labels):
        return ContentWarningBlurOverlay(
          labels: labels,
          onReveal: widget.onContentWarningRevealed,
          onHideSimilar: () {
            hideContentWarningsLikeThese(
              context: context,
              ref: ref,
              labels: labels,
            );
          },
        );
      case _OverlayInteractiveMode(isReady: final interactiveReady):
        return FeedAutoAdvancePastErrorListener(
          videoId: video.id,
          isActive: widget.isActive,
          isAutoAdvanceActive: effectiveAutoActive,
          onSkipBrokenVideo: _skipToNextVideo,
          child: BlocProvider<VideoInteractionsBloc>(
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
                    initialLikeCount: liveLikeCountSeed(video),
                    initialCommentCount: liveCommentCountSeed(video),
                    initialRepostCount: liveRepostCountSeed(video),
                  )
                  ..add(const VideoInteractionsSubscriptionRequested())
                  ..add(const VideoInteractionsFetchRequested()),
            child: Builder(
              builder: (context) {
                return Semantics(
                  button: true,
                  label: context.l10n.videoPlayerPlayVideo,
                  hint: context.l10n.videoPlayerTapHint,
                  child: GestureDetector(
                    behavior: .translucent,
                    onTap: interactiveReady ? _handlePlayerTap : null,
                    onDoubleTapDown: interactiveReady
                        ? (details) => _handleDoubleTapLike(context, details)
                        : null,
                    child: Stack(
                      children: [
                        if (widget.controller != null)
                          PausedVideoOverlay(
                            controller: widget.controller!,
                            isVisible: widget.isActive,
                          ),
                        _FeedItemActions(
                          video: video,
                          index: widget.index,
                          contextTitle: widget.contextTitle,
                          isOwnVideo: isOwnVideo,
                          autoAdvanceAvailable: autoAdvanceAvailable,
                          effectiveAutoEnabled: effectiveAutoEnabled,
                          onToggleAutoAdvance: widget.onToggleAutoAdvance,
                          onSuppressAutoAdvance: widget.onSuppressAutoAdvance,
                          subtitleLayer:
                              video.hasSubtitles && widget.controller != null
                              ? _SubtitleLayer(
                                  video: video,
                                  controller: widget.controller!,
                                )
                              : null,
                          pagePositionListenable: pagePositionListenable,
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
}

class _FeedItemActions extends StatelessWidget {
  const _FeedItemActions({
    required this.video,
    required this.index,
    required this.contextTitle,
    required this.isOwnVideo,
    required this.autoAdvanceAvailable,
    required this.effectiveAutoEnabled,
    required this.onToggleAutoAdvance,
    required this.onSuppressAutoAdvance,
    this.subtitleLayer,
    this.pagePositionListenable,
  });

  final VideoEvent video;
  final int index;
  final String? contextTitle;
  final bool isOwnVideo;
  final bool autoAdvanceAvailable;
  final bool effectiveAutoEnabled;
  final VoidCallback? onToggleAutoAdvance;
  final VoidCallback? onSuppressAutoAdvance;
  final Widget? subtitleLayer;
  final ValueListenable<double>? pagePositionListenable;

  @override
  Widget build(BuildContext context) {
    final listenable = pagePositionListenable;
    if (listenable == null) {
      return _FeedItemOverlayActions(
        video: video,
        contextTitle: contextTitle,
        isOwnVideo: isOwnVideo,
        autoAdvanceAvailable: autoAdvanceAvailable,
        effectiveAutoEnabled: effectiveAutoEnabled,
        onToggleAutoAdvance: onToggleAutoAdvance,
        onSuppressAutoAdvance: onSuppressAutoAdvance,
        subtitleLayer: subtitleLayer,
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, page, _) {
        final distance = (page - index).abs().clamp(0.0, 1.0);
        return _FeedItemOverlayActions(
          video: video,
          contextTitle: contextTitle,
          isOwnVideo: isOwnVideo,
          autoAdvanceAvailable: autoAdvanceAvailable,
          effectiveAutoEnabled: effectiveAutoEnabled,
          onToggleAutoAdvance: onToggleAutoAdvance,
          onSuppressAutoAdvance: onSuppressAutoAdvance,
          subtitleLayer: subtitleLayer,
          overlayOpacity: scrollDrivenOpacity(distance),
        );
      },
    );
  }
}

class _FeedItemOverlayActions extends StatelessWidget {
  const _FeedItemOverlayActions({
    required this.video,
    required this.contextTitle,
    required this.isOwnVideo,
    required this.autoAdvanceAvailable,
    required this.effectiveAutoEnabled,
    required this.onToggleAutoAdvance,
    required this.onSuppressAutoAdvance,
    this.subtitleLayer,
    this.overlayOpacity,
  });

  final VideoEvent video;
  final String? contextTitle;
  final bool isOwnVideo;
  final bool autoAdvanceAvailable;
  final bool effectiveAutoEnabled;
  final VoidCallback? onToggleAutoAdvance;
  final VoidCallback? onSuppressAutoAdvance;
  final Widget? subtitleLayer;
  final double? overlayOpacity;

  @override
  Widget build(BuildContext context) {
    final opacity = overlayOpacity;
    if (opacity == null) {
      return VideoOverlayActions(
        video: video,
        isVisible: true,
        isActive: true,
        hasBottomNavigation: false,
        contextTitle: contextTitle,
        isFullscreen: true,
        topOffset: isOwnVideo ? 64 : 8,
        showAutoButton: autoAdvanceAvailable,
        onInteracted: onSuppressAutoAdvance,
        subtitleLayer: subtitleLayer,
      );
    }

    return VideoOverlayActions(
      video: video,
      isVisible: true,
      isActive: true,
      overlayOpacity: opacity,
      hasBottomNavigation: false,
      contextTitle: contextTitle,
      isFullscreen: true,
      topOffset: isOwnVideo ? 64 : 8,
      showAutoButton: autoAdvanceAvailable,
      onInteracted: onSuppressAutoAdvance,
      subtitleLayer: subtitleLayer,
    );
  }
}

/// Streams player position and renders subtitle text for fullscreen feed.
class _SubtitleLayer extends StatelessWidget {
  const _SubtitleLayer({required this.video, required this.controller});

  final VideoEvent video;
  final DivineVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SubtitleCueStreamPill(
        video: video,
        positionStream: controller.stateStream
            .map((s) => s.position)
            .distinct(),
        initialPosition: controller.state.position,
      ),
    );
  }
}

/// Shows [VideoLoadingPlaceholder] initially.
///
/// If the video is still loading after the moderation-check delay, the
/// moderation API is queried via [FeedLoadingModerationCubit]. Cached
/// videos load immediately and never reach the delay, so no unnecessary
/// API calls are made. Once the moderation check returns a restricted
/// status the view switches to [PooledVideoErrorOverlay] without waiting
/// for the native player to time out with a 404.
class _FeedLoadingOrRestrictedOverlay extends ConsumerWidget {
  const _FeedLoadingOrRestrictedOverlay({
    required this.video,
    required this.index,
    required this.feedMode,
    required this.isSquare,
    required this.shouldPortraitExpand,
  });

  final VideoEvent video;
  final int index;
  final String? feedMode;
  final bool isSquare;
  final bool shouldPortraitExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the moderation service so the BlocProvider rebuilds (and the
    // captured cubit is closed and re-created) if the provider's identity
    // ever flips. The ValueKey gates the BlocProvider lifecycle on the
    // service identity. See .claude/rules/state_management.md → "Bridging
    // Riverpod-provided dependencies into BlocProvider".
    final service = ref.watch(videoModerationStatusServiceProvider);
    return BlocProvider<FeedLoadingModerationCubit>(
      key: ValueKey(service),
      create: (_) => FeedLoadingModerationCubit(
        service: service,
        explicitSha256: video.sha256,
        videoUrl: video.videoUrl,
      )..start(),
      child: _FeedLoadingOrRestrictedOverlayView(
        video: video,
        index: index,
        feedMode: feedMode,
        isSquare: isSquare,
        shouldPortraitExpand: shouldPortraitExpand,
      ),
    );
  }
}

class _FeedLoadingOrRestrictedOverlayView extends ConsumerWidget {
  const _FeedLoadingOrRestrictedOverlayView({
    required this.video,
    required this.index,
    required this.feedMode,
    required this.isSquare,
    required this.shouldPortraitExpand,
  });

  final VideoEvent video;
  final int index;
  final String? feedMode;
  final bool isSquare;
  final bool shouldPortraitExpand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRestricted = context.select(
      (FeedLoadingModerationCubit c) => c.state.isRestricted,
    );

    if (isRestricted) {
      return PooledVideoErrorOverlay(
        video: video,
        // Retry is hidden for moderation-restricted content.
        onRetry: () {},
        onVerifyAge: () => retryAgeRestrictedPooledVideo(
          context: context,
          ref: ref,
          video: video,
          index: index,
          retryPlayback: (httpHeaders) =>
              context
                  .findAncestorStateOfType<InfiniteVideoFeedState>()
                  ?.retryAt(index, httpHeaders: httpHeaders) ??
              Future.value(false),
        ),
        errorType: VideoErrorType.notFound,
        shouldPortraitExpand: shouldPortraitExpand,
        isSquare: isSquare,
      );
    }

    return VideoLoadingPlaceholder(
      videoId: video.id,
      index: index,
      feedMode: feedMode,
      thumbnailUrl: video.thumbnailUrl,
      isSquare: isSquare,
      shouldPortraitExpand: shouldPortraitExpand,
    );
  }
}
