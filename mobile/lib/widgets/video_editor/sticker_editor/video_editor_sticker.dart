// ABOUTME: Sticker display widget supporting both asset and network images.
// ABOUTME: Includes memory-efficient caching based on displayed size.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' show StickerData;

/// A sticker widget that displays an image from either an asset or URL.
///
/// Supports both local assets and network images with automatic memory-efficient
/// caching based on the displayed size.
class VideoEditorSticker extends StatelessWidget {
  const VideoEditorSticker({
    required this.sticker,
    super.key,
    this.enableLimitCacheSize = true,
  });

  final StickerData sticker;

  /// Whether to limit the image cache size based on the widget's constraints.
  ///
  /// When `true` (default), the image is cached at the displayed size to reduce
  /// memory usage. Set to `false` when the image may be scaled or zoomed (e.g.,
  /// in the video editor canvas) to preserve full resolution.
  final bool enableLimitCacheSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: enableLimitCacheSize
          ? LayoutBuilder(
              builder: (_, constraints) {
                if (!constraints.hasBoundedWidth ||
                    !constraints.hasBoundedHeight) {
                  return _RawImage(sticker: sticker);
                }

                final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                final cacheWidth = (constraints.maxWidth * pixelRatio).toInt();
                final cacheHeight = (constraints.maxHeight * pixelRatio)
                    .toInt();

                return _RawImage(
                  sticker: sticker,
                  cacheWidth: cacheWidth,
                  cacheHeight: cacheHeight,
                );
              },
            )
          : _RawImage(sticker: sticker),
    );
  }
}

/// Internal widget that renders the actual sticker image.
class _RawImage extends StatelessWidget {
  const _RawImage({required this.sticker, this.cacheWidth, this.cacheHeight});

  /// The sticker data containing the image source.
  final StickerData sticker;

  /// Optional cache width in pixels for memory optimization.
  final int? cacheWidth;

  /// Optional cache height in pixels for memory optimization.
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    return sticker.networkUrl == null
        ? Image.asset(
            sticker.assetPath!,
            fit: .contain,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            errorBuilder: (context, error, stackTrace) => const _ErrorImage(),
          )
        : CachedNetworkImage(
            imageUrl: sticker.networkUrl!,
            fit: .contain,
            memCacheWidth: cacheWidth,
            memCacheHeight: cacheHeight,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (_, _, _) => const _ErrorImage(),
          );
  }
}

/// Placeholder shown when a sticker image fails to load.
class _ErrorImage extends StatelessWidget {
  const _ErrorImage();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.broken_image_outlined,
      size: 48,
      color: Colors.grey,
    );
  }
}
