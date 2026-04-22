// ABOUTME: Error overlay for the pooled video player path.
// ABOUTME: Differentiates moderation-restricted (403), age-gated (401),
// ABOUTME: missing (404), and generic playback errors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

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
    super.key,
  });

  final VideoEvent video;
  final VoidCallback onRetry;
  final VideoErrorType? errorType;

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
        VideoThumbnailWidget(video: video),
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
