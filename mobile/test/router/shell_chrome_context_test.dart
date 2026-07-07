// ABOUTME: Unit tests for resolveShellChromeContext (shell app bar freezing)
// ABOUTME: Regression: camera/editor pushed above the shell must not pop the
// ABOUTME: app bar in/out mid-transition (own-profile grid & inbox shift-down).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';

void main() {
  // An own-profile grid / inbox tab suppresses the shell app bar; the recorder
  // is a full-screen route pushed *above* the whole shell.
  const profile = RouteContext(type: RouteType.profile, npub: 'me');
  const inbox = RouteContext(type: RouteType.inbox);
  const recorder = RouteContext(type: RouteType.videoRecorder);

  group('resolveShellChromeContext', () {
    test('uses and caches the live context while the shell is on top', () {
      final result = resolveShellChromeContext(
        isShellCovered: false,
        liveContext: profile,
        lastTabContext: inbox,
      );

      expect(result.context, profile);
      expect(result.nextCache, profile);
    });

    test('freezes to the cached tab context while the shell is covered', () {
      // Camera pushed over an own-profile grid: the global pageContext flips
      // to the recorder, but the chrome must keep rendering the tab beneath so
      // the suppressed app bar does not pop in during the push transition.
      final result = resolveShellChromeContext(
        isShellCovered: true,
        liveContext: recorder,
        lastTabContext: profile,
      );

      expect(result.context, profile);
      expect(
        result.nextCache,
        profile,
        reason: 'cache untouched while covered',
      );
    });

    test(
      'keeps the previous cache when uncovered but live context is null',
      () {
        final result = resolveShellChromeContext(
          isShellCovered: false,
          liveContext: null,
          lastTabContext: profile,
        );

        expect(result.context, isNull);
        expect(result.nextCache, profile);
      },
    );

    test('falls back to the live context while covered with no cache yet', () {
      final result = resolveShellChromeContext(
        isShellCovered: true,
        liveContext: recorder,
        lastTabContext: null,
      );

      expect(result.context, recorder);
      expect(result.nextCache, isNull);
    });
  });
}
