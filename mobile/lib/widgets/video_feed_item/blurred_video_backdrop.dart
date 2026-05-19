import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Heavily-blurred copy of a video's poster thumbnail, stretched to
/// `BoxFit.cover` the entire fullscreen area. Painted behind the video
/// in `_PooledFullscreenItemContent` so contain-fit videos (1 × 1 /
/// landscape) sit on a diffused colour cloud derived from their own
/// first frame instead of a flat dark surface — matches the
/// Instagram / TikTok "blurred poster" look.
///
/// Cost: one image decode + one GPU blur pass via [ImageFiltered].
/// [VineCachedImage] keeps poster fetches on the shared cache path, so
/// revisiting the same video can reuse the cached thumbnail bytes.
class BlurredVideoBackdrop extends StatelessWidget {
  /// Creates a blurred backdrop from the poster thumbnail at [url].
  ///
  /// [url] should be an HTTPS URL to a thumbnail/poster image.
  /// If the image fails to load, the widget renders as empty
  /// ([SizedBox.shrink]) and lets the parent background show through.
  const BlurredVideoBackdrop({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // `ImageFiltered` applies the blur on the GPU side; `ClipRect`
      // keeps the bleeding edge of the blur kernel from leaking
      // outside the widget's box and over the surrounding chrome.
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Opacity(
          opacity: 0.5,
          child: VineCachedImage(
            imageUrl: url,
            // Fall back to nothing on error — the parent
            // [ColoredBox(VineTheme.surfaceContainerHigh)] shows through.
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
