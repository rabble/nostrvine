import 'dart:typed_data';

import 'package:divine_blurhash/divine_blurhash.dart';
import 'package:test/test.dart';

/// 8x8 field with distinct per-channel structure: r ramps horizontally,
/// g vertically, b diagonally. Any channel-order mistake changes its hash.
Uint8List _colourField() {
  final rgba = Uint8List(8 * 8 * 4);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final o = (y * 8 + x) * 4;
      rgba[o] = x * 32;
      rgba[o + 1] = y * 32;
      rgba[o + 2] = (x + y) * 16;
      rgba[o + 3] = 255;
    }
  }
  return rgba;
}

/// 32x32 hard vertical black/white split. Its dominant AC factor is the
/// square wave's fundamental, ~2/pi ~ 0.64 — overshooting maxAc (83/166),
/// so encoding it drives the quantised-maxAc ceiling (82) and, depending
/// on the overshooting term's sign, one of the AC quantisation clamps:
/// black-left makes it negative (lower clamp, 0), white-left makes it
/// positive (upper clamp, 18).
Uint8List _halfSplit({required bool blackLeft}) {
  final rgba = Uint8List(32 * 32 * 4);
  for (var y = 0; y < 32; y++) {
    for (var x = 0; x < 32; x++) {
      final o = (y * 32 + x) * 4;
      final v = (x < 16) == blackLeft ? 0 : 255;
      rgba[o] = v;
      rgba[o + 1] = v;
      rgba[o + 2] = v;
      rgba[o + 3] = 255;
    }
  }
  return rgba;
}

void main() {
  group('reference vectors', () {
    // The expected values below were computed with an independent
    // implementation of the woltapp/blurhash reference algorithm, not
    // with this package. Round-trip tests cannot catch a symmetric
    // encode/decode convention error (it round-trips cleanly here while
    // every other client renders the hash wrong); pinning the exact
    // wire format keeps the README's cross-client interop claim
    // falsifiable.
    test(
      'encodes a channel-distinguishing colour field to the exact '
      'reference hash',
      () {
        // Default components (4x3).
        expect(
          encodeBlurHash(_colourField(), 8, 8),
          'LjF={q31a^xuumRofSnPf4fSfRfP',
        );
      },
    );

    test(
      'clamps quantised maxAc (82) and AC terms (18) on a hard '
      'black/white split',
      () {
        // Default components (4x3). Without the 82 ceiling the maxAc
        // character changes; without the AC clamps the overshooting
        // AC pairs change (lower clamp on the black-left split, upper
        // clamp on the white-left one).
        final blackLeft = encodeBlurHash(
          _halfSplit(blackLeft: true),
          32,
          32,
        );
        expect(blackLeft, 'L~Lqe900Rj-;ofWBayj[fQfQfQfQ');
        expect(
          blackLeft[1],
          '~',
          reason: 'maxAc must clamp to base83 index 82',
        );

        final whiteLeft = encodeBlurHash(
          _halfSplit(blackLeft: false),
          32,
          32,
        );
        expect(whiteLeft, 'L~Lqe9~qt7IUofofj[ayfQfQfQfQ');
      },
    );

    test(
      'decodes the canonical woltapp example hash to reference pixel '
      'values',
      () {
        final pixels = decodeBlurHash('LEHV6nWB2yk8pyo0adR*.7kCMdnj', 8, 8);
        (int, int, int) rgbAt(int x, int y) {
          final o = (y * 8 + x) * 4;
          return (pixels[o], pixels[o + 1], pixels[o + 2]);
        }

        expect(rgbAt(0, 0), (135, 164, 177));
        expect(rgbAt(7, 0), (144, 167, 179));
        expect(rgbAt(0, 7), (134, 144, 148));
        expect(rgbAt(7, 7), (140, 144, 145));
        expect(rgbAt(3, 4), (154, 126, 118));
      },
    );
  });
}
