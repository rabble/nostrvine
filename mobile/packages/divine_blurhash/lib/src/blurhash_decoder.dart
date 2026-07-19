import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_blurhash/src/base83.dart';
import 'package:divine_blurhash/src/blurhash_exception.dart';
import 'package:divine_blurhash/src/color_math.dart';

/// Decodes [blurHash] into a `width * height` RGBA pixel buffer.
///
/// The returned buffer is `[r, g, b, a, …]` with alpha fixed at 255.
///
/// [punch] scales the contrast of every AC component uniformly (it is
/// baked into `maxAc`, so it applies to the first component row and column
/// too — unlike `blurhash_dart`, which skipped them).
///
/// Throws [BlurHashDecodeException] when [blurHash] is shorter than 6
/// characters, contains a non-base83 character, or its length does not
/// match the component count declared in its size flag.
Uint8List decodeBlurHash(
  String blurHash,
  int width,
  int height, {
  double punch = 1.0,
}) {
  if (blurHash.length < 6) {
    throw BlurHashDecodeException(
      'too short: length ${blurHash.length} is below the 6-character minimum',
    );
  }

  final sizeFlag = decode83(blurHash, 0, 1);
  final numCompX = (sizeFlag % 9) + 1;
  final numCompY = (sizeFlag ~/ 9) + 1;
  final expectedLength = 4 + 2 * numCompX * numCompY;
  if (blurHash.length != expectedLength) {
    throw BlurHashDecodeException(
      'length ${blurHash.length} does not match the declared '
      '${numCompX}x$numCompY components (expected $expectedLength)',
    );
  }

  final maxAc = (decode83(blurHash, 1, 2) + 1) / 166.0 * punch;
  final dcValue = decode83(blurHash, 2, 6);

  final count = numCompX * numCompY;
  final componentsR = Float64List(count);
  final componentsG = Float64List(count);
  final componentsB = Float64List(count);
  componentsR[0] = sRgbToLinear(dcValue >> 16);
  componentsG[0] = sRgbToLinear((dcValue >> 8) & 255);
  componentsB[0] = sRgbToLinear(dcValue & 255);
  for (var i = 1; i < count; i++) {
    final value = decode83(blurHash, 4 + i * 2, 6 + i * 2);
    final quantR = value ~/ (19 * 19);
    final quantG = (value ~/ 19) % 19;
    final quantB = value % 19;
    componentsR[i] = signPow((quantR - 9) / 9, 2) * maxAc;
    componentsG[i] = signPow((quantG - 9) / 9, 2) * maxAc;
    componentsB[i] = signPow((quantB - 9) / 9, 2) * maxAc;
  }

  final pixels = Uint8List(width * height * 4);
  var offset = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var r = 0.0;
      var g = 0.0;
      var b = 0.0;
      for (var j = 0; j < numCompY; j++) {
        final basisY = math.cos(math.pi * y * j / height);
        for (var i = 0; i < numCompX; i++) {
          final basis = math.cos(math.pi * x * i / width) * basisY;
          final index = i + j * numCompX;
          r += componentsR[index] * basis;
          g += componentsG[index] * basis;
          b += componentsB[index] * basis;
        }
      }
      pixels[offset++] = linearToSRgb(r);
      pixels[offset++] = linearToSRgb(g);
      pixels[offset++] = linearToSRgb(b);
      pixels[offset++] = 255;
    }
  }
  return pixels;
}
