// ABOUTME: Video overlay for the new home feed (video_feed_page).
// ABOUTME: Displays author info, video description, and action buttons
// ABOUTME: matching the new design: Like, Comment, Repost, Share, More.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/utils/scroll_driven_opacity.dart';
import 'package:openvine/widgets/video_feed_item/content_warning_helpers.dart';
import 'package:openvine/widgets/video_feed_item/moderated_content_overlay.dart';
import 'package:openvine/widgets/video_feed_item/paused_video_play_overlay.dart';
import 'package:openvine/widgets/video_feed_item/video_author_info_section.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:unified_logger/unified_logger.dart';

/// Video overlay for the home feed matching the new design.
///
/// Layout:
/// - Bottom-left: author avatar, name, timestamp, description, audio
/// - Bottom-right: Like, Comment, Repost, Share, More ("...") buttons
/// - Full-screen blur overlay when video has content warnings (warn labels)
class FeedVideoOverlay extends ConsumerStatefulWidget {
  const FeedVideoOverlay({
    required this.video,
    required this.isActive,
    required this.pagePosition,
    required this.index,
    this.player,
    this.firstFrameFuture,
    this.listSources,
    this.onContentWarningRevealed,
    this.onInteracted,
    super.key,
  });

  final VideoEvent video;
  final bool isActive;

  /// Fractional page position from [PooledVideoFeed.onScrollOffsetChanged].
  /// Used to compute scroll-driven overlay opacity matching the fullscreen feed.
  final ValueNotifier<double> pagePosition;

  /// The index of this item in the feed, used with [pagePosition] to compute
  /// the scroll distance for opacity.
  final int index;
  final Player? player;
  final Future<void>? firstFrameFuture;
  final Set<String>? listSources;

  /// Called when the user reveals a content-warning overlay.
  final VoidCallback? onContentWarningRevealed;
  final VoidCallback? onInteracted;

  @override
  ConsumerState<FeedVideoOverlay> createState() => _FeedVideoOverlayState();
}

class _FeedVideoOverlayState extends ConsumerState<FeedVideoOverlay> {
  bool _contentWarningRevealed = false;

  /// Advances the feed to the next page by looking up the nearest
  /// [PooledVideoFeedState] ancestor and calling its public
  /// [PooledVideoFeedState.animateToPage]. Used as the Skip action on
  /// the moderated-content overlay.
  void _skipCurrentVideo(BuildContext context) {
    final feedState = context.findAncestorStateOfType<PooledVideoFeedState>();
    assert(
      feedState != null,
      'ModeratedContentOverlay must be mounted inside PooledVideoFeed',
    );
    if (feedState == null) return;
    unawaited(feedState.animateToPage(widget.index + 1));
  }

  /// Triggers age verification and retries pooled playback with viewer auth.
  Future<void> _verifyAge(BuildContext context, VideoEvent video) async {
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
    final playbackStatus = context.select(
      (VideoPlaybackStatusCubit cubit) => cubit.state.statusFor(video.id),
    );
    if (playbackStatus == PlaybackStatus.forbidden ||
        playbackStatus == PlaybackStatus.ageRestricted) {
      return ModeratedContentOverlay(
        status: playbackStatus,
        onSkip: () => _skipCurrentVideo(context),
        onVerifyAge: playbackStatus == PlaybackStatus.ageRestricted
            ? () => _verifyAge(context, video)
            : null,
      );
    }
    final overlayLabels = contentWarningOverlayLabels(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );
    final showContentWarningOverlay = shouldShowContentWarningOverlay(
      contentWarningLabels: video.contentWarningLabels,
      warnLabels: video.warnLabels,
    );

    Log.debug(
      'Feed overlay build: eventId=${video.id}, pubkey=${video.pubkey}, '
      'isActive=${widget.isActive}, hasPlayer=${widget.player != null}, '
      'hasFirstFrameFuture=${widget.firstFrameFuture != null}, '
      'hasSubtitles=${video.hasSubtitles}, '
      'hasWarning=$showContentWarningOverlay, '
      'videoUrl=${video.videoUrl}, thumbnailUrl=${video.thumbnailUrl}',
      name: 'FeedVideoOverlay',
      category: LogCategory.video,
    );

    // Content warning blur overlay takes priority over normal overlay
    if (showContentWarningOverlay && !_contentWarningRevealed) {
      return ContentWarningBlurOverlay(
        labels: overlayLabels,
        onReveal: () {
          setState(() {
            _contentWarningRevealed = true;
          });
          widget.onContentWarningRevealed?.call();
        },
        onHideSimilar: () {
          hideContentWarningsLikeThese(
            context: context,
            ref: ref,
            labels: overlayLabels,
          );
        },
      );
    }

    final hasTextContent =
        video.content.isNotEmpty ||
        (video.title != null && video.title!.isNotEmpty);

    final safeAreaBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        // Bottom gradient overlay (not scroll-faded — keeps the gradient
        // visible so the video edge is always readable).
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SizedBox(
              height: MediaQuery.of(context).size.height / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      VineTheme.backgroundColor.withValues(alpha: 0.0),
                      VineTheme.backgroundColor.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.player != null)
          PausedVideoPlayOverlay(
            player: widget.player!,
            firstFrameFuture: widget.firstFrameFuture,
            isVisible: widget.isActive,
          ),
        // Scroll-faded overlay: author info, badges, and action buttons all
        // fade together as the user swipes to the next video.
        ValueListenableBuilder<double>(
          valueListenable: widget.pagePosition,
          builder: (context, page, child) {
            final distance = (page - widget.index).abs().clamp(0.0, 1.0);
            final opacity = scrollDrivenOpacity(distance);
            return Opacity(
              opacity: opacity,
              child: IgnorePointer(ignoring: opacity < 0.01, child: child),
            );
          },
          child: Stack(
            children: [
              // Author info, captions, and description (bottom-left)
              PositionedDirectional(
                bottom: 20 + safeAreaBottom,
                start: 16,
                end: 80,
                child: VideoAuthorInfoSection(
                  video: video,
                  hasTextContent: hasTextContent,
                  player: widget.player,
                  onInteracted: widget.onInteracted,
                ),
              ),
              // Action buttons column (bottom-right)
              PositionedDirectional(
                bottom: 20 + safeAreaBottom,
                // Right inset matches the trailing inset on the home top
                // bar's More popover (12 px) so the column lines up with
                // the popover icon above it.
                end: 12,
                child: VideoOverlayActionColumn(
                  video: video,
                  onInteracted: widget.onInteracted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
