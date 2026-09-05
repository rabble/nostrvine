// ABOUTME: Tests for how CrashReportingService treats reports around initialize()
// ABOUTME: Possible at all because #4743 gave the service a public constructor

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

/// A Crashlytics that accepts everything initialize() and a replay send it.
void _stubHealthyCrashlytics(_MockFirebaseCrashlytics crashlytics) {
  when(() => crashlytics.setCustomKey(any(), any())).thenAnswer((_) async {});
  when(
    () => crashlytics.setCrashlyticsCollectionEnabled(any()),
  ).thenAnswer((_) async {});
  when(() => crashlytics.isCrashlyticsCollectionEnabled).thenReturn(false);
  when(() => crashlytics.log(any())).thenAnswer((_) async {});
  when(
    () => crashlytics.recordError(any(), any(), reason: any(named: 'reason')),
  ).thenAnswer((_) async {});
  when(() => crashlytics.setUserIdentifier(any())).thenAnswer((_) async {});
}

/// Error-level entries written by the service that carry [marker].
Iterable<LogEntry> _errorEntriesMentioning(String marker) => LogCaptureService()
    .getRecentLogs(minLevel: LogLevel.error)
    .where(
      (entry) =>
          entry.name == 'CrashReporting' &&
          (entry.error?.contains(marker) ?? false),
    );

/// Warning-level entries whose message contains [pattern].
Iterable<LogEntry> _warningsMatching(Pattern pattern) => LogCaptureService()
    .getRecentLogs(minLevel: LogLevel.warning)
    .where((entry) => entry.message.contains(pattern));

String _uniqueMarker(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => registerFallbackValue(Object()));

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
        final marker = _uniqueMarker('pre-init');

        await service.recordError(
          StateError(marker),
          StackTrace.current,
          reason: 'pre-init test',
        );

        expect(_errorEntriesMentioning(marker), hasLength(1));
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

    group('initialize succeeds', () {
      late _MockFirebaseCrashlytics crashlytics;
      var firebaseStarts = 0;

      setUp(() {
        crashlytics = _MockFirebaseCrashlytics();
        _stubHealthyCrashlytics(crashlytics);
        firebaseStarts = 0;
        service = CrashReportingService(
          initializeFirebase: () async => firebaseStarts++,
          crashlytics: () => crashlytics,
        );
        // initialize() installs the process-wide Flutter error handlers, which
        // would otherwise leak into every later test in the merged isolate.
        final originalOnError = FlutterError.onError;
        final originalPlatformOnError = PlatformDispatcher.instance.onError;
        addTearDown(() {
          FlutterError.onError = originalOnError;
          PlatformDispatcher.instance.onError = originalPlatformOnError;
        });
      });

      test('forwards a report recorded before initialize resolved', () async {
        final error = StateError('held for Crashlytics');
        final stack = StackTrace.current;
        await service.recordError(error, stack, reason: 'startup');
        verifyNever(
          () => crashlytics.recordError(
            any(),
            any(),
            reason: any(named: 'reason'),
          ),
        );

        await service.initialize();

        verify(
          () => crashlytics.recordError(error, stack, reason: 'startup'),
        ).called(1);
      });

      test('replays held calls in the order they were made', () async {
        service.log('first breadcrumb');
        await service.setCustomKey('phase', 'bindings');
        service.log('second breadcrumb');
        await service.setUserId('someone');

        await service.initialize();

        verifyInOrder([
          () => crashlytics.log('first breadcrumb'),
          () => crashlytics.setCustomKey('phase', 'bindings'),
          () => crashlytics.log('second breadcrumb'),
          () => crashlytics.setUserIdentifier('someone'),
        ]);
      });

      test('forwards calls made after initialize as they arrive', () async {
        await service.initialize();

        service.log('live breadcrumb');
        await service.recordError(StateError('live'), null, reason: 'now');

        verify(() => crashlytics.log('live breadcrumb')).called(1);
        verify(
          () => crashlytics.recordError(any(), null, reason: 'now'),
        ).called(1);
      });

      test(
        'keeps the earliest calls when more than the capacity are held',
        () async {
          const capacity = CrashReportingService.pendingReportCapacity;
          for (var i = 0; i < capacity + 8; i++) {
            service.log('crumb $i');
          }

          await service.initialize();

          final replayed = verify(() => crashlytics.log(captureAny())).captured
              .cast<String>()
              .where((message) => message.startsWith('crumb'))
              .toList();
          expect(replayed, List.generate(capacity, (i) => 'crumb $i'));
          expect(
            _warningsMatching(RegExp(r'\b8 Crashlytics call')),
            isNotEmpty,
          );
        },
      );

      test(
        'a second initialize neither restarts Firebase nor replays',
        () async {
          service.log('once');

          await service.initialize();
          await service.initialize();

          verify(() => crashlytics.log('once')).called(1);
          expect(firebaseStarts, 1);
        },
      );

      test('a completion-log failure does not revoke readiness', () async {
        when(
          () => crashlytics.isCrashlyticsCollectionEnabled,
        ).thenReturn(true);
        when(
          () => crashlytics.log(any()),
        ).thenThrow(StateError('completion log failed'));

        await service.initialize();
        await service.setCustomKey('still', 'ready');

        verify(() => crashlytics.setCustomKey('still', 'ready')).called(1);
      });
    });

    group('initialize fails', () {
      late _MockFirebaseCrashlytics crashlytics;
      var firebaseStarts = 0;

      setUp(() {
        crashlytics = _MockFirebaseCrashlytics();
        firebaseStarts = 0;
        service = CrashReportingService(
          initializeFirebase: () async {
            firebaseStarts++;
            throw StateError('no Firebase here');
          },
          crashlytics: () => crashlytics,
        );
      });

      test('discards held calls and says how many', () async {
        service.log('one');
        service.log('two');

        await service.initialize();

        verifyZeroInteractions(crashlytics);
        expect(_warningsMatching(RegExp(r'\b2 Crashlytics call')), isNotEmpty);
      });

      test('the discarded count includes calls beyond capacity', () async {
        const capacity = CrashReportingService.pendingReportCapacity;
        for (var i = 0; i < capacity + 8; i++) {
          service.log('call $i');
        }

        await service.initialize();

        expect(_warningsMatching(RegExp(r'\b40 Crashlytics call')), isNotEmpty);
      });

      test(
        'recordError afterwards still writes the error to the unified log',
        () async {
          await service.initialize();
          final marker = _uniqueMarker('after-failure');

          await service.recordError(StateError(marker), StackTrace.current);

          expect(_errorEntriesMentioning(marker), hasLength(1));
          verifyZeroInteractions(crashlytics);
        },
      );

      test('log afterwards is dropped without reaching Firebase', () async {
        await service.initialize();

        service.log('after failure');

        verifyZeroInteractions(crashlytics);
      });

      test(
        'a second initialize does not retry failed Firebase setup',
        () async {
          await service.initialize();
          await service.initialize();

          expect(firebaseStarts, 1);
          verifyZeroInteractions(crashlytics);
        },
      );
    });

    group('unsupported platform', () {
      test(
        'skips Firebase and still writes errors to the unified log',
        () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.linux;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          var firebaseStarted = false;
          final crashlytics = _MockFirebaseCrashlytics();
          service = CrashReportingService(
            initializeFirebase: () async => firebaseStarted = true,
            crashlytics: () => crashlytics,
          );
          service.log('desktop breadcrumb');

          await service.initialize();
          final marker = _uniqueMarker('desktop');
          await service.recordError(StateError(marker), null);

          expect(firebaseStarted, isFalse);
          verifyZeroInteractions(crashlytics);
          expect(_errorEntriesMentioning(marker), hasLength(1));
        },
      );
    });
  });
}
