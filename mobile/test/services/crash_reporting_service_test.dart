// ABOUTME: Tests for CrashReportingService's uninitialized contract
// ABOUTME: Possible at all because #4743 gave the service a public constructor

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/crash_reporting_service.dart';

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
      // Every reporting method opens with `if (!_initialized) return;`. That
      // makes them inert until initialize() succeeds — and permanently inert if
      // Firebase initialisation throws, because the flag is only set on the
      // success path. These tests pin that as the *documented* contract rather
      // than an accident, and they are what a fix would have to change.
      //
      // Whether that silently loses a report in production is tracked
      // separately; it needs Crashlytics telemetry, not a unit test.

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
