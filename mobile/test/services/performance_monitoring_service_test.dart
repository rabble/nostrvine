// ABOUTME: Tests for Firebase Performance Monitoring service
// ABOUTME: Verifies trace creation, metrics, and attributes

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

void main() {
  group('PerformanceMonitoringService', () {
    late PerformanceMonitoringService service;

    setUp(() {
      service = PerformanceMonitoringService();
    });

    test('should initialize without error', () async {
      // Service initialization should not throw
      await service.initialize();
      // If we get here, initialization succeeded
      expect(true, true);
    });

    test('isEnabled stays false while Firebase is unavailable', () async {
      // The flag gates the instrumented HTTP client (#7122): it must only
      // turn true once Firebase Performance actually came up, never merely
      // because initialize() was called and swallowed a failure.
      expect(service.isEnabled, isFalse);

      await service.initialize();

      expect(service.isEnabled, isFalse);
    });

    test(
      'startOperationTrace returns a handle that tags and stops cleanly',
      () async {
        await service.initialize();

        final trace = service.startOperationTrace('test_operation');

        // Tagging and stopping the handle must be safe even when Firebase
        // isn't configured (the uninitialised path returns a no-op handle).
        trace
          ..putAttribute('outcome', 'success')
          ..setMetric('phase_ms', 120);
        await expectLater(trace.stop(), completes);
      },
    );
  });

  group(NoOpPerformanceTraceMonitor, () {
    test('startOperationTrace hands out a no-op trace handle', () async {
      const monitor = NoOpPerformanceTraceMonitor();

      final trace = monitor.startOperationTrace('test_operation');
      trace
        ..putAttribute('outcome', 'success')
        ..setMetric('phase_ms', 120);

      await expectLater(trace.stop(), completes);
    });
  });
}
