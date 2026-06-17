// ABOUTME: Wraps PooledVideoErrorOverlay with the live "verifying age" flag
// ABOUTME: from VideoPlaybackStatusCubit plus the Verify-age retry wiring.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/screens/feed/pooled_age_restricted_retry.dart';
import 'package:openvine/widgets/video_feed_item/pooled_video_error_overlay.dart';

/// [PooledVideoErrorOverlay] wired to [VideoPlaybackStatusCubit].
///
/// Reads the transient "age-verification in flight" flag for [video] so the
/// Verify age button shows its loading state (and is disabled, blocking a
/// duplicate retry) while [retryAgeRestrictedPooledVideo] runs. This keeps the
/// cubit→overlay wiring in one place for every "Verify age" surface on the
/// pooled feed path.
class VerifyingAwareVideoErrorOverlay extends ConsumerWidget {
  const VerifyingAwareVideoErrorOverlay({
    required this.video,
    required this.index,
    required this.onRetry,
    required this.retryPlayback,
    required this.errorType,
    required this.shouldPortraitExpand,
    required this.isSquare,
    super.key,
  });

  final VideoEvent video;
  final int index;

  /// Called when the user taps Retry. Hidden for moderation-restricted content.
  final VoidCallback onRetry;

  /// Reloads playback for the retried item with the signed viewer-auth headers.
  final FutureOr<bool> Function(Map<String, String>) retryPlayback;

  final VideoErrorType? errorType;
  final bool shouldPortraitExpand;
  final bool isSquare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocSelector<
      VideoPlaybackStatusCubit,
      VideoPlaybackStatusState,
      bool
    >(
      selector: (state) => state.isVerifying(video.id),
      builder: (context, isVerifying) => PooledVideoErrorOverlay(
        video: video,
        onRetry: onRetry,
        onVerifyAge: () => retryAgeRestrictedPooledVideo(
          context: context,
          ref: ref,
          video: video,
          index: index,
          retryPlayback: retryPlayback,
        ),
        errorType: errorType,
        isVerifying: isVerifying,
        shouldPortraitExpand: shouldPortraitExpand,
        isSquare: isSquare,
      ),
    );
  }
}
