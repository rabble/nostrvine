import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'PooledAgeRestrictedRetry';

/// Verifies access to an age-restricted pooled video, then retries playback
/// with viewer auth headers on the active pooled controller item.
Future<void> retryAgeRestrictedPooledVideo({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
  required int index,
  required FutureOr<bool> Function(Map<String, String>) retryPlayback,
}) async {
  // The pooled overlays (ModeratedContentOverlay / PooledVideoErrorOverlay)
  // emit no tap-time log of their own, so this is the only record that the
  // user actually pressed "Verify age" on the native feed path.
  Log.info(
    '🔐 [AGE-GATE] User tapped Verify age (pooled) for video ${video.id}',
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
    final videoUrl = video.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
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
    final sha256Hash = _resolveSha256(video);
    if (sha256Hash == null) {
      Log.warning(
        'Skipping age-restricted retry: cannot resolve sha256 for event '
        '${video.id}',
        name: _logName,
        category: LogCategory.video,
      );
      _showVerifyAgeFailed(context);
      return;
    }

    final headers = await ref
        .read(mediaAuthInterceptorProvider)
        .handleUnauthorizedMedia(
          context: context,
          sha256Hash: sha256Hash,
          url: videoUrl,
          serverUrl: _extractServerUrl(videoUrl),
          category: 'video',
        );
    if (!context.mounted) return;
    if (headers == null) {
      // handleUnauthorizedMedia returns null both when the viewer declines the
      // age dialog (a deliberate choice — stay silent) and when they accept but
      // the signed viewer-auth header could not be created (e.g. a remote
      // signer that failed or timed out). Distinguish the two by the persisted
      // verification flag so an auth failure isn't a silent no-op.
      final accepted = ref
          .read(ageVerificationServiceProvider)
          .isAdultContentVerified;
      if (accepted) {
        _showVerifyAgeFailed(context);
      }
      return;
    }

    // The hash-bound token authorizes any variant of the blob, so the feed
    // applies these headers to every resolved playback source
    // (optimized/HLS/raw) for the retried item.
    final playbackSucceeded = await retryPlayback(headers);
    if (!context.mounted) return;
    if (!playbackSucceeded) {
      _showVerifyAgeFailed(context);
      return;
    }

    playbackStatusCubit.report(video.id, PlaybackStatus.ready);
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

String? _resolveSha256(VideoEvent video) {
  final sha256 = video.sha256;
  if (sha256 != null && sha256.isNotEmpty) {
    return sha256;
  }

  final videoUrl = video.videoUrl;
  if (videoUrl == null || videoUrl.isEmpty) {
    return null;
  }

  return _extractSha256FromUrl(videoUrl);
}

String? _extractSha256FromUrl(String url) {
  try {
    final uri = Uri.parse(url);
    for (final segment in uri.pathSegments.reversed) {
      final cleanSegment = segment.split('.').first;
      if (cleanSegment.length == 64 &&
          RegExp(r'^[a-fA-F0-9]+$').hasMatch(cleanSegment)) {
        return cleanSegment.toLowerCase();
      }
    }
  } catch (_) {
    return null;
  }

  return null;
}

String? _extractServerUrl(String videoUrl) {
  try {
    final uri = Uri.parse(videoUrl);
    final portSuffix = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portSuffix';
  } catch (_) {
    return null;
  }
}
