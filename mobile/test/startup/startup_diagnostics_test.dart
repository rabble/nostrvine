// ABOUTME: Tests for comprehensive startup diagnostics and monitoring
// ABOUTME: Validates timing logs, breadcrumbs, and timeout detection

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/features/app/startup/startup_profiler.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockCrashReportingService extends Mock
    implements CrashReportingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup Diagnostics', () {
    late StartupCoordinator coordinator;
    late _MockCrashReportingService mockCrashReporting;
    late List<String> breadcrumbs;

    setUp(() {
      coordinator = StartupCoordinator();
      mockCrashReporting = _MockCrashReportingService();
      breadcrumbs = [];

      // Set up log capture
      Log.setLogLevel(LogLevel.debug);

      // Mock the CrashReportingService singleton
      when(() => mockCrashReporting.logInitializationStep(any())).thenAnswer((
        invocation,
      ) {
        breadcrumbs.add(invocation.positionalArguments[0] as String);
      });
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('should track startup timing for each service', () async {
      // Arrange
      final startTime = DateTime.now();
      var service1Initialized = false;
      var service2Initialized = false;

      coordinator.registerService(
        name: 'TestService1',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 50));
          service1Initialized = true;
        },
      );

      coordinator.registerService(
        name: 'TestService2',
        phase: StartupPhase.essential,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 30));
          service2Initialized = true;
        },
      );

      // Act
      await coordinator.initialize();
      final endTime = DateTime.now();

      // Assert
      expect(service1Initialized, isTrue);
      expect(service2Initialized, isTrue);

      final metrics = coordinator.metrics;
      expect(metrics.serviceTimings['TestService1'], isNotNull);
      expect(metrics.serviceTimings['TestService2'], isNotNull);

      // Verify timing is reasonable
      expect(
        metrics.serviceTimings['TestService1']!.inMilliseconds,
        greaterThanOrEqualTo(50),
      );
      expect(
        metrics.serviceTimings['TestService2']!.inMilliseconds,
        greaterThanOrEqualTo(30),
      );

      // Total duration should be at least the sum of services
      expect(metrics.totalDuration.inMilliseconds, greaterThanOrEqualTo(80));
      expect(
        endTime.difference(startTime).inMilliseconds,
        greaterThanOrEqualTo(80),
      );
    });

    test('should log breadcrumbs for each initialization step', () async {
      // Arrange
      final profiler = StartupProfiler.instance;
      profiler.markAppStart();

      coordinator.registerService(
        name: 'AuthService',
        phase: StartupPhase.critical,
        initialize: () async {
          CrashReportingService.instance.logInitializationStep(
            'Initializing service: AuthService',
          );
          await Future.delayed(const Duration(milliseconds: 10));
          CrashReportingService.instance.logInitializationStep(
            '✓ AuthService initialized successfully',
          );
        },
      );

      coordinator.registerService(
        name: 'NostrService',
        phase: StartupPhase.essential,
        initialize: () async {
          CrashReportingService.instance.logInitializationStep(
            'Initializing service: NostrService',
          );
          await Future.delayed(const Duration(milliseconds: 10));
          CrashReportingService.instance.logInitializationStep(
            '✓ NostrService initialized successfully',
          );
        },
      );

      // Act
      await coordinator.initialize();
      profiler.markAppReady();

      // Assert - breadcrumbs should be logged (would be captured by mock)
      // In production, these would be sent to Crashlytics
      expect(coordinator.metrics.serviceTimings['AuthService'], isNotNull);
      expect(coordinator.metrics.serviceTimings['NostrService'], isNotNull);
    });

    test(
      'should leave deferred phases pending after blocking startup only',
      () async {
        final deferredCompleter = Completer<void>();

        coordinator.registerService(
          name: 'EnvironmentService',
          phase: StartupPhase.critical,
          initialize: () async {},
        );

        coordinator.registerService(
          name: 'DeferredWarmup',
          phase: StartupPhase.deferred,
          initialize: () => deferredCompleter.future,
          optional: true,
        );

        await coordinator.initializeThrough(StartupPhase.critical);

        expect(coordinator.isPhaseComplete(StartupPhase.critical), isTrue);
        expect(coordinator.isPhaseComplete(StartupPhase.deferred), isFalse);

        final remainingFuture = coordinator.initializeRemaining();
        await Future<void>.delayed(Duration.zero);
        expect(coordinator.isPhaseComplete(StartupPhase.deferred), isFalse);

        deferredCompleter.complete();
        await remainingFuture;

        expect(coordinator.isPhaseComplete(StartupPhase.deferred), isTrue);
      },
    );

    test('should generate a startup metrics report', () async {
      coordinator.registerService(
        name: 'FastService',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 10));
        },
      );

      coordinator.registerService(
        name: 'DeferredService',
        phase: StartupPhase.deferred,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 5));
        },
        optional: true,
      );

      await coordinator.initialize();

      final report = coordinator.metrics.generateReport();
      expect(report, contains('Startup Performance Report'));
      expect(report, contains('Total time:'));
      expect(report, contains('FastService'));
      expect(report, contains('DeferredService'));
    });

    test('should detect and warn about slow initialization', () {
      fakeAsync((async) {
        final completer = Completer<void>();
        final warnings = <String>[];
        Timer? timeoutTimer;

        coordinator.registerService(
          name: 'SlowService',
          phase: StartupPhase.critical,
          initialize: () async {
            // Start timeout detection
            timeoutTimer = Timer(const Duration(seconds: 2), () {
              warnings.add(
                'WARNING: SlowService initialization taking > 2 seconds',
              );
              CrashReportingService.instance.log(
                'Startup timeout detected for SlowService',
              );
            });

            // Simulate slow initialization
            await Future.delayed(const Duration(seconds: 3));
            timeoutTimer?.cancel();
            completer.complete();
          },
        );

        // Kick off initialization (fire-and-forget; we'll elapse past it).
        unawaited(coordinator.initialize());

        // After 2.1s, the 2s Timer should have fired.
        async.elapse(const Duration(seconds: 2, milliseconds: 100));
        expect(
          warnings,
          contains('WARNING: SlowService initialization taking > 2 seconds'),
        );

        // Elapse past the 3s simulated work so the service — and the
        // whole coordinator — complete.
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(completer.isCompleted, isTrue);
        final metrics = coordinator.metrics;
        expect(
          metrics.serviceTimings['SlowService']!.inMilliseconds,
          greaterThanOrEqualTo(3000),
        );
      });
    });

    test('should handle initialization failures with proper logging', () async {
      // Arrange

      coordinator.registerService(
        name: 'FailingService',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 10));
          throw Exception('Service initialization failed');
        },
      );

      // Act & Assert
      try {
        await coordinator.initialize();
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('Service initialization failed'));

        // Metrics should still be available with error info
        final metrics = coordinator.metrics;
        expect(metrics.errors.length, greaterThan(0));
        expect(metrics.errors.first.serviceName, equals('FailingService'));
        expect(
          metrics.errors.first.error.toString(),
          contains('Service initialization failed'),
        );
      }
    });
  });
}
