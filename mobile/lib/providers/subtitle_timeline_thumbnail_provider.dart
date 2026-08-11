// ABOUTME: Riverpod provider wiring the subtitle timeline's filmstrip service
// ABOUTME: to the app media cache.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/subtitle_timeline_thumbnail_service.dart';
import 'package:path/path.dart' as p;

const _cacheableVideoExtensions = <String>{
  '.mp4',
  '.mov',
  '.webm',
  '.mkv',
  '.m4v',
  '.ts',
};

/// Provides the service that fills the subtitle timeline with video frames.
final subtitleTimelineFrameLoaderProvider = Provider<TimelineFrameLoader>((
  ref,
) {
  final mediaCache = ref.watch(mediaCacheProvider);
  final service = SubtitleTimelineThumbnailService(
    downloadVideo: ({required String url, required String cacheKey}) async {
      final cached = mediaCache.getCachedFileSync(cacheKey);
      if (cached != null && cached.existsSync()) {
        final ext = p.extension(cached.path).toLowerCase();
        if (_cacheableVideoExtensions.contains(ext)) return cached;
        await mediaCache.removeCachedFile(cacheKey);
      }
      return mediaCache.cacheFile(url, key: cacheKey);
    },
    resolveVideoUrl: VideoEventAppExtensions.resolvePlayableUrl,
  );
  return service.thumbnailsFor;
});
