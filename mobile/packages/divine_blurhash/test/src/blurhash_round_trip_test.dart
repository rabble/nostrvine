import 'dart:typed_data';

import 'package:divine_blurhash/divine_blurhash.dart';
import 'package:test/test.dart';

Uint8List _solid(int width, int height, int r, int g, int b) {
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < width * height; i++) {
    rgba[i * 4] = r;
    rgba[i * 4 + 1] = g;
    rgba[i * 4 + 2] = b;
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}

/// Builds a horizontal grayscale ramp (black at x=0 → white at x=width-1).
Uint8List _horizontalGrayRamp(int width, int height) {
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final v = (x / (width - 1) * 255).round();
      final o = (y * width + x) * 4;
      rgba[o] = v;
      rgba[o + 1] = v;
      rgba[o + 2] = v;
      rgba[o + 3] = 255;
    }
  }
  return rgba;
}

void main() {
  group('encode → decode round trip', () {
    test('a solid fill decodes back to its source colour', () {
      const sourceR = 100;
      const sourceG = 149;
      const sourceB = 237;
      // Encode at a realistic width (the service downscales to ≤128 before
      // encoding). A uniform fill still produces a tiny residual AC term
      // ∝ 1/width in the discrete DCT — negligible at this size, so the
      // decode stays within a few levels of the source on every channel.
      final hash = encodeBlurHash(
        _solid(128, 128, sourceR, sourceG, sourceB),
        128,
        128,
        numCompX: 3,
      );

      final pixels = decodeBlurHash(hash, 32, 32);
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        expect((pixels[i] - sourceR).abs(), lessThanOrEqualTo(5));
        expect((pixels[i + 1] - sourceG).abs(), lessThanOrEqualTo(5));
        expect((pixels[i + 2] - sourceB).abs(), lessThanOrEqualTo(5));
      }
    });

    test('grayscale content decodes without a colour tint', () {
      // The blurhash_dart decode bug this replaces inflated red/green in
      // every AC component, tinting grayscale ramps. Spec-correct integer
      // division keeps gray pixels gray.
      final hash = encodeBlurHash(
        _horizontalGrayRamp(64, 64),
        64,
        64,
        numCompY: 4,
      );

      final pixels = decodeBlurHash(hash, 32, 32);
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        expect(
          (r - g).abs() <= 3 && (g - b).abs() <= 3 && (r - b).abs() <= 3,
          isTrue,
          reason: 'pixel ${i ~/ 4} is tinted: r=$r g=$g b=$b',
        );
      }
    });

    test('punch scales AC contrast on the first component row', () {
      // A horizontal ramp puts almost all AC energy in the first component
      // row (j = 0, i > 0) — the row blurhash_dart's punch skipped. Ours
      // bakes punch into maxAc for every AC term, so the left↔right contrast
      // must scale with punch, not stay flat.
      final hash = encodeBlurHash(
        // Default 4×3 components — the horizontal ramp's AC lands in the
        // first component row.
        _horizontalGrayRamp(64, 64),
        64,
        64,
      );

      int horizontalContrast(double punch) {
        final pixels = decodeBlurHash(hash, 16, 16, punch: punch);
        final left = pixels[0];
        final right = pixels[(16 - 1) * 4];
        return (right - left).abs();
      }

      final soft = horizontalContrast(0.5);
      final full = horizontalContrast(1);
      expect(
        full,
        greaterThan((soft * 1.4).round()),
        reason: 'punch must scale the dominant first-row AC contrast',
      );
    });
  });
}
