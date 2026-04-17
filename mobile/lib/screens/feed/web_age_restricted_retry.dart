import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/web_video_access_service.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'WebAgeRestrictedRetry';

Future<ResolvedWebVideoSource?> resolveWebAgeRestrictedPlaybackSource({
  required BuildContext context,
  required WidgetRef ref,
  required VideoEvent video,
}) async {
  final videoUrl = video.videoUrl;
  if (videoUrl == null || videoUrl.isEmpty) {
    Log.warning(
      'Skipping web age-restricted retry: missing videoUrl for event '
      '${video.id}',
      name: _logName,
      category: LogCategory.video,
    );
    return null;
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
  if (headers == null) {
    return null;
  }

  return ref
      .read(webVideoAccessServiceProvider)
      .resolveAuthenticatedPlayback(
        url: videoUrl,
        headers: headers,
        fallbackMimeType: video.mimeType,
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

  try {
    final uri = Uri.parse(videoUrl);
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
