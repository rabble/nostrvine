import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'PooledAgeRestrictedRetry';

/// Verifies access to an age-restricted pooled video, then retries playback
/// with viewer auth headers on the active pooled controller item.
Future<void> retryAgeRestrictedPooledVideo({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
  required int index,
}) async {
  final videoUrl = video.videoUrl;
  if (videoUrl == null || videoUrl.isEmpty) {
    Log.warning(
      'Skipping age-restricted retry: missing videoUrl for event '
      '${video.id}',
      name: _logName,
      category: LogCategory.video,
    );
    return;
  }

  final headers = await ref
      .read(mediaAuthInterceptorProvider)
      .handleUnauthorizedMedia(
        context: context,
        sha256Hash: _resolveSha256(video),
        url: videoUrl,
        serverUrl: _extractServerUrl(videoUrl),
        category: 'video',
      );
  if (headers == null || !context.mounted) {
    return;
  }

  final feedController = VideoPoolProvider.maybeFeedOf(context);
  if (feedController == null) {
    Log.warning(
      'Skipping age-restricted retry: no VideoPoolProvider feed controller '
      'in context for event ${video.id}',
      name: _logName,
      category: LogCategory.video,
    );
    return;
  }

  context.read<VideoPlaybackStatusCubit>().report(
    video.id,
    PlaybackStatus.ready,
  );
  feedController.updateRequestHeadersAndRetry(index, headers);
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
