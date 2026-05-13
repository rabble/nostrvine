// ABOUTME: Unit tests for image_upload_validation (#4272 plan §2).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/image_upload_validation.dart';

void main() {
  group('validateImageBytes', () {
    test('ok at exactly max bytes (avatar)', () {
      final bytes = Uint8List(kProfileImageUploadMaxBytes);
      final r = validateImageBytes(bytes, ImageUploadKind.avatar);
      expect(r, isA<ImageUploadValidationOk>());
      expect(r.isOk, isTrue);
    });

    test('tooLarge one byte over limit (banner)', () {
      final bytes = Uint8List(kProfileImageUploadMaxBytes + 1);
      final r = validateImageBytes(bytes, ImageUploadKind.banner);
      expect(r, isA<ImageUploadValidationTooLarge>());
      final t = r as ImageUploadValidationTooLarge;
      expect(t.limitBytes, kProfileImageUploadMaxBytes);
      expect(t.actualBytes, kProfileImageUploadMaxBytes + 1);
    });

    test('empty bytes ok', () {
      final r = validateImageBytes(Uint8List(0), ImageUploadKind.avatar);
      expect(r.isOk, isTrue);
    });

    test('unsupportedFormat when filename has disallowed extension', () {
      final bytes = Uint8List(10);
      final r = validateImageBytes(
        bytes,
        ImageUploadKind.avatar,
        filename: 'x.exe',
      );
      expect(r, isA<ImageUploadValidationUnsupportedFormat>());
      expect((r as ImageUploadValidationUnsupportedFormat).extension, 'exe');
    });

    test('ok when filename has allowed extension', () {
      final bytes = Uint8List(10);
      final r = validateImageBytes(
        bytes,
        ImageUploadKind.avatar,
        filename: 'Photo.JPEG',
      );
      expect(r.isOk, isTrue);
    });

    test('ok when filename has no extension (permissive)', () {
      final bytes = Uint8List(10);
      final r = validateImageBytes(
        bytes,
        ImageUploadKind.avatar,
        filename: 'blob',
      );
      expect(r.isOk, isTrue);
    });

    test('HEIC allowed (iOS gallery)', () {
      final bytes = Uint8List(1);
      final r = validateImageBytes(
        bytes,
        ImageUploadKind.avatar,
        filename: 'img.heic',
      );
      expect(r.isOk, isTrue);
    });
  });

  group('validateImageFile', () {
    test('unreadable when file missing', () {
      final f = File('/nonexistent/path/4272_missing_image.jpg');
      final r = validateImageFile(f, ImageUploadKind.banner);
      expect(r, isA<ImageUploadValidationUnreadable>());
    });

    test('unsupportedFormat for disallowed extension on disk', () {
      final dir = Directory.systemTemp.createTempSync('img_val_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final f = File('${dir.path}/notes.txt');
      f.writeAsBytesSync(Uint8List(8));

      final r = validateImageFile(f, ImageUploadKind.avatar);
      expect(r, isA<ImageUploadValidationUnsupportedFormat>());
      expect((r as ImageUploadValidationUnsupportedFormat).extension, 'txt');
    });

    test('ok for small png path', () {
      final dir = Directory.systemTemp.createTempSync('img_val_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final f = File('${dir.path}/x.png');
      f.writeAsBytesSync(Uint8List(4));

      final r = validateImageFile(f, ImageUploadKind.videoThumbnail);
      expect(r.isOk, isTrue);
    });
  });

  group('ImageUploadPolicy.maxBytes', () {
    test('all kinds use profile ceiling for now', () {
      for (final k in ImageUploadKind.values) {
        expect(
          ImageUploadPolicy.maxBytes(k),
          kProfileImageUploadMaxBytes,
        );
      }
    });
  });
}
