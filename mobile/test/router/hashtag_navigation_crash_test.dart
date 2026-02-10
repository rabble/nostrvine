// ABOUTME: Tests for hashtag navigation crash after route consolidation
// ABOUTME: Verifies no "ref after unmount" crashes when switching hashtags

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

void main() {
  group('Hashtag Navigation Crash Test', () {
    testWidgets(
      'rapidly switching hashtags does not crash with ref-after-unmount',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );

        // Navigate to first hashtag
        container
            .read(goRouterProvider)
            .go(HashtagScreenRouter.pathForTag('comedy', index: 0));
        await tester.pump(); // Start navigation
        await tester.pump(const Duration(milliseconds: 100)); // Partial settle

        // Rapidly switch to second hashtag (triggers widget disposal)
        container
            .read(goRouterProvider)
            .go(HashtagScreenRouter.pathForTag('lol', index: 0));
        await tester.pump(); // Start navigation
        await tester.pump(const Duration(milliseconds: 100)); // Partial settle

        // Switch again to ensure postFrameCallbacks don't crash
        container
            .read(goRouterProvider)
            .go(HashtagScreenRouter.pathForTag('nostr', index: 0));
        await tester.pumpAndSettle();

        // Should complete without "ref after unmount" crash
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('navigating from hashtag grid to feed mode works', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to hashtag grid
      container
          .read(goRouterProvider)
          .go(HashtagScreenRouter.pathForTag('bitcoin'));
      await tester.pumpAndSettle();

      // Navigate to feed mode (parameter change on same route)
      container
          .read(goRouterProvider)
          .go(HashtagScreenRouter.pathForTag('bitcoin', index: 0));
      await tester.pumpAndSettle();

      // Should complete without crash
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigating away from hashtag to explore does not crash', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to hashtag
      container
          .read(goRouterProvider)
          .go(HashtagScreenRouter.pathForTag('comedy', index: 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Navigate away to explore (different route)
      container.read(goRouterProvider).go(ExploreScreen.pathForIndex(0));
      await tester.pumpAndSettle();

      // Should complete without crash
      expect(tester.takeException(), isNull);
    });
    // TODO(Any): Fix and re-enable these tests
  }, skip: true);
}
