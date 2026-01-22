// ABOUTME: Integration tests for camera initialization and setup
// ABOUTME: Tests camera service creation, initialization, and basic properties

// NOTE: On Android, camera/microphone permissions must be granted before running.
// Either grant via ADB: adb shell pm grant co.openvine.app android.permission.CAMERA
// Or the first test run will show permission dialogs that must be accepted.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:permissions_service/permissions_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Initialization Integration Tests', () {
    late CameraService cameraService;

    setUpAll(() async {
      // Request permissions once at the start of all tests
      // On Android, this will show the permission dialog once
      // After granting, all subsequent tests will run without dialogs
      final service = PermissionHandlerPermissionsService();
      await service.requestCameraPermission();
      await service.requestMicrophonePermission();
    });

    setUp(() {
      cameraService = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    testWidgets('camera service can be created', (tester) async {
      expect(cameraService, isNotNull);
      expect(cameraService, isA<CameraService>());
    });

    testWidgets('camera service can be initialized', (tester) async {
      await cameraService.initialize();

      expect(cameraService.isInitialized, isTrue);
    });

    testWidgets('camera provides valid aspect ratio', (tester) async {
      await cameraService.initialize();

      final aspectRatio = cameraService.cameraAspectRatio;
      expect(aspectRatio, greaterThan(0));
      expect(aspectRatio.isFinite, isTrue);
    });

    testWidgets('camera provides valid zoom limits', (tester) async {
      await cameraService.initialize();

      expect(cameraService.minZoomLevel, greaterThan(0.0));
      expect(
        cameraService.maxZoomLevel,
        greaterThanOrEqualTo(cameraService.minZoomLevel),
      );
    });

    testWidgets('camera reports focus support capability', (tester) async {
      await cameraService.initialize();

      expect(cameraService.isFocusPointSupported, isA<bool>());
    });

    testWidgets('camera reports recording capability', (tester) async {
      await cameraService.initialize();

      expect(cameraService.canRecord, isTrue);
    });

    testWidgets('camera reports switch capability', (tester) async {
      await cameraService.initialize();

      expect(cameraService.canSwitchCamera, isA<bool>());
    });

    testWidgets('camera can be disposed after initialization', (tester) async {
      await cameraService.initialize();
      expect(cameraService.isInitialized, isTrue);

      await cameraService.dispose();

      // Verify no exceptions occurred during the operations
      expect(tester.takeException(), isNull);
    });

    testWidgets('camera can be initialized multiple times', (tester) async {
      await cameraService.initialize();
      expect(cameraService.isInitialized, isTrue);

      // Second initialization should be safe
      await cameraService.initialize();
      expect(cameraService.isInitialized, isTrue);
    });
  });
}
