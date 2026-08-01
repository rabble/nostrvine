// ABOUTME: Pins the launch-time media-download suspension policy from main.dart.
// ABOUTME: Guards the background-launch case that lifecycle transitions miss.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart';

void main() {
  group('shouldSuspendDownloadsAtLaunch', () {
    test('suspends when the app starts in a background state', () {
      // A silent push or a background upload completion launches the process
      // without ever resuming it, so no `paused` transition follows to tear
      // in-flight NSURLSession requests down before iOS suspends the isolate.
      for (final state in [
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
        AppLifecycleState.inactive,
      ]) {
        expect(
          shouldSuspendDownloadsAtLaunch(state),
          isTrue,
          reason: '$state must start suspended',
        );
      }
    });

    test('does not suspend a foreground launch', () {
      expect(
        shouldSuspendDownloadsAtLaunch(AppLifecycleState.resumed),
        isFalse,
      );
    });

    test('does not suspend when the engine has not reported a state yet', () {
      // Latching here would leave downloads off for a foreground launch that
      // never sends a `resumed` transition to lift them.
      expect(shouldSuspendDownloadsAtLaunch(null), isFalse);
    });
  });
}
