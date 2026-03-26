// ABOUTME: Unit tests for ExifUtil EXIF metadata stripping
// ABOUTME: Verifies GPS and device metadata is removed from JPEG before upload

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:openvine/utils/exif_util.dart';

/// Creates a minimal JPEG with EXIF data containing GPS and device metadata.
Uint8List _createJpegWithExif() {
  final image = img.Image(width: 2, height: 2);

  // Add GPS EXIF data
  image.exif.gpsIfd[0x0001] = img.IfdValueAscii('N'); // GPSLatitudeRef
  image.exif.gpsIfd[0x0003] = img.IfdValueAscii('W'); // GPSLongitudeRef

  // Add device info
  image.exif.imageIfd[0x010F] = img.IfdValueAscii('TestDevice'); // Make
  image.exif.imageIfd[0x0110] = img.IfdValueAscii('TestModel'); // Model

  return Uint8List.fromList(img.encodeJpg(image));
}

/// Creates a minimal JPEG without any EXIF data.
Uint8List _createJpegWithoutExif() {
  final image = img.Image(width: 2, height: 2);
  // Encode without adding any EXIF — the encoder skips APP1 when exif is empty
  final encoded = img.encodeJpg(image);
  return Uint8List.fromList(encoded);
}

void main() {
  group(ExifUtil, () {
    group('stripJpegExif', () {
      test('strips GPS and device EXIF from JPEG', () {
        final jpegWithExif = _createJpegWithExif();

        // Verify EXIF is present before stripping
        final exifBefore = img.decodeJpgExif(jpegWithExif);
        expect(exifBefore, isNotNull);
        expect(exifBefore!.imageIfd.values, isNotEmpty);

        // Strip EXIF
        final stripped = ExifUtil.stripJpegExif(jpegWithExif);

        // Verify EXIF is absent after stripping
        final exifAfter = img.decodeJpgExif(stripped);
        expect(
          exifAfter,
          isNull,
          reason: 'EXIF data should be completely removed',
        );
      });

      test('output is smaller than input when EXIF was present', () {
        final jpegWithExif = _createJpegWithExif();
        final stripped = ExifUtil.stripJpegExif(jpegWithExif);

        expect(
          stripped.length,
          lessThan(jpegWithExif.length),
          reason: 'Removing EXIF block should reduce file size',
        );
      });

      test('output is a valid decodable JPEG', () {
        final jpegWithExif = _createJpegWithExif();
        final stripped = ExifUtil.stripJpegExif(jpegWithExif);

        // Must still be a valid JPEG
        expect(stripped[0], equals(0xFF), reason: 'JPEG SOI marker byte 1');
        expect(stripped[1], equals(0xD8), reason: 'JPEG SOI marker byte 2');

        final decoded = img.decodeJpg(stripped);
        expect(decoded, isNotNull, reason: 'Stripped JPEG must be decodable');
        expect(decoded!.width, equals(2));
        expect(decoded.height, equals(2));
      });

      test('returns original bytes for JPEG without EXIF', () {
        final jpegNoExif = _createJpegWithoutExif();
        final result = ExifUtil.stripJpegExif(jpegNoExif);

        // When there's no EXIF to strip, bytes should pass through unchanged
        expect(result.length, equals(jpegNoExif.length));
      });

      test('returns original bytes for PNG input', () {
        // PNG magic: 0x89 0x50 0x4E 0x47
        final pngBytes = Uint8List.fromList(
          img.encodePng(img.Image(width: 2, height: 2)),
        );

        final result = ExifUtil.stripJpegExif(pngBytes);

        expect(
          result,
          equals(pngBytes),
          reason: 'Non-JPEG input should be returned unchanged',
        );
      });

      test('returns original bytes for empty input', () {
        final empty = Uint8List(0);
        final result = ExifUtil.stripJpegExif(empty);

        expect(result, equals(empty));
      });

      test('returns original bytes for single-byte input', () {
        final single = Uint8List.fromList([0xFF]);
        final result = ExifUtil.stripJpegExif(single);

        expect(result, equals(single));
      });
    });
  });
}
