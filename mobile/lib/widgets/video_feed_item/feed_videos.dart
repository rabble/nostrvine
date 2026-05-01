import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart'
    hide PlaybackStatus;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/feed/feed_auto_advance_coordinator.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/screens/feed/feed_auto_advance_error_listener.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_heart_overlay.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_overlay.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
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

  @override
  ConsumerState<FeedVideos> createState() => FeedVideosState();
}

class FeedVideosState extends ConsumerState<FeedVideos> with RouteAware {
  final FeedAutoAdvanceCubit _autoAdvanceCubit = FeedAutoAdvanceCubit();
  final _feedKey = GlobalKey<InfiniteVideoFeedState>();

  /// Animates the underlying feed to [index].
  ///
  /// Used by parent screens that hold a [GlobalKey<FeedVideosState>] to
  /// programmatically skip to a specific video (e.g. after a 404 removal).
  Future<void> animateToPage(int index) =>
      _feedKey.currentState?.animateToPage(index) ?? Future.value();

  @override
  void didUpdateWidget(covariant FeedVideos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _feedKey.currentState?.resumeActive();
      } else {
        _feedKey.currentState?.pauseActive();
      }
    }
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
    unawaited(_autoAdvanceCubit.close());
    super.dispose();
  }

  @override
  void didPushNext() {
    _feedKey.currentState?.pauseActive();
  }

  @override
  void didPopNext() {
    _feedKey.currentState?.resumeActive();
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
    return BlocProvider.value(
      value: _autoAdvanceCubit,
      child: BlocListener<VideoVolumeCubit, VideoVolumeState>(
        // Sync volume when hardware buttons change system volume.
        listener: (_, state) {
          _feedKey.currentState?.setVolume(state.volume);
        },
        child: InfiniteVideoFeed(
          key: _feedKey,
          videos: widget.videos,
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

            // Capture the cubit eagerly so the post-frame callback doesn't
            // walk the ancestor tree on a potentially-deactivated element.
            final cubit = context.read<VideoPlaybackStatusCubit>();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              cubit.report(video.id, playbackStatusFromError(errorType));
            });
            // Mirror the BoxFit logic of VideoLoadingPlaceholder /
            // VideoItemWidget so the error thumbnail respects the same
            // square / portrait-expand rules as the live video.
            final width = video.width;
            final height = video.height;
            final isSquare = width != null && height != null && width == height;
            return PooledVideoErrorOverlay(
              video: video,
              onRetry: onRetry,
              errorType: errorType,
              shouldPortraitExpand: widget.shouldPortraitExpand,
              isSquare: isSquare,
            );
          },
          overlayBuilder:
              (context, index, controller, {required bool isActive}) {
                if (index < 0 || index >= widget.videos.length) {
                  return const SizedBox.shrink();
                }
                return _Overlay(
                  controller: controller,
                  video: widget.videos[index],
                  index: index,
                  isActive: isActive,
                  contextTitle: widget.contextTitle,
                  onToggleAutoAdvance: _toggleAutoAdvance,
                  onSuppressAutoAdvance: _suppressAutoAdvance,
                );
              },
        ),
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
    this.onToggleAutoAdvance,
    this.onSuppressAutoAdvance,
  });

  final String? contextTitle;
  final DivineVideoPlayerController? controller;
  final VideoEvent video;
  final int index;
  final bool isActive;
  final VoidCallback? onToggleAutoAdvance;
  final VoidCallback? onSuppressAutoAdvance;

  @override
  ConsumerState<_Overlay> createState() => __OverlayState();
}

class __OverlayState extends ConsumerState<_Overlay> {
  final _heartTrigger = ValueNotifier<HeartTrigger?>(null);
  int _heartTriggerId = 0;

  void _handleDoubleTapLike(BuildContext context, TapDownDetails details) {
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
    widget.onSuppressAutoAdvance?.call();

    if (widget.controller != null) {
      if (widget.controller!.state.isPaused) {
        widget.controller!.play();
      } else {
        widget.controller!.pause();
      }
    }
  }

  bool _contentWarningRevealed = false;

  /// Advances the feed to the next page by finding the nearest
  /// [InfiniteVideoFeedState] ancestor and calling its public
  /// [InfiniteVideoFeedState.animateToPage].
  void _skipToNextVideo() {
    final feedState = context.findAncestorStateOfType<InfiniteVideoFeedState>();
    assert(
      feedState != null,
      'ModeratedContentOverlay must be mounted inside InfiniteVideoFeed',
    );
    if (feedState == null) return;
    unawaited(feedState.animateToPage(widget.index + 1));
  }

  /// Triggers age verification and retries pooled playback with viewer auth.
  Future<void> _verifyAgeForVideo() async {
    await retryAgeRestrictedPooledVideo(
      context: context,
      ref: ref,
      video: widget.video,
      index: widget.index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;

    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

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
    if (playbackStatus == .forbidden || playbackStatus == .ageRestricted) {
      return ModeratedContentOverlay(
        status: playbackStatus,
        onSkip: _skipToNextVideo,
        onVerifyAge: playbackStatus == .ageRestricted
            ? _verifyAgeForVideo
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
    final isReady =
        widget.controller != null &&
        widget.controller?.state.isFirstFrameRendered == true &&
        widget.controller?.state.hasError == false;

    return FeedAutoAdvancePastErrorListener(
      videoId: video.id,
      isActive: widget.isActive,
      isAutoAdvanceActive: effectiveAutoActive,
      onSkipBrokenVideo: _skipToNextVideo,
      child: BlocProvider<VideoInteractionsBloc>(
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
        child: Builder(
          builder: (context) {
            return Semantics(
              button: true,
              hint: isReady
                  ? 'Tap to play or pause. Double tap to like.'
                  : null,
              child: GestureDetector(
                behavior: .translucent,
                onTap: isReady ? _handlePlayerTap : null,
                onDoubleTapDown: isReady
                    ? (details) => _handleDoubleTapLike(context, details)
                    : null,
                child: Stack(
                  children: [
                    if (widget.controller != null) ...[
                      PausedVideoOverlay(
                        controller: widget.controller!,
                        isVisible: widget.isActive,
                        onVolumeToggle: (v) => context
                            .findAncestorStateOfType<InfiniteVideoFeedState>()
                            ?.setVolume(v),
                      ),
                    ],
                    VideoOverlayActions(
                      video: video,
                      isVisible: true,
                      isActive: true,
                      hasBottomNavigation: false,
                      contextTitle: widget.contextTitle,
                      isFullscreen: true,
                      topOffset: isOwnVideo ? 64 : 8,
                      showAutoButton: autoAdvanceAvailable,
                      isAutoEnabled: effectiveAutoEnabled,
                      onAutoPressed: widget.onToggleAutoAdvance,
                      onInteracted: widget.onSuppressAutoAdvance,
                      subtitleLayer: video.hasSubtitles &&
                              widget.controller != null
                          ? _SubtitleLayer(
                              video: video,
                              controller: widget.controller!,
                            )
                          : null,
                    ),
                    Positioned.fill(
                      child: DoubleTapHeartOverlay(
                        trigger: _heartTrigger,
                      ),
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

/// Streams player position and renders subtitle text for fullscreen feed.
class _SubtitleLayer extends ConsumerWidget {
  const _SubtitleLayer({required this.video, required this.controller});

  final VideoEvent video;
  final DivineVideoPlayerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitlesVisible = ref.watch(subtitleVisibilityProvider);

    return Padding(
      padding: const .only(bottom: 24),
      child: StreamBuilder<int>(
        stream: controller.stateStream
            .map((s) => s.position.inMilliseconds)
            .distinct(),
        builder: (context, snapshot) {
          final positionMs = snapshot.data ?? 0;
          return SubtitleOverlay(
            video: video,
            positionMs: positionMs,
            visible: subtitlesVisible,
            enablePositioned: false,
            bottomOffset: 0,
          );
        },
      ),
    );
  }
}

/// Shows [VideoLoadingPlaceholder] initially.
///
/// If the video is still loading after [_kModerationCheckDelay], the
/// moderation API is queried. Cached videos load immediately and never
/// reach the delay, so no unnecessary API calls are made. Once the
/// moderation check returns a restricted status the overlay switches to
/// [PooledVideoErrorOverlay] without waiting for the native player to
/// time out with a 404.
class _FeedLoadingOrRestrictedOverlay extends ConsumerStatefulWidget {
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
  ConsumerState<_FeedLoadingOrRestrictedOverlay> createState() =>
      _FeedLoadingOrRestrictedOverlayState();
}

class _FeedLoadingOrRestrictedOverlayState
    extends ConsumerState<_FeedLoadingOrRestrictedOverlay> {
  static const _kModerationCheckDelay = Duration(seconds: 2);

  Timer? _timer;
  bool _checkModeration = false;

  @override
  void initState() {
    super.initState();
    final shouldCheck = VideoModerationStatusService.shouldCheckModeration(
      widget.video.videoUrl,
    );
    if (shouldCheck) {
      final sha256 = VideoModerationStatusService.resolveSha256(
        explicitSha256: widget.video.sha256,
        videoUrl: widget.video.videoUrl,
      );
      if (sha256 != null) {
        _timer = Timer(_kModerationCheckDelay, () {
          if (mounted) setState(() => _checkModeration = true);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkModeration) {
      final sha256 = VideoModerationStatusService.resolveSha256(
        explicitSha256: widget.video.sha256,
        videoUrl: widget.video.videoUrl,
      );
      if (sha256 != null) {
        final isRestricted =
            ref
                .watch(videoModerationStatusProvider(sha256))
                .whenOrNull(
                  data: (status) =>
                      status?.isUnavailableDueToModeration ?? false,
                ) ??
            false;
        if (isRestricted) {
          return PooledVideoErrorOverlay(
            video: widget.video,
            // Retry is hidden for moderation-restricted content.
            onRetry: () {},
            errorType: VideoErrorType.notFound,
            shouldPortraitExpand: widget.shouldPortraitExpand,
            isSquare: widget.isSquare,
          );
        }
      }
    }

    return VideoLoadingPlaceholder(
      videoId: widget.video.id,
      index: widget.index,
      feedMode: widget.feedMode,
      thumbnailUrl: widget.video.thumbnailUrl,
      isSquare: widget.isSquare,
      shouldPortraitExpand: widget.shouldPortraitExpand,
    );
  }
}
