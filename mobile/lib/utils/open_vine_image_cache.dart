import 'package:flutter/painting.dart';
import 'package:media_cache/media_cache.dart';

/// Global image cache singleton backed by [MediaCacheManager].
final openVineImageCache = MediaCacheManager(
  config: const MediaCacheConfig.image(cacheKey: 'openvine_image_cache'),
);

Future<void> clearOpenVineImageCache() async {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.clear();
  imageCache.clearLiveImages();
  await openVineImageCache.clearCache();
}
