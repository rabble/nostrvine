import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:openvine/utils/image_orientation.dart';

void main() {
  group(bakeImageOrientation, () {
    Uint8List solid({required int width, required int height}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(10, 200, 40));
      return img.encodeJpg(image);
    }

    /// Splices a minimal APP1 EXIF segment carrying `Orientation = 6` into
    /// [jpeg] — "rotate 90° clockwise for display", which is how a phone
    /// stores a portrait photo.
    ///
    /// Hand-built because the package's own encoders drop the tag, so a photo
    /// with landscape pixels *and* an orientation tag cannot be produced by
    /// round-tripping through them.
    Uint8List withOrientationTag(Uint8List jpeg) {
      final exif = <int>[
        ...'Exif'.codeUnits, 0x00, 0x00,
        // TIFF header, big endian, IFD0 at offset 8.
        0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,
        0x00, 0x01, // one entry
        0x01, 0x12, // tag: Orientation
        0x00, 0x03, // type: SHORT
        0x00, 0x00, 0x00, 0x01, // count
        0x00, 0x06, 0x00, 0x00, // value 6, left-aligned in the 4-byte field
        0x00, 0x00, 0x00, 0x00, // no next IFD
      ];
      final length = exif.length + 2;
      return Uint8List.fromList([
        jpeg[0], jpeg[1], // SOI
        0xFF, 0xE1, (length >> 8) & 0xFF, length & 0xFF,
        ...exif,
        ...jpeg.sublist(2),
      ]);
    }

    test('puts a tagged photo upright in the pixels', () {
      // The renderer decodes raw bytes (Android's BitmapFactory), which drops
      // the tag — without baking, the backdrop lands 90° off in the video.
      final tagged = withOrientationTag(solid(width: 400, height: 200));

      final baked = img.decodeImage(bakeImageOrientation(tagged))!;

      expect(baked.width, 200);
      expect(baked.height, 400);
    });

    test('leaves an untagged image the way round it already is', () {
      // The counterpart: without this the previous expectation could be met by
      // rotating everything, which would break every screenshot-style pick.
      final baked = img.decodeImage(
        bakeImageOrientation(solid(width: 400, height: 200)),
      )!;

      expect(baked.width, 400);
      expect(baked.height, 200);
    });

    test('caps the longest edge of a landscape image', () {
      // A 12-megapixel pick would otherwise be decoded at full size on the
      // render thread for a backdrop that gets stretched to the frame anyway.
      final baked = img.decodeImage(
        bakeImageOrientation(
          solid(width: 4000, height: 2000),
          maxDimension: 1000,
        ),
      )!;

      expect(baked.width, 1000);
      expect(baked.height, 500);
    });

    test('caps the longest edge of a portrait image', () {
      final baked = img.decodeImage(
        bakeImageOrientation(
          solid(width: 2000, height: 4000),
          maxDimension: 1000,
        ),
      )!;

      expect(baked.width, 500);
      expect(baked.height, 1000);
    });

    test('leaves a small image alone rather than upscaling it', () {
      final baked = img.decodeImage(
        bakeImageOrientation(solid(width: 120, height: 80), maxDimension: 1000),
      )!;

      expect(baked.width, 120);
      expect(baked.height, 80);
    });

    test('returns undecodable bytes unchanged instead of throwing', () {
      // The package's format sniffing reads past the end of short input and
      // throws, so a truncated pick must not take the screen down with it.
      final garbage = Uint8List.fromList([1, 2, 3, 4]);

      expect(bakeImageOrientation(garbage), same(garbage));
    });
  });
}
