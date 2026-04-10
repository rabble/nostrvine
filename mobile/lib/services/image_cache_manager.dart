// ABOUTME: Custom cache manager for network images with iOS-optimized timeout and connection settings
// ABOUTME: Prevents network image loading deadlocks by limiting concurrent connections and setting appropriate timeouts

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:openvine/services/image_cache_manager_native.dart'
    if (dart.library.html) 'package:openvine/services/image_cache_manager_web.dart'
    as platform_cache;
import 'package:unified_logger/unified_logger.dart';

class ImageCacheManager extends CacheManager {
  static const key = 'openvine_image_cache';

  static ImageCacheManager? _instance;

  factory ImageCacheManager() {
    return _instance ??= ImageCacheManager._();
  }

  ImageCacheManager._() : super(platform_cache.createCacheConfig(key));
}

// Singleton instance for easy access across the app
final openVineImageCache = ImageCacheManager();

/// Clear all cached images - useful for debugging cache-related issues
Future<void> clearImageCache() async {
  Log.info(
    '🗑️ Clearing entire image cache...',
    name: 'ImageCacheManager',
    category: LogCategory.system,
  );
  try {
    await openVineImageCache.emptyCache();
    Log.info(
      '✅ Image cache cleared successfully',
      name: 'ImageCacheManager',
      category: LogCategory.system,
    );
  } catch (e) {
    Log.error(
      '❌ Failed to clear image cache: $e',
      name: 'ImageCacheManager',
      category: LogCategory.system,
    );
  }
}
