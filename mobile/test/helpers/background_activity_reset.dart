// ABOUTME: Heals and blames leaks of the process-global BackgroundActivityManager.
// ABOUTME: Registrations and the foreground flag survive a test unless reset.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/background_activity_manager.dart';

/// Describes how a test left [BackgroundActivityManager], or `null` when it
/// left it at its resting state.
///
/// The manager is a process-global singleton and `flutter_test` restores
/// nothing between tests, so under `very_good test --optimization` both halves
/// below persist for the remainder of the merged isolate.
String? findBackgroundActivityViolation() {
  final manager = BackgroundActivityManager();
  final status = manager.getStatus();
  final services = (status['serviceNames']! as List).cast<String>();
  final backgrounded = status['isAppInForeground'] == false;
  final initialized = status['isInitialized'] == true;
  if (services.isEmpty && !backgrounded && !initialized) return null;

  final parts = <String>[
    if (services.isNotEmpty) 'left ${services.join(', ')} registered',
    if (backgrounded) 'left the app in the background state',
    if (initialized)
      'left the manager initialized, with its periodic cleanup timer armed',
  ];
  return parts.join(' and ');
}

/// Restores the manager and, under [strict], fails the test that dirtied it.
///
/// Healing runs first so each test is blamed only for its own leak instead of
/// every later test inheriting the first one's. Compliant tests never trip it.
void healAndBlameBackgroundActivity({required bool strict}) {
  final violation = findBackgroundActivityViolation();
  if (violation == null) return;
  BackgroundActivityManager().resetForTesting();
  if (strict) {
    fail(
      'This test $violation. BackgroundActivityManager is a process-global '
      'singleton, so under very_good --optimization every later suite in the '
      'isolate inherits it: a registered service keeps receiving lifecycle '
      'callbacks, and a stale background state turns the next `resumed` into '
      'a fan-out over all of them, cross-attributing the result to an '
      'unrelated test (#6880). Dispose the service you created (services '
      'unregister in dispose()), or addTearDown '
      '(BackgroundActivityManager().resetForTesting). '
      'See .claude/rules/testing.md (VGV merged isolate).',
    );
  }
}
