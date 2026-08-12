// ABOUTME: Tests for Firebase Performance Monitoring service
// ABOUTME: Verifies trace creation, metrics, and attributes

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

void main() {
  group('PerformanceMonitoringService.collectionEnabled', () {
    test('stays off outside release builds', () {
      // Premise: the test runner is not a release build, so this asserts the
      // same branch a developer's `flutter run` takes.
      expect(kReleaseMode, isFalse, reason: 'tests must run in non-release');

      // #7123: collection was enabled unconditionally, so developer devices
      // reported into the production dataset alongside real users. Local
      // builds were 9.5% of the 1.0.19 `_app_start` sample at a p50 of 919 ms
      // against ~100 ms for the same phone on a store build — enough to
      // manufacture a release-over-release regression that the release code
      // did not contain.
      expect(PerformanceMonitoringService.collectionEnabled, isFalse);
    });
  });

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

    test('should handle trace start and stop without error', () async {
      await service.initialize();

      // These should not throw even if Firebase isn't configured
      await service.startTrace('test_trace');
      await service.stopTrace('test_trace');

      expect(true, true);
    });

    test('should handle metrics without error', () async {
      await service.initialize();
      await service.startTrace('test_trace');

      // These should not throw even if Firebase isn't configured
      service.setMetric('test_trace', 'test_metric', 100);
      service.incrementMetric('test_trace', 'counter', 1);

      await service.stopTrace('test_trace');
      expect(true, true);
    });

    test('should handle attributes without error', () async {
      await service.initialize();
      await service.startTrace('test_trace');

      // This should not throw even if Firebase isn't configured
      service.putAttribute('test_trace', 'test_attr', 'test_value');

      await service.stopTrace('test_trace');
      expect(true, true);
    });

    test('trace convenience method should work', () async {
      await service.initialize();

      // Test the trace wrapper
      final result = await service.trace('test_operation', () async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'success';
      });

      expect(result, 'success');
    });

    test('trace convenience method should handle errors', () async {
      await service.initialize();

      // Test that errors are propagated
      expect(
        () => service.trace('error_operation', () async {
          throw Exception('Test error');
        }),
        throwsException,
      );
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
