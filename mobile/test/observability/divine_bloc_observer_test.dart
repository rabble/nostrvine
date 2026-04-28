// ABOUTME: Tests for DivineBlocObserver — gates Crashlytics forwarding on
// ABOUTME: ReportableError, sanitizes the reason annotation, and preserves
// ABOUTME: Log.error coverage for every Bloc onError trigger.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/observability/divine_bloc_observer.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/crash_reporting_service.dart';

class _MockCrashReportingService extends Mock
    implements CrashReportingService {}

class _CountCubit extends Cubit<int> {
  _CountCubit() : super(0);

  void boom(Object error, StackTrace stackTrace) => addError(error, stackTrace);
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  group(DivineBlocObserver, () {
    late _MockCrashReportingService mockCrash;
    late DivineBlocObserver observer;

    setUp(() {
      mockCrash = _MockCrashReportingService();
      when(
        () => mockCrash.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      observer = DivineBlocObserver(crashReporting: mockCrash);
    });

    test('forwards Reportable errors to CrashReportingService.recordError', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      final stack = StackTrace.current;
      final error = Reportable(StateError('boom'), context: 'test');

      observer.onError(cubit, error, stack);

      verify(
        () => mockCrash.recordError(
          error,
          stack,
          reason: 'Bloc.addError _CountCubit',
        ),
      ).called(1);
    });

    test('annotates the report with the bloc runtime type', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      observer.onError(
        cubit,
        Reportable(StateError('x')),
        StackTrace.current,
      );

      verify(
        () => mockCrash.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any(named: 'reason', that: contains('_CountCubit')),
        ),
      ).called(1);
    });

    test('does not forward non-Reportable errors to Crashlytics', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      observer.onError(cubit, Exception('domain failure'), StackTrace.current);

      verifyNever(
        () => mockCrash.recordError(
          any<dynamic>(),
          any<StackTrace?>(),
          reason: any(named: 'reason'),
        ),
      );
    });

    test('records a Reportable whose toString sanitizes npub identifiers', () {
      final cubit = _CountCubit();
      addTearDown(cubit.close);

      const npub =
          'npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvw';
      final error = Reportable(
        StateError('No public key for $npub during cold start'),
        context: '_publishLike',
      );

      observer.onError(cubit, error, StackTrace.current);

      final captured = verify(
        () => mockCrash.recordError(
          captureAny<dynamic>(),
          any<StackTrace?>(),
          reason: any(named: 'reason'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.single.toString(), contains('npub1<redacted>'));
      expect(captured.single.toString(), isNot(contains(npub)));
    });

    test(
      'integration: addError(Reportable) on a Cubit triggers recordError once',
      () async {
        final previousObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = previousObserver);

        final cubit = _CountCubit();
        addTearDown(cubit.close);

        cubit.boom(
          Reportable(Exception('e2e'), context: 'integration'),
          StackTrace.current,
        );

        // addError dispatches to the bloc error stream via a microtask;
        // drain it before verifying the synchronous expectation.
        await Future<void>.delayed(Duration.zero);

        verify(
          () => mockCrash.recordError(
            any<dynamic>(that: isA<ReportableError>()),
            any<StackTrace?>(),
            reason: 'Bloc.addError _CountCubit',
          ),
        ).called(1);
      },
    );
  });
}
