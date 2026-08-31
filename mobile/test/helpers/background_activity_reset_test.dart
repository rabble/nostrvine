// ABOUTME: Tests the heal-and-blame reset for BackgroundActivityManager.
// ABOUTME: Covers the fan-out mechanism, the heal, the blame, and the no-op.

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/background_activity_manager.dart';

import 'background_activity_reset.dart';

class _RecordingService implements BackgroundAwareService {
  int resumeCount = 0;

  @override
  String get serviceName => 'RecordingService';

  @override
  void onAppBackgrounded() {}

  @override
  void onExtendedBackground() {}

  @override
  void onAppResumed() => resumeCount++;

  @override
  void onPeriodicCleanup() {}
}

void main() {
  group('healAndBlameBackgroundActivity', () {
    late BackgroundActivityManager manager;

    setUp(() {
      manager = BackgroundActivityManager()..resetForTesting();
    });

    // Every test here dirties the singleton on purpose, so each one restores
    // it before the root tearDown in flutter_test_config.dart inspects it.
    // addTearDown runs at the test's own scope, which is inside that root.
    tearDown(() => manager.resetForTesting());

    group('the mechanism it exists to close', () {
      // A committed cross-test version of this is not possible: deliberately
      // leaking into a later test would itself be blamed under
      // DIVINE_STRICT_GLOBALS. The out-of-isolate proof is in #6880.
      test('resumed fans out to every service still registered', () {
        final probe = _RecordingService();
        manager.registerService(probe);

        manager
          ..onAppLifecycleStateChanged(AppLifecycleState.paused)
          ..onAppLifecycleStateChanged(AppLifecycleState.resumed);

        expect(probe.resumeCount, 1);
      });

      test('a service the reset removed receives no later callback', () {
        final probe = _RecordingService();
        manager.registerService(probe);

        healAndBlameBackgroundActivity(strict: false);

        manager
          ..onAppLifecycleStateChanged(AppLifecycleState.paused)
          ..onAppLifecycleStateChanged(AppLifecycleState.resumed);

        expect(probe.resumeCount, 0);
      });
    });

    group('healing', () {
      test('clears a registration the test left behind', () {
        manager.registerService(_RecordingService());

        healAndBlameBackgroundActivity(strict: false);

        expect(manager.getStatus()['registeredServices'], 0);
      });

      test('clears an initialized manager, and its periodic timer', () async {
        await manager.initialize();
        expect(manager.getStatus()['isInitialized'], isTrue);

        healAndBlameBackgroundActivity(strict: false);

        expect(manager.getStatus()['isInitialized'], isFalse);
      });

      test('restores a background state the test left behind', () {
        manager.onAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(manager.isAppInForeground, isFalse);

        healAndBlameBackgroundActivity(strict: false);

        expect(manager.isAppInForeground, isTrue);
      });
    });

    group('blaming', () {
      test('names the leaked service', () {
        manager.registerService(_RecordingService());

        expect(
          () => healAndBlameBackgroundActivity(strict: true),
          throwsA(
            isA<TestFailure>().having(
              (f) => f.message,
              'message',
              allOf(contains('RecordingService'), contains('#6880')),
            ),
          ),
        );
      });

      test('names a manager left initialized', () async {
        await manager.initialize();

        expect(
          () => healAndBlameBackgroundActivity(strict: true),
          throwsA(
            isA<TestFailure>().having(
              (f) => f.message,
              'message',
              contains('left the manager initialized'),
            ),
          ),
        );
      });

      test('names a leaked background state', () {
        manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

        expect(
          () => healAndBlameBackgroundActivity(strict: true),
          throwsA(
            isA<TestFailure>().having(
              (f) => f.message,
              'message',
              contains('left the app in the background state'),
            ),
          ),
        );
      });

      test('heals even when it blames, so the next test starts clean', () {
        manager.registerService(_RecordingService());

        expect(
          () => healAndBlameBackgroundActivity(strict: true),
          throwsA(isA<TestFailure>()),
        );

        expect(manager.getStatus()['registeredServices'], 0);
      });
    });

    group('compliant tests', () {
      test('a clean manager is never blamed', () {
        expect(
          () => healAndBlameBackgroundActivity(strict: true),
          returnsNormally,
        );
      });

      test('a service that unregisters itself is never blamed', () {
        final probe = _RecordingService();
        manager
          ..registerService(probe)
          ..unregisterService(probe);

        expect(
          () => healAndBlameBackgroundActivity(strict: true),
          returnsNormally,
        );
      });
    });
  });
}
