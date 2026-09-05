// ABOUTME: Tests for CrashReportingService's uninitialized contract
// ABOUTME: Possible at all because #4743 gave the service a public constructor

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(CrashReportingService, () {
    late CrashReportingService service;

    setUp(() {
      // A fresh instance per test. Before #4743 this was a lazy static, so a
      // test could only ever observe whatever state the process was already in.
      service = CrashReportingService();
    });

    group('construction', () {
      test('builds without touching Firebase', () {
        expect(CrashReportingService.new, returnsNormally);
      });

      test('satisfies the CrashReporter port deep services depend on', () {
        expect(service, isA<CrashReporter>());
      });

      test('two instances are independent', () {
        expect(service, isNot(same(CrashReportingService())));
      });
    });

    group('before initialize', () {
      // The runZonedGuarded handler is armed before initialize() runs, so
      // whatever it catches in that window arrives here first. Nothing may
      // vanish: an error is written to the unified log immediately, and every
      // call is held for Crashlytics until initialize() decides whether
      // Crashlytics exists (#8616).

      test('recordError writes the error to the unified log', () async {
        final marker = 'pre-init-${DateTime.now().microsecondsSinceEpoch}';

        await service.recordError(
          StateError(marker),
          StackTrace.current,
          reason: 'pre-init test',
        );

        final logged = LogCaptureService()
            .getRecentLogs(minLevel: LogLevel.error)
            .where(
              (entry) =>
                  entry.name == 'CrashReporting' &&
                  (entry.error?.contains(marker) ?? false),
            );
        expect(logged, hasLength(1));
      });

      test('recordError completes instead of throwing', () async {
        await expectLater(
          service.recordError(StateError('boom'), StackTrace.current),
          completes,
        );
      });

      test('log completes instead of throwing', () {
        expect(() => service.log('breadcrumb'), returnsNormally);
      });

      test('setCustomKey completes instead of throwing', () async {
        await expectLater(service.setCustomKey('k', 'v'), completes);
      });

      test('setUserId completes instead of throwing', () async {
        await expectLater(service.setUserId('someone'), completes);
      });

      test('logInitializationStep completes instead of throwing', () {
        expect(() => service.logInitializationStep('step'), returnsNormally);
      });
    });
  });
}
