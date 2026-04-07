// ABOUTME: Sticker display widget supporting both SVG assets and network images.
// ABOUTME: SVG assets render as vectors; network images use cached raster rendering.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/widgets/vine_cached_image.dart';

/// A sticker widget that displays an image from either an asset or URL.
///
/// Local asset stickers are rendered as SVGs using [SvgPicture.asset].
/// Network stickers are rendered as raster images with caching.
class VideoEditorSticker extends StatelessWidget {
  const VideoEditorSticker({
    required this.sticker,
    super.key,
    this.enableLimitCacheSize = true,
  });

  final StickerData sticker;

  /// Whether to limit the image cache size based on the widget's constraints.
  ///
  /// When `true` (default), network images are cached at the displayed size to
  /// reduce memory usage. This has no effect on SVG assets, which are
  /// resolution-independent. Set to `false` when the image may be scaled or
  /// zoomed (e.g., in the video editor canvas) to preserve full resolution.
  final bool enableLimitCacheSize;

  @override
  Widget build(BuildContext context) {
    // SVG assets don't need raster cache sizing.
    if (sticker.networkUrl == null) {
      return Center(child: _SvgAssetImage(sticker: sticker));
    }

    return Center(
      child: enableLimitCacheSize
          ? LayoutBuilder(
              builder: (_, constraints) {
                if (!constraints.hasBoundedWidth ||
                    !constraints.hasBoundedHeight) {
                  return _NetworkImage(sticker: sticker);
                }

                final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                final cacheWidth = (constraints.maxWidth * pixelRatio).toInt();
                final cacheHeight = (constraints.maxHeight * pixelRatio)
                    .toInt();

                return _NetworkImage(
                  sticker: sticker,
                  cacheWidth: cacheWidth,
                  cacheHeight: cacheHeight,
                );
              },
            )
          : _NetworkImage(sticker: sticker),
    );
  }
}

/// Renders a local SVG asset sticker.
class _SvgAssetImage extends StatelessWidget {
  const _SvgAssetImage({required this.sticker});

  final StickerData sticker;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(sticker.assetPath!);
  }
}

/// Renders a network sticker image with optional cache sizing.
class _NetworkImage extends StatelessWidget {
  const _NetworkImage({
    required this.sticker,
    this.cacheWidth,
    this.cacheHeight,
  });

  final StickerData sticker;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    return VineCachedImage(
      imageUrl: sticker.networkUrl!,
      fit: BoxFit.contain,
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
      color: VineTheme.lightText,
    );
  }
}
