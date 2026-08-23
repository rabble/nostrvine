// ABOUTME: Guards main.dart against re-adding a PopScope above MaterialApp
// ABOUTME: Such a PopScope never registers a PopEntry, so its callback is dead

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

void main() {
  group('root PopScope', () {
    // Why the guard below exists. main.dart carried a 120-line
    // handleBackNavigation closure behind a PopScope placed above
    // MaterialApp.router, described in its own comment as the
    // iOS/macOS/Windows back behaviour. It had never run: PopScope delivers
    // onPopInvokedWithResult only through a PopEntry registered on the
    // ModalRoute returned by ModalRoute.of(context), and there is no
    // ModalRoute above MaterialApp. Being unreachable is why that copy of
    // the back logic drifted from the two that do run (#3337).
    testWidgets('is inert above MaterialApp, and works inside a route', (
      tester,
    ) async {
      var rootInvocations = 0;
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            builder: (_, _) => const Scaffold(body: Text('A')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (_, _) => rootInvocations++,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        rootInvocations,
        isZero,
        reason: 'a PopScope above MaterialApp never registers a PopEntry',
      );

      var inRouteInvocations = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (_, _) => inRouteInvocations++,
            child: const Scaffold(body: Text('A')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(
        inRouteInvocations,
        equals(1),
        reason: 'control: the identical PopScope inside a route does fire',
      );
    });

    test('is not reintroduced in main.dart', () {
      final source = File('lib/main.dart').readAsStringSync();

      expect(
        source,
        isNot(contains('PopScope')),
        reason:
            'A PopScope in main.dart sits above MaterialApp.router and is '
            'dead (see the widget test above). App-level back interception '
            'belongs in resolveBackAction, reached through '
            'BackButtonHandler on Android and the shell app bar elsewhere. '
            'If you genuinely need to intercept above a Router, the '
            'supported widget is NavigatorPopHandler.',
      );
    });
  });
}
