// ABOUTME: Tests the ImageCropKind config contract used by the crop editor.
// ABOUTME: Locks the per-kind aspect ratio, output cap, filename and mime type.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';

void main() {
  group(ImageCropKind, () {
    test('avatar locks a 1:1 frame capped at 1024 as png', () {
      expect(ImageCropKind.avatar.aspectRatio, 1);
      expect(ImageCropKind.avatar.maxOutputSize, const Size(1024, 1024));
      expect(ImageCropKind.avatar.filename, 'avatar.png');
      expect(ImageCropKind.avatar.mimeType, 'image/png');
    });

    test('banner locks a 3:1 frame capped at 1500x500 as png', () {
      expect(ImageCropKind.banner.aspectRatio, 3);
      expect(ImageCropKind.banner.maxOutputSize, const Size(1500, 500));
      expect(ImageCropKind.banner.filename, 'banner.png');
      expect(ImageCropKind.banner.mimeType, 'image/png');
    });
  });
}
