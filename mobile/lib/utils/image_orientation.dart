// ABOUTME: Bakes an image's EXIF orientation into its pixels and bounds its
// ABOUTME: size, for consumers that decode raw bytes and ignore EXIF.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest edge a normalized image is scaled down to.
///
/// Video output tops out around 1080p and a chroma-key backdrop is stretched
/// to the frame, so a 12-megapixel phone photo buys nothing but decode time
/// and memory on the render thread.
const int kMaxBackgroundImageDimension = 1920;

/// Rewrites [bytes] so the pixels are already in their display orientation,
/// scaled down to [maxDimension] on the longest edge.
///
/// A photo shot in portrait is commonly stored as landscape pixels plus an
/// EXIF orientation tag. Decoders that read raw bytes — notably Android's
/// `BitmapFactory`, which is what the renderer uses for a chroma-key
/// background — ignore that tag and show the image rotated. Baking the
/// rotation in removes the ambiguity for every consumer.
///
/// Returns [bytes] unchanged when they cannot be decoded — including when the
/// decoder throws, which it does on truncated input rather than reporting a
/// clean failure — leaving the caller's existing error handling in charge.
///
/// This is CPU-bound and decodes the whole image: call it through `compute`
/// rather than on the UI isolate.
Uint8List bakeImageOrientation(
  Uint8List bytes, {
  int maxDimension = kMaxBackgroundImageDimension,
}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // Format sniffing reads ahead of the buffer on short/corrupt input and
    // throws instead of returning null.
    return bytes;
  }
  if (decoded == null) return bytes;

  // The decoder already applies the tag and clears it; baking again is the
  // belt to that braces, and keeps this correct if that ever changes.
  final oriented = img.bakeOrientation(decoded);
  final longestEdge = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;

  final sized = longestEdge > maxDimension
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? maxDimension : null,
          height: oriented.height > oriented.width ? maxDimension : null,
          maintainAspect: true,
        )
      : oriented;

  // PNG keeps the backdrop lossless and sidesteps a second round of JPEG
  // artefacts on an image that is about to be re-encoded into the video.
  return img.encodePng(sized);
}
