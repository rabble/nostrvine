import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Diffused colour cloud derived from a video's own first frame,
/// stretched to cover the entire fullscreen area. Painted behind the
/// video in `_PooledFullscreenItemContent` so contain-fit videos
/// (1 × 1 / landscape) sit on it instead of a flat dark surface —
/// matches the Instagram / TikTok "blurred poster" look.
///
/// When the video carries a [blurhash], the backdrop renders the decoded
/// 32 × 32 blurhash bilinearly stretched — visually equivalent to a heavy
/// gaussian blur of the poster at zero per-frame raster cost. The
/// runtime-blur fallback ([ImageFiltered], sigma 30) only runs for videos
/// without a blurhash; that fullscreen blur pass over the live video
/// texture was a major raster-thread cost (on-device: Impeller janked
/// every frame), so the blurhash path is strongly preferred.
class BlurredVideoBackdrop extends StatelessWidget {
  /// Creates a blurred backdrop for a video poster.
  ///
  /// [blurhash] is preferred when non-empty. [url] is the HTTPS poster
  /// thumbnail used for the runtime-blur fallback; when neither is
  /// available, or the image fails to load, the widget renders as empty
  /// ([SizedBox.shrink]) and lets the parent background show through.
  const BlurredVideoBackdrop({super.key, this.url, this.blurhash});

  final String? url;
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    final hash = blurhash;
    if (hash != null && hash.isNotEmpty) {
      // Paint-level 50% alpha — no Opacity saveLayer, no blur pass.
      return BlurhashDisplay(blurhash: hash, opacity: 0.5);
    }
    final posterUrl = url;
    if (posterUrl == null || posterUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRect(
      // `ImageFiltered` applies the blur on the GPU side; `ClipRect`
      // keeps the bleeding edge of the blur kernel from leaking
      // outside the widget's box and over the surrounding chrome.
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Opacity(
          opacity: 0.5,
          child: VineCachedImage(
            imageUrl: posterUrl,
            // Fall back to nothing on error — the parent
            // [ColoredBox(VineTheme.surfaceContainerHigh)] shows through.
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
