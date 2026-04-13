import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show HttpExceptionWithStatus;
import 'package:media_cache/media_cache.dart';

/// Global image cache singleton backed by [MediaCacheManager].
final openVineImageCache = MediaCacheManager(
  config: const MediaCacheConfig.image(cacheKey: 'openvine_image_cache'),
);

/// A wrapper around [CachedNetworkImage] that always uses
/// [openVineImageCache] as the cache manager.
///
/// Automatically evicts failed images from the cache so the next load
/// retries from the network — unless the failure is a 404, which is
/// expected (e.g. thumbnail not generated yet) and should stay cached.
class VineCachedImage extends StatelessWidget {
  const VineCachedImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeOutDuration = const Duration(milliseconds: 1000),
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      cacheManager: openVineImageCache,
      placeholder: placeholder,
      errorWidget: errorWidget != null
          ? (context, url, error) {
              _evictIfRetryable(url, error);
              return errorWidget!(context, url, error);
            }
          : null,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
    );
  }

  /// Evicts [url] from the cache unless the error is a 404.
  ///
  /// 404s are expected (thumbnail not generated yet) and should not be
  /// evicted so the cache doesn't retry on every rebuild.
  static void _evictIfRetryable(String url, Object error) {
    final is404 = error is HttpExceptionWithStatus
        ? error.statusCode == 404
        : error.toString().contains('404');
    if (!is404) {
      _evictFromCache(url);
    }
  }

  /// Evicts [url] from both the disk cache and Flutter's in-memory image
  /// cache. Best-effort — failure is silently swallowed.
  static Future<void> _evictFromCache(String url) async {
    try {
      await CachedNetworkImage.evictFromCache(
        url,
        cacheManager: openVineImageCache,
      );
    } catch (_) {
      // Best-effort — eviction failure must not crash the app.
    }
  }
}
