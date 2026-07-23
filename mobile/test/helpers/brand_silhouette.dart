// ABOUTME: Rasterises brand artwork and compares two exports by silhouette, so
// ABOUTME: a test can pin a shipped PNG to the vector source it was cut from.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';

/// An image decoded to raw bytes.
///
/// [rgba] is `ui.ImageByteFormat.rawRgba`, i.e. **premultiplied** — only
/// pixels with `a == 255` carry their unattenuated colour.
typedef DecodedImage = ({int width, int height, Uint8List rgba});

/// Resolution two silhouettes are compared at, after each is cropped to its
/// own bounding box and scaled to fit. Comparing normalised shapes keeps the
/// check about the artwork's geometry rather than its padding or export size.
const silhouetteBox = 192;

/// Decodes an encoded image (PNG, JPEG, …) to raw premultiplied RGBA.
Future<DecodedImage> decodeRgba(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData();
  final result = (
    width: image.width,
    height: image.height,
    rgba: data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  image.dispose();
  codec.dispose();
  return result;
}

/// Rasterises [svg] at [width] pixels wide, keeping its own aspect ratio.
Future<DecodedImage> rasterizeSvg(String svg, {int width = 512}) async {
  final picture = await vg.loadPicture(SvgStringLoader(svg), null);
  final scale = width / picture.size.width;
  final height = (picture.size.height * scale).round();
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..scale(scale)
    ..drawPicture(picture.picture);
  final recordedPicture = recorder.endRecording();
  final image = await recordedPicture.toImage(width, height);
  final data = await image.toByteData();
  final result = (
    width: width,
    height: height,
    rgba: data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  image.dispose();
  recordedPicture.dispose();
  picture.picture.dispose();
  return result;
}

/// Coverage mask of the visible artwork, cropped to its bounding box and
/// area-resampled into a centred [silhouetteBox] square, so two exports of the
/// same shape line up regardless of source resolution or margins.
List<bool> normalizedSilhouette(DecodedImage image) {
  bool opaqueAt(int x, int y) =>
      image.rgba[(y * image.width + x) * 4 + 3] > 128;

  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (!opaqueAt(x, y)) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return List<bool>.filled(silhouetteBox * silhouetteBox, false);

  final boxWidth = maxX - minX + 1;
  final boxHeight = maxY - minY + 1;
  final scale = silhouetteBox / (boxWidth > boxHeight ? boxWidth : boxHeight);
  final targetWidth = (boxWidth * scale).round().clamp(1, silhouetteBox);
  final targetHeight = (boxHeight * scale).round().clamp(1, silhouetteBox);
  final offsetX = (silhouetteBox - targetWidth) ~/ 2;
  final offsetY = (silhouetteBox - targetHeight) ~/ 2;

  final mask = List<bool>.filled(silhouetteBox * silhouetteBox, false);
  for (var ty = 0; ty < targetHeight; ty++) {
    final y0 = minY + (ty * boxHeight / targetHeight).floor();
    final y1 = minY + ((ty + 1) * boxHeight / targetHeight).ceil();
    for (var tx = 0; tx < targetWidth; tx++) {
      final x0 = minX + (tx * boxWidth / targetWidth).floor();
      final x1 = minX + ((tx + 1) * boxWidth / targetWidth).ceil();
      var covered = 0;
      var total = 0;
      for (var y = y0; y < y1 && y <= maxY; y++) {
        for (var x = x0; x < x1 && x <= maxX; x++) {
          total++;
          if (opaqueAt(x, y)) covered++;
        }
      }
      if (total > 0 && covered * 2 >= total) {
        mask[(ty + offsetY) * silhouetteBox + tx + offsetX] = true;
      }
    }
  }
  return mask;
}

/// Intersection over union — 1.0 for identical silhouettes, 0.0 for disjoint.
double silhouetteOverlap(List<bool> a, List<bool> b) {
  var intersection = 0;
  var union = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] && b[i]) intersection++;
    if (a[i] || b[i]) union++;
  }
  return union == 0 ? 0 : intersection / union;
}
