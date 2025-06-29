// ABOUTME: Unit tests for camera recording configuration functionality
// ABOUTME: Tests duration clamping, FPS limits, and configuration management

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/camera_service.dart';

void main() {
  group('CameraConfiguration', () {
    test('default configuration has correct values', () {
      const config = CameraConfiguration();
      
      expect(config.recordingDuration, const Duration(milliseconds: 6300));
      expect(config.enableAutoStop, true);
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

    test('vine configuration can set auto stop', () {
      // Test auto stop enabled
      final configAutoStop = CameraConfiguration.vine(autoStop: true);
      expect(configAutoStop.enableAutoStop, true);

      // Test auto stop disabled
      final configNoAutoStop = CameraConfiguration.vine(autoStop: false);
      expect(configNoAutoStop.enableAutoStop, false);
    });

    test('toString provides useful debug information', () {
      final config = CameraConfiguration.vine(
        duration: const Duration(seconds: 8),
      );
      
      final description = config.toString();
      expect(description, contains('8s'));
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

    test('camera service uses configuration correctly', () {
      // Test that camera service uses the configuration properties
      expect(cameraService.configuration.recordingDuration, const Duration(milliseconds: 6300));
      expect(cameraService.maxVineDuration, const Duration(milliseconds: 6300));
      expect(cameraService.enableAutoStop, true);
    });
  });
}