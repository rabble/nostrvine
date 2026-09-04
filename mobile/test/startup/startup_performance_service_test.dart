// ABOUTME: Tests for StartupPerformanceService auth shell readiness
// ABOUTME: Each test builds its own instance, so no state crosses tests

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(StartupPerformanceService, () {
    late StartupPerformanceService service;

    setUp(() {
      // A fresh instance per test. Before #4743 this was
      // `StartupPerformanceService.instance`, so every test inherited the
      // latch state of the one before it — which is what made the
      // idempotency test below unable to fail.
      service = StartupPerformanceService(
        crashReporting: CrashReportingService(),
      );
    });

    group('markAuthShellReady', () {
      test('sets authShellReadyTime', () async {
        await service.initialize();

        service.markAuthShellReady();

        expect(service.authShellReadyTime, isNotNull);
      });

      test(
        'is a no-op before initialize, because there is no start time',
        () async {
          service.markAuthShellReady();

          expect(service.authShellReadyTime, isNull);
        },
      );

      test('latches first-write-wins and ignores later calls', () async {
        await service.initialize();

        service.markAuthShellReady();
        final firstTime = service.authShellReadyTime;

        // Regression guard (#4743): asserting only `second == first` passes
        // when the method never runs at all, since null == null. Pinning the
        // latch as non-null first is what makes this test able to fail — it
        // survived a total no-op mutant before the DI conversion.
        expect(firstTime, isNotNull);

        service.markAuthShellReady();

        expect(service.authShellReadyTime, equals(firstTime));
      });
    });

    group('getMetrics', () {
      test(
        'reports auth shell readiness separately from UI readiness',
        () async {
          await service.initialize();

          service.markAuthShellReady();

          expect(service.authShellReadyTime, isNotNull);
          expect(service.getMetrics()['auth_shell_ready_ms'], isA<int>());
        },
      );
    });

    group('isolation', () {
      test('a new instance does not inherit another instance latch', () async {
        await service.initialize();
        service.markAuthShellReady();
        expect(service.authShellReadyTime, isNotNull);

        final other = StartupPerformanceService(
          crashReporting: CrashReportingService(),
        );

        expect(other.authShellReadyTime, isNull);
      });
    });
  });
}
