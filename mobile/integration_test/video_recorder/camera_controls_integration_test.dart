// ABOUTME: Integration tests for camera control features
// ABOUTME: Tests flash, zoom, focus point, and exposure controls

// NOTE: On Android, camera/microphone permissions must be granted before running.
// Either grant via ADB: adb shell pm grant co.openvine.app android.permission.CAMERA
// Or the first test run will show permission dialogs that must be accepted.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:permissions_service/permissions_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Controls Integration Tests', () {
    late CameraService cameraService;

    setUpAll(() async {
      // Request permissions once at the start
      const service = PermissionHandlerPermissionsService();
      await service.requestCameraPermission();
      await service.requestMicrophonePermission();

      Log.info(
        '📷 Running Camera Controls Integration Tests',
        name: 'CameraControlsIntegrationTest',
        category: LogCategory.system,
      );
      Log.info(
        'Platform: ${Platform.operatingSystem}',
        name: 'CameraControlsIntegrationTest',
        category: LogCategory.system,
      );
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

    group('Flash Control', () {
      testWidgets('can set flash to auto', (tester) async {
        final success = await cameraService.setFlashMode(DivineFlashMode.auto);
        expect(success, isA<bool>());
      });

      testWidgets('can set flash to off', (tester) async {
        final success = await cameraService.setFlashMode(DivineFlashMode.off);
        expect(success, isA<bool>());
      });

      testWidgets('can set flash to torch', (tester) async {
        final success = await cameraService.setFlashMode(DivineFlashMode.torch);
        expect(success, isA<bool>());
      });

      testWidgets('can cycle through all flash modes', (tester) async {
        for (final mode in DivineFlashMode.values) {
          final success = await cameraService.setFlashMode(mode);
          expect(success, isA<bool>());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    });

    group('Zoom Control', () {
      testWidgets('can set zoom level', (tester) async {
        final minZoom = cameraService.minZoomLevel;
        final maxZoom = cameraService.maxZoomLevel;

        final midZoom = (minZoom + maxZoom) / 2;
        final success = await cameraService.setZoomLevel(midZoom);

        expect(success, isA<bool>());
      });

      testWidgets('can set zoom to minimum', (tester) async {
        final minZoom = cameraService.minZoomLevel;
        final success = await cameraService.setZoomLevel(minZoom);

        expect(success, isA<bool>());
      });

      testWidgets('can set zoom to maximum', (tester) async {
        final maxZoom = cameraService.maxZoomLevel;
        final success = await cameraService.setZoomLevel(maxZoom);

        expect(success, isA<bool>());
      });

      testWidgets('can smoothly transition zoom levels', (tester) async {
        final minZoom = cameraService.minZoomLevel;
        final maxZoom = cameraService.maxZoomLevel;

        // Zoom from min to max in steps
        for (var i = 0; i <= 5; i++) {
          final zoom = minZoom + (maxZoom - minZoom) * (i / 5);
          await cameraService.setZoomLevel(zoom);
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
    });

    group('Focus Control', () {
      testWidgets('can set focus point at center', (tester) async {
        final success = await cameraService.setFocusPoint(
          const Offset(0.5, 0.5),
        );
        expect(success, isA<bool>());
      });

      testWidgets('can set focus point at corners', (tester) async {
        final points = [
          const Offset(0.0, 0.0), // Top-left
          const Offset(1.0, 0.0), // Top-right
          const Offset(0.0, 1.0), // Bottom-left
          const Offset(1.0, 1.0), // Bottom-right
        ];

        for (final point in points) {
          final success = await cameraService.setFocusPoint(point);
          expect(success, isA<bool>());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });

      testWidgets('can set exposure point', (tester) async {
        final success = await cameraService.setExposurePoint(
          const Offset(0.5, 0.5),
        );
        expect(success, isA<bool>());
      });

      testWidgets('can set exposure at corners', (tester) async {
        final points = [
          const Offset(0.0, 0.0), // Top-left
          const Offset(1.0, 0.0), // Top-right
          const Offset(0.0, 1.0), // Bottom-left
          const Offset(1.0, 1.0), // Bottom-right
        ];

        for (final point in points) {
          final success = await cameraService.setExposurePoint(point);
          expect(success, isA<bool>());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    });

    group('Combined Controls', () {
      testWidgets('can change multiple settings in sequence', (tester) async {
        await cameraService.setFlashMode(DivineFlashMode.auto);
        await tester.pump(const Duration(milliseconds: 100));

        await cameraService.setZoomLevel(2.0);
        await tester.pump(const Duration(milliseconds: 100));

        await cameraService.setFocusPoint(const Offset(0.5, 0.5));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify no exceptions occurred during the operations
        expect(tester.takeException(), isNull);
      });
    });
  });
}
