// ABOUTME: Tests for consolidated routes with optional parameters
// ABOUTME: Verifies single route handles both grid and feed modes without GlobalKey conflicts

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

void main() {
  group('Consolidated Route Tests', () {
    testWidgets('Navigate /explore → /explore/0 without GlobalKey conflict', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Start at /explore (grid mode)
      container.read(goRouterProvider).go(ExploreScreen.path);
      await tester.pumpAndSettle();

      // Navigate to /explore/0 (feed mode)
      container.read(goRouterProvider).go(ExploreScreen.pathForIndex(0));
      await tester.pumpAndSettle();

      // Should complete without GlobalKey conflict
      expect(tester.takeException(), isNull);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets(
      'Navigate to /hashtag/bitcoin without GlobalKey conflict',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );

        // Navigate to /hashtag/bitcoin (grid)
        container
            .read(goRouterProvider)
            .go(HashtagScreenRouter.pathForTag('bitcoin'));
        await tester.pumpAndSettle();

        // Should complete without GlobalKey conflict
        expect(tester.takeException(), isNull);
      },
      // TODO(any): Fix and re-enable these tests
      skip: true,
    );

    test('parseRoute handles optional index for explore', () {
      final gridMode = parseRoute(ExploreScreen.path);
      expect(gridMode.type, RouteType.explore);
      expect(gridMode.videoIndex, null);

      final feedMode = parseRoute(ExploreScreen.pathForIndex(5));
      expect(feedMode.type, RouteType.explore);
      expect(feedMode.videoIndex, 5);
    });

    test('parseRoute handles hashtag grid mode', () {
      final gridMode = parseRoute(HashtagScreenRouter.pathForTag('bitcoin'));
      expect(gridMode.type, RouteType.hashtag);
      expect(gridMode.hashtag, 'bitcoin');
      expect(gridMode.videoIndex, null);
    });
  });
}
