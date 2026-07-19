import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_blurhash/src/base83.dart';
import 'package:divine_blurhash/src/color_math.dart';

/// Encodes a `width * height` RGBA pixel buffer into a BlurHash string.
///
/// [rgba] must be `width * height * 4` bytes in `[r, g, b, a, …]` order;
/// the alpha channel is ignored. [numCompX] and [numCompY] (1–9 each)
/// control the horizontal/vertical DCT component counts — more components
/// mean more detail but a longer hash and more visible DCT ringing.
///
/// Throws [ArgumentError] when the component counts are out of range or
/// [rgba] does not match `width * height * 4`.
String encodeBlurHash(
  Uint8List rgba,
  int width,
  int height, {
  int numCompX = 4,
  int numCompY = 3,
}) {
  if (numCompX < 1 || numCompX > 9 || numCompY < 1 || numCompY > 9) {
    throw ArgumentError(
      'numCompX ($numCompX) and numCompY ($numCompY) must each be 1–9',
    );
  }
  if (rgba.length != width * height * 4) {
    throw ArgumentError(
      'rgba length ${rgba.length} does not match width*height*4 '
      '(${width * height * 4})',
    );
  }

  final count = numCompX * numCompY;
  final factorsR = Float64List(count);
  final factorsG = Float64List(count);
  final factorsB = Float64List(count);
  final scale = 1.0 / (width * height);

  for (var j = 0; j < numCompY; j++) {
    for (var i = 0; i < numCompX; i++) {
      final normalisation = (i == 0 && j == 0) ? 1.0 : 2.0;
      var r = 0.0;
      var g = 0.0;
      var b = 0.0;
      for (var y = 0; y < height; y++) {
        final basisY = math.cos(math.pi * j * y / height);
        for (var x = 0; x < width; x++) {
          final basis =
              normalisation * math.cos(math.pi * i * x / width) * basisY;
          final offset = (y * width + x) * 4;
          r += basis * sRgbToLinear(rgba[offset]);
          g += basis * sRgbToLinear(rgba[offset + 1]);
          b += basis * sRgbToLinear(rgba[offset + 2]);
        }
      }
      final index = i + j * numCompX;
      factorsR[index] = r * scale;
      factorsG[index] = g * scale;
      factorsB[index] = b * scale;
    }
  }

  final buffer = StringBuffer()
    ..write(encode83((numCompX - 1) + (numCompY - 1) * 9, 1));

  final double maximumValue;
  if (count > 1) {
    var actualMax = 0.0;
    for (var i = 1; i < count; i++) {
      actualMax = math.max(actualMax, factorsR[i].abs());
      actualMax = math.max(actualMax, factorsG[i].abs());
      actualMax = math.max(actualMax, factorsB[i].abs());
    }
    final quantisedMax = math.max(
      0,
      math.min(82, (actualMax * 166 - 0.5).floor()),
    );
    maximumValue = (quantisedMax + 1) / 166.0;
    buffer.write(encode83(quantisedMax, 1));
  } else {
    maximumValue = 1.0;
    buffer.write(encode83(0, 1));
  }

  buffer.write(encode83(_encodeDc(factorsR[0], factorsG[0], factorsB[0]), 4));
  for (var i = 1; i < count; i++) {
    buffer.write(
      encode83(
        _encodeAc(factorsR[i], factorsG[i], factorsB[i], maximumValue),
        2,
      ),
    );
  }
  return buffer.toString();
}

int _encodeDc(double r, double g, double b) {
  final roundedR = linearToSRgb(r);
  final roundedG = linearToSRgb(g);
  final roundedB = linearToSRgb(b);
  return (roundedR << 16) + (roundedG << 8) + roundedB;
}

int _encodeAc(double r, double g, double b, double maximumValue) {
  int quant(double value) => math.max(
    0,
    math.min(18, (signPow(value / maximumValue, 0.5) * 9 + 9.5).floor()),
  );
  return quant(r) * 19 * 19 + quant(g) * 19 + quant(b);
}
