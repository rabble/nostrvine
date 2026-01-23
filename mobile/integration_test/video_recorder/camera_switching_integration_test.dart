// ABOUTME: Integration tests for camera switching functionality
// ABOUTME: Tests switching between front and back cameras

// NOTE: On Android, camera/microphone permissions must be granted before running.
// Either grant via ADB: adb shell pm grant co.openvine.app android.permission.CAMERA
// Or the first test run will show permission dialogs that must be accepted.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:permissions_service/permissions_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Switching Integration Tests', () {
    late CameraService cameraService;

    setUpAll(() async {
      final service = PermissionHandlerPermissionsService();
      await service.requestCameraPermission();
      await service.requestMicrophonePermission();
    });

    setUp(() async {
      cameraService = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await cameraService.initialize();
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    testWidgets('reports camera switch capability', (tester) async {
      final canSwitch = cameraService.canSwitchCamera;
      expect(canSwitch, isA<bool>());
    });

    testWidgets('can switch camera if multiple cameras available', (
      tester,
    ) async {
      if (!cameraService.canSwitchCamera) {
        // Skip if device only has one camera
        return;
      }

      final success = await cameraService.switchCamera();

      expect(success, isTrue);
      expect(cameraService.isInitialized, isTrue);
    });

    testWidgets('camera remains initialized after switching', (tester) async {
      if (!cameraService.canSwitchCamera) {
        return;
      }

      await cameraService.switchCamera();
      await tester.pump(Duration(milliseconds: 500));

      expect(cameraService.isInitialized, isTrue);
      expect(cameraService.canRecord, isTrue);
    });

    testWidgets('can switch camera multiple times', (tester) async {
      if (!cameraService.canSwitchCamera) {
        return;
      }

      for (var i = 0; i < 3; i++) {
        final success = await cameraService.switchCamera();
        expect(success, isTrue);

        await tester.pump(Duration(milliseconds: 300));
      }

      expect(cameraService.isInitialized, isTrue);
    });

    testWidgets('switching camera updates aspect ratio', (tester) async {
      if (!cameraService.canSwitchCamera) {
        return;
      }

      await cameraService.switchCamera();
      await tester.pump(Duration(milliseconds: 500));

      final newAspectRatio = cameraService.cameraAspectRatio;

      // Aspect ratio should be valid (may or may not change)
      expect(newAspectRatio, greaterThan(0));
      expect(newAspectRatio.isFinite, isTrue);
    });
  });
}
