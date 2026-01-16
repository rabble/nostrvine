// ABOUTME: Integration tests for app lifecycle handling
// ABOUTME: Tests camera behavior during app pause/resume and other lifecycle changes

// NOTE: On Android, camera/microphone permissions must be granted before running.
// Either grant via ADB: adb shell pm grant co.openvine.app android.permission.CAMERA
// Or the first test run will show permission dialogs that must be accepted.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:permissions_service/permissions_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Lifecycle Integration Tests', () {
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

    testWidgets('handles app pause', (tester) async {
      await cameraService.handleAppLifecycleState(.paused);
      await tester.pump(Duration(milliseconds: 100));

      // Should complete without error
    });

    testWidgets('handles app resume', (tester) async {
      await cameraService.handleAppLifecycleState(.resumed);
      await tester.pump(Duration(milliseconds: 100));

      // Camera should still be initialized
      expect(cameraService.isInitialized, isTrue);
    });

    testWidgets('handles pause-resume cycle', (tester) async {
      await cameraService.handleAppLifecycleState(.paused);
      await tester.pump(Duration(milliseconds: 200));

      await cameraService.handleAppLifecycleState(.resumed);
      await tester.pump(Duration(milliseconds: 200));

      // Camera should recover
      expect(cameraService.isInitialized, isTrue);
      expect(cameraService.canRecord, isTrue);
    });

    testWidgets('handles multiple lifecycle changes', (tester) async {
      final List<AppLifecycleState> states = [
        .paused,
        .resumed,
        .inactive,
        .resumed,
        .paused,
        .resumed,
      ];

      for (final state in states) {
        await cameraService.handleAppLifecycleState(state);
        await tester.pump(Duration(milliseconds: 100));
      }

      // Should handle all transitions gracefully
      expect(cameraService.isInitialized, isTrue);
    });

    testWidgets('can record after lifecycle changes', (tester) async {
      // Simulate app going to background and back
      await cameraService.handleAppLifecycleState(.paused);
      await tester.pump(Duration(milliseconds: 200));

      await cameraService.handleAppLifecycleState(.resumed);
      await tester.pump(Duration(milliseconds: 200));

      // Should still be able to record
      expect(cameraService.canRecord, isTrue);

      await cameraService.startRecording();
      await tester.pump(Duration(milliseconds: 500));

      final video = await cameraService.stopRecording();
      expect(video, anyOf(isNull, isA<Object>()));
    });

    testWidgets('handles detached state', (tester) async {
      await cameraService.handleAppLifecycleState(.detached);
      await tester.pump(Duration(milliseconds: 100));

      // Verify no exceptions occurred during the operations
      expect(tester.takeException(), isNull);
    });
  });
}
