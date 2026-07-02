// ABOUTME: Pins the transition-free shell page on the root navigator
// ABOUTME: Regression test for the startup/login sign-in-page glimpse (#5242)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/router/routes/shell.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  @override
  ValueKey<String> get pageKey => const ValueKey('shell');
}

class _FakeNavigationShell extends Fake
    with Diagnosticable
    implements StatefulNavigationShell {
  @override
  int get currentIndex => 0;
}

void main() {
  group('bottom-nav shell route', () {
    testWidgets('builds a zero-duration page on the root navigator', (
      tester,
    ) async {
      final shellRoute = shellRoutes().single as StatefulShellRoute;

      // The shell replaces /welcome on the root navigator when the
      // authenticated redirect lands (startup restore, login), and the
      // startup splash lifts at the start of that navigation. A `builder:`
      // here would fall back to a default MaterialPage whose ~400ms slide
      // shows the welcome screen exiting — the sign-in glimpse of #5242.
      expect(
        shellRoute.pageBuilder,
        isNotNull,
        reason:
            'The shell StatefulShellRoute must use pageBuilder (not '
            'builder) so the welcome→home startup redirect swaps without '
            'a visible transition.',
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      final context = tester.element(find.byType(SizedBox));

      final page = shellRoute.pageBuilder!(
        context,
        _FakeGoRouterState(),
        _FakeNavigationShell(),
      );

      expect(page, isA<NoTransitionPage<void>>());
      final transitionPage = page as NoTransitionPage<void>;
      expect(transitionPage.transitionDuration, Duration.zero);
      expect(transitionPage.reverseTransitionDuration, Duration.zero);
      expect(transitionPage.key, const ValueKey('shell'));
      expect(transitionPage.child, isA<AppShell>());
    });
  });
}
