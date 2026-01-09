// ABOUTME: Tests for CameraService base class
// ABOUTME: Validates factory pattern
//
// NOTE: These are basic unit tests that validate the abstract interface.
// Concrete implementations are tested in their respective test files, and
// actual camera functionality is tested in integration_test/.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraService Tests', () {
    test('create() returns a CameraService instance', () {
      final service = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
      );
      expect(service, isA<CameraService>());
    });
  });
}
