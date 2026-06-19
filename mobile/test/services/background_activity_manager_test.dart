// Test for BackgroundActivityManager functionality
// Permanent: exercises process-wide WidgetsBinding lifecycle notifications and
// BackgroundActivityManager singleton state; keep isolated until the manager is
// injectable/resettable per test.
@Tags(['skip_very_good_optimization'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/background_activity_manager.dart';

class TestBackgroundService implements BackgroundAwareService {
  @override
  String get serviceName => 'TestService';

  bool backgroundCalled = false;
  bool extendedBackgroundCalled = false;
  bool resumedCalled = false;
  bool cleanupCalled = false;

  @override
  void onAppBackgrounded() {
    backgroundCalled = true;
  }

  @override
  void onExtendedBackground() {
    extendedBackgroundCalled = true;
  }

  @override
  void onAppResumed() {
    resumedCalled = true;
  }

  @override
  void onPeriodicCleanup() {
    cleanupCalled = true;
  }
}

/// Service whose [onAppBackgrounded] throws synchronously — used to assert
/// the manager isolates failures and keeps processing remaining services.
class _ThrowingBackgroundService implements BackgroundAwareService {
  bool entered = false;

  @override
  String get serviceName => 'ThrowingService';

  @override
  void onAppBackgrounded() {
    entered = true;
    throw StateError('boom');
  }

  @override
  void onExtendedBackground() {}

  @override
  void onAppResumed() {}

  @override
  void onPeriodicCleanup() {}
}

void main() {
  group('BackgroundActivityManager', () {
    late BackgroundActivityManager manager;
    late TestBackgroundService testService;

    setUp(() async {
      manager = BackgroundActivityManager();
      manager.dispose();
      testService = TestBackgroundService();

      // BackgroundActivityManager is a process-wide singleton. Tests in this
      // file share the same instance and run in random order, so clear any
      // prior registrations/timers, reset its state to foreground, and drain
      // pending lifecycle notifications before each test. Otherwise a prior
      // test can leak services or stale background state into the next case.
      manager.onAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
    });

    test('should start in foreground state', () {
      expect(manager.isAppInForeground, isTrue);
      expect(manager.isAppInBackground, isFalse);
    });

    test('should register and notify services', () async {
      manager.registerService(testService);
      addTearDown(() => manager.unregisterService(testService));

      // Simulate app going to background
      manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(manager.isAppInBackground, isTrue);

      // _performImmediateBackgroundActions wraps each service notification in
      // `Future.microtask(() async { await Future(fn).timeout(...); })`, so
      // the notification chain is microtask → Timer(0) → completion. Drain
      // the event queue deterministically instead of relying on a fixed
      // wall-clock delay, which is flaky under CI load.
      await pumpEventQueue();

      expect(testService.backgroundCalled, isTrue);
    });

    test(
      'isolates a throwing service so remaining services still get notified',
      () async {
        final throwing = _ThrowingBackgroundService();
        manager.registerService(throwing);
        manager.registerService(testService);
        addTearDown(() {
          manager.unregisterService(throwing);
          manager.unregisterService(testService);
        });

        manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

        // Same drain pattern as 'should register and notify services' —
        // the per-service notification chain is microtask → completion.
        await pumpEventQueue();

        expect(throwing.entered, isTrue);
        // The healthy service still received its notification despite the
        // sibling service throwing inside the same suspend pass.
        expect(testService.backgroundCalled, isTrue);
      },
    );

    test('should handle app resume', () async {
      manager.registerService(testService);
      addTearDown(() => manager.unregisterService(testService));

      // Go to background then resume
      manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

      // Drain the background notification chain before transitioning back.
      await pumpEventQueue();

      manager.onAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(manager.isAppInForeground, isTrue);
      expect(testService.resumedCalled, isTrue);
    });

    test('should unregister services', () {
      final initialCount = manager.getStatus()['registeredServices'] as int;

      manager.registerService(testService);
      expect(
        manager.getStatus()['registeredServices'],
        equals(initialCount + 1),
      );

      manager.unregisterService(testService);
      expect(manager.getStatus()['registeredServices'], equals(initialCount));
    });

    test('should provide status information', () {
      manager.registerService(testService);
      addTearDown(() => manager.unregisterService(testService));

      final status = manager.getStatus();
      expect(status['isAppInForeground'], isTrue);
      expect(status['registeredServices'], greaterThanOrEqualTo(1));
      expect(status['serviceNames'], contains('TestService'));
    });
  });
}
