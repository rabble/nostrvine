// ABOUTME: Tests the imageCropLauncherProvider DI seam default.
// ABOUTME: Ensures it resolves to the real showImageCropEditor by default.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';

void main() {
  group('imageCropLauncherProvider', () {
    test('defaults to showImageCropEditor', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(imageCropLauncherProvider),
        same(showImageCropEditor),
      );
    });
  });
}
