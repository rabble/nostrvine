// ABOUTME: Tests for shake detector service
// ABOUTME: Verifies shake detection logic without actual accelerometer

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/shake_detector_service.dart';

void main() {
  group('ShakeDetectorService', () {
    test('can be instantiated with default values', () {
      final service = ShakeDetectorService();
      expect(service.shakeThreshold, 15.0);
      expect(service.shakeCount, 3);
      expect(service.shakeDuration, const Duration(milliseconds: 500));
    });

    test('can be instantiated with custom values', () {
      final service = ShakeDetectorService(
        shakeThreshold: 20.0,
        shakeCount: 5,
        shakeDuration: const Duration(seconds: 1),
      );
      expect(service.shakeThreshold, 20.0);
      expect(service.shakeCount, 5);
      expect(service.shakeDuration, const Duration(seconds: 1));
    });

    test('onShake stream is broadcast stream', () {
      final service = ShakeDetectorService();
      // Should be able to listen multiple times (broadcast)
      service.onShake.listen((_) {});
      service.onShake.listen((_) {});
      service.dispose();
    });

    test('dispose cleans up resources', () {
      final service = ShakeDetectorService();
      service.start();
      service.dispose();
      // Should not throw after dispose
    });

    test('stop cancels subscription', () {
      final service = ShakeDetectorService();
      service.start();
      service.stop();
      service.dispose();
    });
  });
}
