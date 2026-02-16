// ABOUTME: Riverpod provider for WatermarkDownloadService
// ABOUTME: Constructs service with MediaCacheManager and GallerySaveService dependencies

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/services/watermark_download_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'watermark_download_provider.g.dart';

/// Provides a [WatermarkDownloadService] with injected dependencies.
@riverpod
WatermarkDownloadService watermarkDownloadService(Ref ref) {
  return WatermarkDownloadService(
    mediaCache: ref.watch(mediaCacheProvider),
    gallerySaveService: ref.watch(gallerySaveServiceProvider),
  );
}
