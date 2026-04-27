// ABOUTME: Riverpod wiring for importing classic Vines into the clip library.
// ABOUTME: Keeps the import service testable while using app cache and storage services.

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/classic_vine_clip_import_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'classic_vine_clip_import_provider.g.dart';

@riverpod
ClassicVineClipImportService classicVineClipImportService(Ref ref) {
  final mediaCache = ref.watch(mediaCacheProvider);

  return ClassicVineClipImportService(
    clipLibraryService: ref.watch(clipLibraryServiceProvider),
    getDocumentsPath: getDocumentsPath,
    downloadVideo: ({required String url, required String cacheKey}) async {
      final cached = mediaCache.getCachedFileSync(cacheKey);
      if (cached != null && cached.existsSync()) return cached;
      return mediaCache.cacheFile(url, key: cacheKey);
    },
    extractThumbnail: ({required videoPath, required targetTimestamp}) async {
      final result = await VideoThumbnailService.extractThumbnail(
        videoPath: videoPath,
        targetTimestamp: targetTimestamp,
      );
      if (result == null) return null;
      return ClassicVineThumbnail(
        path: result.path,
        timestamp: result.timestamp,
      );
    },
    extractLastFrame: VideoThumbnailService.extractLastFrame,
  );
}
