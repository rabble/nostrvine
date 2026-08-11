// ABOUTME: Riverpod provider wiring the subtitle timeline's filmstrip service
// ABOUTME: to the app media cache.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/subtitle_timeline_thumbnail_service.dart';

/// Provides the service that fills the subtitle timeline with video frames.
final subtitleTimelineThumbnailServiceProvider =
    Provider<SubtitleTimelineThumbnailService>((ref) {
      final mediaCache = ref.watch(mediaCacheProvider);
      return SubtitleTimelineThumbnailService(
        downloadVideo: ({required String url, required String cacheKey}) async {
          final cached = mediaCache.getCachedFileSync(cacheKey);
          if (cached != null && cached.existsSync()) return cached;
          return mediaCache.cacheFile(url, key: cacheKey);
        },
      );
    });
