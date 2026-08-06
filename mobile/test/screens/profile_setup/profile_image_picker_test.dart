// ABOUTME: Unit tests for the profile image-picker platform routing helper and
// ABOUTME: the pre-crop validation that rejects missing/empty picker output.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_picker.dart';

void main() {
  group('isDesktopImagePickerPlatform', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('returns false for mobile platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(isDesktopImagePickerPlatform(), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(isDesktopImagePickerPlatform(), isFalse);
    });

    test('returns true for desktop platforms', () {
      for (final platform in const [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(isDesktopImagePickerPlatform(), isTrue, reason: '$platform');
      }
    });
  });

  group('resolveProfileImageSelection', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('profile_image_picker');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('resolves an existing non-empty file', () async {
      final file = File('${tempDir.path}/picked.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);

      final selection = await resolveProfileImageSelection(XFile(file.path));

      expect(selection, isNotNull);
      expect(selection!.file?.path, file.path);
      expect(selection.bytes, isNull);
    });

    test('rejects a file the picker never wrote', () async {
      // Stat throws for a missing path; the caller must still get a
      // recoverable null rather than an uncaught exception.
      final selection = await resolveProfileImageSelection(
        XFile('${tempDir.path}/gone.jpg'),
      );

      expect(selection, isNull);
    });

    test('rejects a zero-byte file', () async {
      // The iOS crash: image_picker hands back a temporary JPEG with no bytes.
      final file = File('${tempDir.path}/empty.jpg')..writeAsBytesSync([]);

      final selection = await resolveProfileImageSelection(XFile(file.path));

      expect(selection, isNull);
    });
  });
}
