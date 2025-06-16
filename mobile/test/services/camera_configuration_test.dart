// ABOUTME: Unit tests for camera recording configuration functionality
// ABOUTME: Tests duration clamping, FPS limits, and configuration management

import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/camera_service.dart';

void main() {
  group('CameraConfiguration', () {
    test('default configuration has correct values', () {
      const config = CameraConfiguration();
      
      expect(config.recordingDuration, const Duration(seconds: 6));
      expect(config.targetFPS, 5.0);
      expect(config.enableAutoStop, true);
      expect(config.targetFrameCount, 30); // 6 seconds * 5 FPS
    });

    test('vine configuration clamps duration to 3-15 seconds', () {
      // Test lower bound
      final configLow = CameraConfiguration.vine(
        duration: const Duration(seconds: 1),
      );
      expect(configLow.recordingDuration, const Duration(seconds: 3));

      // Test upper bound
      final configHigh = CameraConfiguration.vine(
        duration: const Duration(seconds: 20),
      );
      expect(configHigh.recordingDuration, const Duration(seconds: 15));

      // Test valid range
      final configValid = CameraConfiguration.vine(
        duration: const Duration(seconds: 8),
      );
      expect(configValid.recordingDuration, const Duration(seconds: 8));
    });

    test('vine configuration clamps FPS to 3-10', () {
      // Test lower bound
      final configLow = CameraConfiguration.vine(fps: 1.0);
      expect(configLow.targetFPS, 3.0);

      // Test upper bound
      final configHigh = CameraConfiguration.vine(fps: 15.0);
      expect(configHigh.targetFPS, 10.0);

      // Test valid range
      final configValid = CameraConfiguration.vine(fps: 7.5);
      expect(configValid.targetFPS, 7.5);
    });

    test('target frame count calculation is correct', () {
      final config = CameraConfiguration.vine(
        duration: const Duration(seconds: 10),
        fps: 4.0,
      );
      
      expect(config.targetFrameCount, 40); // 10 seconds * 4 FPS
    });

    test('toString provides useful debug information', () {
      final config = CameraConfiguration.vine(
        duration: const Duration(seconds: 8),
        fps: 6.0,
      );
      
      final description = config.toString();
      expect(description, contains('8s'));
      expect(description, contains('6.0'));
      expect(description, contains('48')); // frame count
    });
  });

  group('CameraService Configuration', () {
    late CameraService cameraService;

    setUp(() {
      cameraService = CameraService();
    });

    tearDown(() {
      cameraService.dispose();
    });

    test('setRecordingDuration clamps to valid range', () {
      // Test lower bound clamping
      cameraService.setRecordingDuration(const Duration(seconds: 2));
      expect(cameraService.maxVineDuration, const Duration(seconds: 3));

      // Test upper bound clamping
      cameraService.setRecordingDuration(const Duration(seconds: 20));
      expect(cameraService.maxVineDuration, const Duration(seconds: 15));

      // Test valid value
      cameraService.setRecordingDuration(const Duration(seconds: 12));
      expect(cameraService.maxVineDuration, const Duration(seconds: 12));
    });

    test('setTargetFPS clamps to valid range', () {
      // Test lower bound clamping
      cameraService.setTargetFPS(1.0);
      expect(cameraService.targetFPS, 3.0);

      // Test upper bound clamping
      cameraService.setTargetFPS(15.0);
      expect(cameraService.targetFPS, 10.0);

      // Test valid value
      cameraService.setTargetFPS(7.5);
      expect(cameraService.targetFPS, 7.5);
    });

    test('useVineConfiguration applies preset correctly', () {
      cameraService.useVineConfiguration(
        duration: const Duration(seconds: 9),
        fps: 8.0,
        autoStop: false,
      );

      expect(cameraService.maxVineDuration, const Duration(seconds: 9));
      expect(cameraService.targetFPS, 8.0);
      expect(cameraService.enableAutoStop, false);
      expect(cameraService.targetFrameCount, 72); // 9 * 8
    });

    test('updateConfiguration replaces entire configuration', () {
      final newConfig = CameraConfiguration(
        recordingDuration: const Duration(seconds: 7),
        targetFPS: 4.5,
        enableAutoStop: false,
      );

      cameraService.updateConfiguration(newConfig);

      expect(cameraService.configuration, newConfig);
      expect(cameraService.maxVineDuration, const Duration(seconds: 7));
      expect(cameraService.targetFPS, 4.5);
      expect(cameraService.enableAutoStop, false);
    });
  });
}