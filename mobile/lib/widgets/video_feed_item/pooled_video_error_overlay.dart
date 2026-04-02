// ABOUTME: Error overlay for the pooled video player path.
// ABOUTME: Differentiates moderation-restricted (403), age-gated (401),
// ABOUTME: missing (404), and generic playback errors.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/video_moderation_status_service.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Error overlay for videos playing through the pooled video player.
///
/// Shows different UI based on the error:
/// - 403 Forbidden: Shield icon + "Content restricted" (no retry)
/// - 404 with moderation status: Shield icon + "Content restricted" (no retry)
/// - 401 Unauthorized: Lock icon + "Age-restricted content" + Retry
/// - Other: Error icon + user-friendly message + Retry
class PooledVideoErrorOverlay extends ConsumerWidget {
  const PooledVideoErrorOverlay({
    required this.video,
    required this.onRetry,
    required this.errorMessage,
    super.key,
  });

  final VideoEvent video;
  final VoidCallback onRetry;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorType = _VideoErrorType.fromMessage(errorMessage);

    // Resolve sha256 for moderation lookup on 403/404 errors.
    final sha256 = errorType.shouldCheckModeration
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
        errorType == _VideoErrorType.forbidden ||
        (moderationStatus != null &&
            moderationStatus.isUnavailableDueToModeration);

    final icon = errorType == _VideoErrorType.ageRestricted
        ? Icons.lock_outline
        : isModerationRestricted
        ? Icons.shield_outlined
        : Icons.error_outline;

    final message = errorType == _VideoErrorType.ageRestricted
        ? 'Age-restricted content'
        : isModerationRestricted
        ? 'Content restricted'
        : errorType.userMessage;

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
              children: [
                Icon(icon, color: VineTheme.whiteText, size: 48),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showRetry) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.whiteText,
                      foregroundColor: VineTheme.backgroundColor,
                    ),
                    child: Text(
                      errorType == _VideoErrorType.ageRestricted
                          ? 'Verify Age'
                          : 'Retry',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Classifies a raw error string into an actionable error type.
enum _VideoErrorType {
  /// 401 Unauthorized — age-gated content.
  ageRestricted,

  /// 403 Forbidden — moderation-restricted content.
  forbidden,

  /// 404 Not Found — may or may not be moderation-related.
  notFound,

  /// Any other playback failure.
  generic
  ;

  static _VideoErrorType fromMessage(String? message) {
    if (message == null) return generic;
    final lower = message.toLowerCase();
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return ageRestricted;
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return forbidden;
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return notFound;
    }
    return generic;
  }

  /// Whether moderation status should be checked for this error type.
  bool get shouldCheckModeration => this == forbidden || this == notFound;

  /// User-facing message for this error type.
  String get userMessage => switch (this) {
    ageRestricted => 'Age-restricted content',
    forbidden => 'Content restricted',
    notFound => 'Video not found',
    generic => 'Video playback error',
  };
}
