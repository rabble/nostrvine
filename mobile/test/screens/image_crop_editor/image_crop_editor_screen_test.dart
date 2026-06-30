// ABOUTME: Tests the ImageCropKind config contract used by the crop editor.
// ABOUTME: Locks the per-kind aspect ratio, output cap, filename and mime type.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';

void main() {
  group(ImageCropKind, () {
    test('avatar locks a 1:1 frame capped at 1024 as jpeg', () {
      expect(ImageCropKind.avatar.aspectRatio, 1);
      expect(ImageCropKind.avatar.maxOutputSize, const Size(1024, 1024));
      expect(ImageCropKind.avatar.filename, 'avatar.jpg');
      expect(ImageCropKind.avatar.mimeType, 'image/jpeg');
    });

    test('banner locks a 3:1 frame capped at 1500x500 as jpeg', () {
      expect(ImageCropKind.banner.aspectRatio, 3);
      expect(ImageCropKind.banner.maxOutputSize, const Size(1500, 500));
      expect(ImageCropKind.banner.filename, 'banner.jpg');
      expect(ImageCropKind.banner.mimeType, 'image/jpeg');
    });
  });

  group('croppedBytesOrNull', () {
    test('returns null for empty bytes (failed capture)', () {
      expect(croppedBytesOrNull(Uint8List(0)), isNull);
    });

    test('returns the bytes unchanged when non-empty', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(croppedBytesOrNull(bytes), same(bytes));
    });
  });
}
