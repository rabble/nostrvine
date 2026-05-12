// ABOUTME: Error overlay for the pooled video player path.
// ABOUTME: Differentiates moderation-restricted (403), age-gated (401),
// ABOUTME: missing (404), and generic playback errors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Error overlay for videos playing through the pooled video player.
///
/// Shows different UI based on the [VideoErrorType] from the controller:
/// - [VideoErrorType.forbidden]: Shield icon + "Content restricted" (no retry)
/// - [VideoErrorType.notFound] with moderation status: Shield icon +
///   "Content restricted" (no retry)
/// - [VideoErrorType.ageRestricted]: Lock icon + "Age-restricted content" +
///   Verify Age
/// - [VideoErrorType.notFound]: Error icon + "Video not found" + Retry
/// - [VideoErrorType.generic]: Error icon + "Video playback error" + Retry
class PooledVideoErrorOverlay extends ConsumerWidget {
  const PooledVideoErrorOverlay({
    required this.video,
    required this.onRetry,
    required this.errorType,
    this.shouldPortraitExpand = true,
    this.isSquare = false,
    super.key,
  });

  final VideoEvent video;
  final VoidCallback onRetry;
  final VideoErrorType? errorType;

  /// Mirrors `InfiniteVideoFeed.shouldPortraitExpand`. When `false`, the
  /// thumbnail uses [BoxFit.contain] regardless of orientation so square
  /// or letterboxed videos are not cropped.
  final bool shouldPortraitExpand;

  /// Whether the video is square (1:1). When `true` the thumbnail uses
  /// [BoxFit.contain] to avoid stretching it across the full feed
  /// viewport.
  final bool isSquare;

  BoxFit _resolveBoxFit() {
    if (!shouldPortraitExpand) return BoxFit.contain;
    return isSquare ? BoxFit.contain : BoxFit.cover;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = errorType ?? VideoErrorType.generic;
    final shouldEnrichNotFoundWithModeration = type == VideoErrorType.notFound;
    final isDivineUrl = VideoModerationStatusService.shouldCheckModeration(
      video.videoUrl,
    );

    // For divine URLs, check moderation status to enrich 404/notFound
    // errors with moderation context.
    final sha256 = isDivineUrl && shouldEnrichNotFoundWithModeration
        ? VideoModerationStatusService.resolveSha256(
            explicitSha256: video.sha256,
            videoUrl: video.videoUrl,
          )
        : null;

    final moderationAsync = sha256 != null
        ? ref.watch(videoModerationStatusProvider(sha256))
        : null;

    final moderationStatus = moderationAsync?.whenOrNull(
      data: (status) => status,
    );
    final isModerationRestricted =
        type == VideoErrorType.forbidden ||
        (shouldEnrichNotFoundWithModeration &&
            moderationStatus != null &&
            moderationStatus.isUnavailableDueToModeration);

    final DivineIconName icon = switch ((type, isModerationRestricted)) {
      (VideoErrorType.ageRestricted, _) => DivineIconName.lockSimple,
      (VideoErrorType.notFound, true) => DivineIconName.shieldCheck,
      (VideoErrorType.notFound, false) => DivineIconName.warningCircle,
      (_, true) => DivineIconName.shieldCheck,
      _ => DivineIconName.warningCircle,
    };

    final message = switch ((type, isModerationRestricted)) {
      (VideoErrorType.ageRestricted, _) => context.l10n.videoErrorAgeRestricted,
      (VideoErrorType.notFound, true) =>
        context.l10n.videoErrorContentRestricted,
      (VideoErrorType.notFound, false) => context.l10n.videoErrorNotFound,
      (VideoErrorType.forbidden, _) => context.l10n.videoErrorContentRestricted,
      (VideoErrorType.generic, _) => context.l10n.videoErrorPlayback,
    };

    final showRetry = !isModerationRestricted;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: VineTheme.backgroundColor,
          child: video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty
              ? SizedBox.expand(
                  child: VineCachedImage(
                    imageUrl: video.thumbnailUrl!,
                    fit: _resolveBoxFit(),
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                )
              : const SizedBox.expand(),
        ),
        ColoredBox(
          color: VineTheme.scrim50,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                DivineIcon(icon: icon, color: VineTheme.whiteText, size: 48),
                Text(
                  message,
                  style: VineTheme.bodyMediumFont(),
                  textAlign: TextAlign.center,
                ),
                if (showRetry)
                  DivineButton(
                    label: context.l10n.videoErrorRetry,
                    type: DivineButtonType.tertiary,
                    size: DivineButtonSize.small,
                    onPressed: onRetry,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
