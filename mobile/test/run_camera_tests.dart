// ABOUTME: Test runner script for camera tests with real hardware
// ABOUTME: Runs unit and integration tests with proper setup and reporting

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/unified_logger.dart';

// Import widget tests
import 'widgets/video_recorder/video_recorder_bottom_bar_test.dart'
    as bottom_bar_test;
import 'widgets/video_recorder/video_recorder_top_bar_test.dart'
    as top_bar_test;
import 'widgets/video_recorder/video_recorder_camera_preview_test.dart'
    as camera_preview_test;
import 'widgets/video_recorder/video_recorder_countdown_overlay_test.dart'
    as countdown_test;
import 'widgets/video_recorder/video_recorder_focus_point_test.dart'
    as focus_point_test;
import 'widgets/video_recorder/video_recorder_more_sheet_test.dart'
    as more_sheet_test;

// Import screen tests
import 'screens/video_recorder_screen_test.dart' as screen_test;

void main() async {
  // Initialize Flutter test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  Log.info(
    '=== OpenVine Camera Test Suite ===',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );
  Log.info(
    'Running camera tests with real hardware...',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );

  // Check camera availability
  CameraService? cameraService;
  try {
    cameraService = CameraService.create(
      onAutoStopped: (_) {},
      onUpdateState: ({forceCameraRebuild}) {},
    );
    await cameraService.initialize();

    Log.info(
      'Camera service initialized successfully',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
    Log.info(
      'Camera available: ${cameraService.isInitialized}',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
    Log.info(
      'Can switch camera: ${cameraService.canSwitchCamera}',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
  } catch (e) {
    Log.warning(
      'Could not initialize camera service: $e',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
    Log.warning(
      'Some tests will be skipped.',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
    cameraService = null;
  } finally {
    // Clean up camera service after check
    await cameraService?.dispose();
  }

  // Platform information
  Log.info(
    'Platform: ${Platform.operatingSystem}',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );
  Log.info(
    'Dart: ${Platform.version}',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );

  // Run test suites
  group('Camera Test Suite', () {
    group('Video Recorder Widget Tests', () {
      group('Bottom Bar Widget', () {
        bottom_bar_test.main();
      });

      group('Top Bar Widget', () {
        top_bar_test.main();
      });

      group('Camera Preview Widget', () {
        camera_preview_test.main();
      });

      group('Countdown Overlay Widget', () {
        countdown_test.main();
      });

      group('Focus Point Widget', () {
        focus_point_test.main();
      });

      group('More Sheet Widget', () {
        more_sheet_test.main();
      });
    });

    group('Video Recorder Screen Tests', () {
      screen_test.main();
    });
  });
}
