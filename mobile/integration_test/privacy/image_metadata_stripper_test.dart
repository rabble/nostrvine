// ABOUTME: Integration test for image_metadata_stripper plugin on real device
// ABOUTME: Verifies GPS/EXIF data is actually stripped by native code

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_metadata_stripper/image_metadata_stripper.dart';
import 'package:patrol/patrol.dart';

/// A small 32x32 RGB JPEG with GPS EXIF data (Berlin coordinates).
/// Generated via Pillow + piexif. Only ~1 KB so it can live inline.
const _testImageBase64 =
    '/9j/4AAQSkZJRgABAQAAAQABAAD/4QEeRXhpZgAATU0AKgAAAAgABAEPAAIAAAALAAAAPgEQ'
    'AAIAAAAKAAAASYdpAAQAAAABAAAAU4glAAQAAAABAAAAlAAAAABUZXN0Q2FtZXJhAFRlc3RN'
    'b2RlbAAAApADAAIAAAAUAAAAbZKGAAcAAAATAAAAgTIwMjU6MDM6MjUgMTI6MDA6MDAAVGVz'
    'dCBpbWFnZSB3aXRoIEdQUwAGAAEAAgAAAAJOAAAAAAIABQAAAAMAAADeAAMAAgAAAAJFAAAA'
    'AAQABQAAAAMAAAD2AAUAAQAAAAEAAAAAAAYABQAAAAEAAAEOAAAANAAAAAEAAAAfAAAAAQAA'
    'AAwAAAABAAAADQAAAAEAAAAYAAAAAQAAABIAAAABAAAAIgAAAAH/2wBDAAUDBAQEAwUEBAQF'
    'BQUGBwwIBwcHBw8LCwkMEQ8SEhEPERETFhwXExQaFRERGCEYGh0dHx8fExciJCIeJBweHx7/'
    '2wBDAQUFBQcGBw4ICA4eFBEUHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4eHh4e'
    'Hh4eHh4eHh4eHh4eHh7/wAARCAAgACADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAA'
    'AAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKB'
    'kaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNk'
    'ZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXG'
    'x8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAA'
    'AAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEI'
    'FEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpj'
    'ZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPE'
    'xcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD5xsNK6fLW'
    '/Y6V0+Wt2w0rp8tb9hpXT5a+2xWZ+ZzZFnO2pg2GldPlrfsNK6fLW9Y6V0+Wt6w0rp8tfO4r'
    'M/M/Z8iznbU5+x0rp8tb9hpXT5a3rDSuny1vWOldPlr53FZn5n8hZFnG2phWGldPlresNK6f'
    'LW9YaV0+Wt6w0rp8tfO4rM/M/Z8izjbU/9k=';

/// EXIF APP1 marker bytes: `Exif\0\0`
const _exifMarker = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00];

/// Returns `true` if [bytes] contain the EXIF APP1 header.
bool _containsExifMarker(Uint8List bytes) {
  return _containsSequence(bytes, _exifMarker);
}

/// Returns `true` if [bytes] contain a specific byte sequence.
bool _containsSequence(Uint8List bytes, List<int> sequence) {
  for (var i = 0; i < bytes.length - sequence.length; i++) {
    var match = true;
    for (var j = 0; j < sequence.length; j++) {
      if (bytes[i + j] != sequence[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

/// Returns `true` if the bytes contain the `TestCamera` maker string,
/// which is embedded in the fixture's EXIF IFD0.
bool _containsMakeTag(Uint8List bytes) {
  // 'TestCamera' in ASCII
  const make = [0x54, 0x65, 0x73, 0x74, 0x43, 0x61, 0x6D, 0x65, 0x72, 0x61];
  return _containsSequence(bytes, make);
}

/// Returns `true` if the bytes contain the DateTimeOriginal value
/// `2025:03:25 12:00:00` embedded in the fixture's EXIF.
bool _containsDateTimeOriginal(Uint8List bytes) {
  // '2025:03:25 12:00:00' in ASCII
  const dt = [
    0x32, 0x30, 0x32, 0x35, 0x3A, 0x30, 0x33, 0x3A, 0x32, 0x35, //
    0x20, 0x31, 0x32, 0x3A, 0x30, 0x30, 0x3A, 0x30, 0x30,
  ];
  return _containsSequence(bytes, dt);
}

/// Returns `true` if the bytes contain the GPS IFD pointer tag (0x8825)
/// which marks the presence of a GPS sub-IFD in EXIF data.
bool _containsGpsIfd(Uint8List bytes) {
  // EXIF tag 0x8825 = GPS IFD pointer (big-endian, Motorola byte order)
  const gpsTag = [0x88, 0x25];
  return _containsSequence(bytes, gpsTag);
}

void main() {
  group('ImageMetadataStripper Integration Tests', () {
    late Directory tempDir;
    late Uint8List fixtureBytes;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'image_metadata_stripper_test_',
      );
      fixtureBytes = base64Decode(_testImageBase64);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    patrolTest(
      'fixture image contains EXIF, GPS and maker metadata',
      ($) async {
        expect(
          _containsExifMarker(fixtureBytes),
          isTrue,
          reason: 'Fixture must contain EXIF APP1 marker',
        );
        expect(
          _containsMakeTag(fixtureBytes),
          isTrue,
          reason: 'Fixture must contain camera Make tag',
        );
        expect(
          _containsDateTimeOriginal(fixtureBytes),
          isTrue,
          reason: 'Fixture must contain DateTimeOriginal',
        );
        expect(
          _containsGpsIfd(fixtureBytes),
          isTrue,
          reason: 'Fixture must contain GPS IFD pointer tag',
        );
      },
    );

    patrolTest(
      'strips EXIF and GPS metadata from JPEG',
      ($) async {
        // Arrange — copy GPS-tagged fixture to temp file
        final inputFile = File('${tempDir.path}/input.jpg');
        await inputFile.writeAsBytes(fixtureBytes);

        // Sanity check — original contains EXIF
        final originalBytes = await inputFile.readAsBytes();
        expect(
          _containsExifMarker(originalBytes),
          isTrue,
          reason: 'Test fixture must contain EXIF data',
        );

        // Act — strip metadata in-place via native plugin
        await ImageMetadataStripper.stripMetadataInPlace(inputFile);

        // Assert — privacy-sensitive metadata is removed.
        // Note: iOS CGImageDestination may add a minimal EXIF APP1
        // header (orientation, color profile) which is harmless.
        // We verify the actual privacy-relevant fields are gone.
        final strippedBytes = await inputFile.readAsBytes();

        // Assert — camera maker tag is gone
        expect(
          _containsMakeTag(strippedBytes),
          isFalse,
          reason: 'Stripped image must not contain Make tag',
        );

        // Assert — DateTimeOriginal is gone
        expect(
          _containsDateTimeOriginal(strippedBytes),
          isFalse,
          reason: 'Stripped image must not contain DateTimeOriginal',
        );

        // Assert — GPS IFD pointer is gone
        expect(
          _containsGpsIfd(strippedBytes),
          isFalse,
          reason: 'Stripped image must not contain GPS IFD',
        );

        // Assert — output is still a valid JPEG (starts with SOI marker)
        expect(strippedBytes[0], equals(0xFF));
        expect(strippedBytes[1], equals(0xD8));

        // Assert — output is non-empty and reasonable size
        expect(strippedBytes.length, greaterThan(100));
      },
    );

    patrolTest(
      'strips metadata via separate input/output paths',
      ($) async {
        // Arrange
        final inputFile = File('${tempDir.path}/input.jpg');
        final outputPath = '${tempDir.path}/output.jpg';
        await inputFile.writeAsBytes(fixtureBytes);

        // Act
        await ImageMetadataStripper.stripMetadata(
          inputPath: inputFile.path,
          outputPath: outputPath,
        );

        // Assert — original is untouched
        final originalBytes = await inputFile.readAsBytes();
        expect(_containsExifMarker(originalBytes), isTrue);
        expect(_containsMakeTag(originalBytes), isTrue);

        // Assert — privacy-sensitive metadata is gone.
        // Note: a minimal EXIF APP1 header for orientation/color is
        // acceptable — we verify the actual sensitive fields.
        final outputFile = File(outputPath);
        expect(outputFile.existsSync(), isTrue);

        final strippedBytes = await outputFile.readAsBytes();
        expect(
          _containsMakeTag(strippedBytes),
          isFalse,
          reason: 'Stripped image must not contain Make tag',
        );
        expect(
          _containsDateTimeOriginal(strippedBytes),
          isFalse,
          reason: 'Stripped image must not contain DateTimeOriginal',
        );
        expect(
          _containsGpsIfd(strippedBytes),
          isFalse,
          reason: 'Stripped image must not contain GPS IFD',
        );

        // Assert — valid JPEG
        expect(strippedBytes[0], equals(0xFF));
        expect(strippedBytes[1], equals(0xD8));
        expect(strippedBytes.length, greaterThan(100));
      },
    );
  });
}
