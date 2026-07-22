// ABOUTME: Regenerates the Android splash density set from the xxxhdpi master
// ABOUTME: so the launch wordmark renders at one fixed dp size on every device.

// Run from `mobile/`:
//
//     dart run scripts/generate_android_launch_images.dart
//
// Why this exists: `drawable/launch_background.xml` draws the launch image with
// `android:gravity="center"`, which paints a bitmap at its *intrinsic* size —
// pixel width divided by the density bucket it was resolved from. Shipping the
// same pixels in every bucket therefore scales the wordmark by 4x between an
// mdpi and an xxxhdpi device. Each bucket has to carry the same artwork at its
// own scale factor instead.
//
// iOS is not generated here: `LaunchScreen.storyboard` pins the image view to a
// fixed point size, so its 1x/2x/3x set is already density-correct.

import 'dart:io';

import 'package:image/image.dart';

/// Canvas size the launch image occupies, in density-independent pixels.
///
/// Matches Android 12+'s icon-with-background splash canvas (240dp, artwork
/// inside the inner 160dp circle), which `values-v31/styles.xml` opts into via
/// `windowSplashScreenIconBackgroundColor`. Using the same number for the
/// legacy `windowBackground` splash makes both paths render the mark at one
/// size.
const canvasDp = 240;

/// Density buckets under `res/`, keyed by their scale factor.
const buckets = <String, double>{
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// The bucket whose file is the hand-authored master every other size is
/// resampled from — the largest, so no bucket is ever upscaled.
const masterBucket = 'xxxhdpi';

String _pathFor(String bucket) =>
    'android/app/src/main/res/drawable-$bucket/launch_image.png';

/// Scales [image] with alpha premultiplied, so averaging across the artwork's
/// anti-aliased edge cannot pull transparent pixels' RGB into the result.
Image _resamplePremultiplied(Image image, int size) {
  final premultiplied = image.clone();
  for (final pixel in premultiplied) {
    final alpha = pixel.a / 255;
    pixel.setRgba(
      (pixel.r * alpha).round(),
      (pixel.g * alpha).round(),
      (pixel.b * alpha).round(),
      pixel.a,
    );
  }

  final resized = copyResize(
    premultiplied,
    width: size,
    height: size,
    interpolation: Interpolation.average,
  );

  for (final pixel in resized) {
    if (pixel.a == 0) {
      pixel.setRgba(0, 0, 0, 0);
      continue;
    }
    final alpha = pixel.a / 255;
    pixel.setRgba(
      (pixel.r / alpha).round().clamp(0, 255),
      (pixel.g / alpha).round().clamp(0, 255),
      (pixel.b / alpha).round().clamp(0, 255),
      pixel.a,
    );
  }
  return resized;
}

void main() {
  final masterFile = File(_pathFor(masterBucket));
  if (!masterFile.existsSync()) {
    stderr.writeln('Master not found: ${masterFile.path}');
    exitCode = 1;
    return;
  }

  final master = decodePng(masterFile.readAsBytesSync());
  if (master == null) {
    stderr.writeln('Could not decode ${masterFile.path} as PNG.');
    exitCode = 1;
    return;
  }

  final expectedMaster = (canvasDp * buckets[masterBucket]!).round();
  if (master.width != expectedMaster || master.height != expectedMaster) {
    stderr.writeln(
      'Master must be ${expectedMaster}x$expectedMaster '
      '(${canvasDp}dp at ${buckets[masterBucket]}x), '
      'got ${master.width}x${master.height}.',
    );
    exitCode = 1;
    return;
  }

  for (final entry in buckets.entries) {
    if (entry.key == masterBucket) continue;
    final size = (canvasDp * entry.value).round();
    final path = _pathFor(entry.key);
    File(path).writeAsBytesSync(
      encodePng(_resamplePremultiplied(master, size)),
    );
    stdout.writeln('wrote $path (${size}x$size)');
  }
}
