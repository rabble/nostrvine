import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/blossom_blob_hash.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'PooledAgeRestrictedRetry';

typedef PooledAgeRestrictedSha256Resolver =
    String? Function({String? explicitSha256, String? videoUrl});

/// Outcome of a viewer-auth playback retry.
///
/// [errorType] carries the error the player classified for the retried item
/// when [succeeded] is `false`. Only a repeated [VideoErrorType.ageRestricted]
/// proves the age gate itself is unclearable; every other failure is an
/// unrelated playback problem that must stay retryable. #6253
typedef PooledRetryOutcome = ({bool succeeded, VideoErrorType? errorType});

/// Reloads playback for the retried item with signed viewer-auth headers.
typedef PooledRetryPlayback =
    FutureOr<PooledRetryOutcome> Function(Map<String, String> httpHeaders);

/// Verifies access to an age-restricted pooled video, then retries playback
/// with viewer auth headers on the active pooled controller item.
Future<void> retryAgeRestrictedPooledVideo({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
  required int index,
  required PooledAgeRestrictedSha256Resolver resolveSha256,
  required PooledRetryPlayback retryPlayback,
}) async {
  Log.info(
    '🔐 [AGE-GATE] Starting age-restricted pooled retry for video ${video.id}',
    name: _logName,
    category: LogCategory.video,
  );

  // Drive the "Verify age" button's loading state for the whole operation so
  // the tap is never a silent wait. Captured up front (sync, pre-await) and
  // cleared in `finally` regardless of which branch exits.
  final playbackStatusCubit = context.read<VideoPlaybackStatusCubit>();
  if (playbackStatusCubit.state.isVerifying(video.id)) {
    return;
  }
  playbackStatusCubit.markVerifying(video.id);
  try {
    final retryInput = _resolveRetryInput(video, resolveSha256);
    if (retryInput == null) {
      Log.warning(
        'Skipping age-restricted retry: missing videoUrl for event '
        '${video.id}',
        name: _logName,
        category: LogCategory.video,
      );
      _showVerifyAgeFailed(context);
      return;
    }

    // BUD-01 (kind 24242) viewer auth is hash-bound: the origin authorizes any
    // variant URL of the blob, which is what lets the feed apply one header set
    // to every resolved source. Without a sha256 the auth path falls back to
    // URL-bound NIP-98, which would only authenticate the bare event URL and
    // re-401 on the optimized/HLS variants — refuse the retry instead.
    if (retryInput.sha256 == null) {
      Log.warning(
        'Skipping age-restricted retry: cannot resolve sha256 for event '
        '${video.id}',
        name: _logName,
        category: LogCategory.video,
      );
      _showVerifyAgeFailed(context);
      return;
    }

    final authResult = await ref
        .read(mediaAuthInterceptorProvider)
        .handleUnauthorizedMedia(
          context: context,
          sha256Hash: retryInput.sha256,
          url: retryInput.videoUrl,
          serverUrl: retryInput.serverUrl,
          category: 'video',
        );
    if (!context.mounted) return;

    switch (authResult) {
      case ViewerAuthAuthorized(:final headers):
        // The hash-bound token authorizes any variant of the blob, so the feed
        // applies these headers to every resolved playback source
        // (optimized/HLS/raw) for the retried item.
        final outcome = await retryPlayback(headers);
        if (!context.mounted) return;
        if (!outcome.succeeded) {
          if (!_isAuthRejection(outcome)) {
            _showVerifyAgeFailed(context);
            return;
          }
          playbackStatusCubit.markAuthRetryExhausted(video.id);
          playbackStatusCubit.report(video.id, PlaybackStatus.unavailable);
          _showVideoUnavailable(context);
          return;
        }
        playbackStatusCubit.report(video.id, PlaybackStatus.ready);
      case ViewerAuthSignerUnreachable():
        // A remote signer timed out — distinct from a verify failure, since the
        // remedy is checking the connection rather than re-verifying.
        _showSignerUnreachable(context);
      case ViewerAuthBlockedByPreference():
        // The viewer is verified but adult content is switched off in their
        // Content Filters (the default). Point them at the setting instead of
        // implying verification failed.
        _showAdultContentHidden(context);
      case ViewerAuthUnavailable():
        // Unavailable covers both a deliberate decline (stay silent) and an
        // accept-then-no-header case (surface feedback). Distinguish the two by
        // the persisted verification flag so an auth failure isn't silent.
        final accepted = ref
            .read(ageVerificationServiceProvider)
            .isAdultContentVerified;
        if (accepted) {
          _showVerifyAgeFailed(context);
        }
    }
  } finally {
    if (!playbackStatusCubit.isClosed) {
      playbackStatusCubit.clearVerifying(video.id);
    }
  }
}

/// Silently retries pooled age-restricted playback when the viewer's existing
/// preferences already allow adult media to play without prompting.
Future<void> autoRetryAgeRestrictedPooledVideo({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
  required int index,
  required PooledAgeRestrictedSha256Resolver resolveSha256,
  required PooledRetryPlayback retryPlayback,
}) async {
  final mediaAuthInterceptor = ref.read(mediaAuthInterceptorProvider);
  if (!mediaAuthInterceptor.canAutoAuthorizeAdultMedia) return;

  final retryInput = _resolveRetryInput(video, resolveSha256);
  if (retryInput == null || retryInput.sha256 == null) return;

  final playbackStatusCubit = context.read<VideoPlaybackStatusCubit>();
  if (playbackStatusCubit.state.isVerifying(video.id)) return;

  playbackStatusCubit.markVerifying(video.id);
  try {
    final authResult = await mediaAuthInterceptor
        .createAutoAuthHeadersForAdultMedia(
          sha256Hash: retryInput.sha256,
          url: retryInput.videoUrl,
          serverUrl: retryInput.serverUrl,
        );
    if (!context.mounted) return;

    switch (authResult) {
      case ViewerAuthAuthorized(:final headers):
        final outcome = await retryPlayback(headers);
        if (!context.mounted) return;
        if (!outcome.succeeded) {
          if (!_isAuthRejection(outcome)) return;
          playbackStatusCubit.markAuthRetryExhausted(video.id);
          playbackStatusCubit.report(video.id, PlaybackStatus.unavailable);
          return;
        }
        playbackStatusCubit.report(video.id, PlaybackStatus.ready);
      case ViewerAuthSignerUnreachable():
      case ViewerAuthBlockedByPreference():
      case ViewerAuthUnavailable():
        break;
    }
  } finally {
    if (!playbackStatusCubit.isClosed) {
      playbackStatusCubit.clearVerifying(video.id);
    }
  }
}

/// Surfaces a localized failure so a tapped "Verify age" button is never a
/// silent no-op when verification can't complete.
void _showVerifyAgeFailed(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(context.l10n.videoErrorVerifyAgeFailed),
  );
}

/// Surfaces a neutral unavailable message after valid auth was rejected.
///
/// Uses the body copy rather than the title so the snackbar reads as a
/// sentence instead of repeating the overlay heading verbatim.
void _showVideoUnavailable(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(context.l10n.videoErrorUnavailableBody),
  );
}

/// Whether a failed retry was the media server rejecting the signed request
/// again, rather than an unrelated playback failure on the same reload.
///
/// A network drop, decode failure, or timeout also fails the retry, and
/// treating those as an exhausted age gate would strand a recoverable video
/// as permanently unavailable for the rest of the session.
bool _isAuthRejection(PooledRetryOutcome outcome) =>
    outcome.errorType == VideoErrorType.ageRestricted;

/// Tells an age-verified viewer that adult content is switched off in their
/// Content Filters, so they know where to opt in rather than re-verifying.
void _showAdultContentHidden(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(context.l10n.videoErrorAdultContentHidden),
  );
}

/// Surfaces the connectivity-specific message when a remote signer didn't
/// respond in time, so the viewer knows to check their connection rather than
/// re-verify their age.
void _showSignerUnreachable(BuildContext context) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    DivineSnackbarContainer.snackBar(
      context.l10n.videoErrorVerifyAgeSignerUnreachable,
    ),
  );
}

_PooledRetryInput? _resolveRetryInput(
  VideoEvent video,
  PooledAgeRestrictedSha256Resolver resolveSha256,
) {
  final videoUrl = video.videoUrl;
  if (videoUrl == null || videoUrl.isEmpty) {
    return null;
  }

  return _PooledRetryInput(
    videoUrl: videoUrl,
    sha256: resolveSha256(explicitSha256: video.sha256, videoUrl: videoUrl),
    serverUrl: extractMediaServerUrl(videoUrl),
  );
}

class _PooledRetryInput {
  const _PooledRetryInput({
    required this.videoUrl,
    required this.sha256,
    required this.serverUrl,
  });

  final String videoUrl;
  final String? sha256;
  final String? serverUrl;
}
