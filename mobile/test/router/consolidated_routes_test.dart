// ABOUTME: Tests for consolidated routes with optional parameters
// ABOUTME: Verifies single route handles both grid and feed modes without GlobalKey conflicts

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';

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
      'Navigate /search → /search/bitcoin without GlobalKey conflict',
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

        // Start at /search (empty)
        container.read(goRouterProvider).go(SearchScreenPure.path);
        await tester.pumpAndSettle();

        // Navigate to /search/bitcoin (grid with term)
        container
            .read(goRouterProvider)
            .go(SearchScreenPure.pathForTerm(term: 'bitcoin'));
        await tester.pumpAndSettle();

        // Should complete without GlobalKey conflict
        expect(tester.takeException(), isNull);
      },
      // TODO(any): Fix and re-enable these tests
      skip: true,
    );

    testWidgets(
      'Navigate /hashtag/bitcoin → /hashtag/bitcoin/0 without GlobalKey conflict',
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

        // Start at /hashtag/bitcoin (grid)
        container
            .read(goRouterProvider)
            .go(HashtagScreenRouter.pathForTag('bitcoin'));
        await tester.pumpAndSettle();

        // Navigate to /hashtag/bitcoin/0 (feed)
        container
            .read(goRouterProvider)
            .go(HashtagScreenRouter.pathForTag('bitcoin', index: 0));
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

    test('parseRoute handles optional searchTerm and index for search', () {
      final empty = parseRoute(SearchScreenPure.path);
      expect(empty.type, RouteType.search);
      expect(empty.searchTerm, null);
      expect(empty.videoIndex, null);

      final withTerm = parseRoute(
        SearchScreenPure.pathForTerm(term: 'bitcoin'),
      );
      expect(withTerm.type, RouteType.search);
      expect(withTerm.searchTerm, 'bitcoin');
      expect(withTerm.videoIndex, null);

      final withTermAndIndex = parseRoute(
        SearchScreenPure.pathForTerm(term: 'bitcoin', index: 3),
      );
      expect(withTermAndIndex.type, RouteType.search);
      expect(withTermAndIndex.searchTerm, 'bitcoin');
      expect(withTermAndIndex.videoIndex, 3);
    });

    test('parseRoute handles optional index for hashtag', () {
      final gridMode = parseRoute(HashtagScreenRouter.pathForTag('bitcoin'));
      expect(gridMode.type, RouteType.hashtag);
      expect(gridMode.hashtag, 'bitcoin');
      expect(gridMode.videoIndex, null);

      final feedMode = parseRoute(
        HashtagScreenRouter.pathForTag('bitcoin', index: 2),
      );
      expect(feedMode.type, RouteType.hashtag);
      expect(feedMode.hashtag, 'bitcoin');
      expect(feedMode.videoIndex, 2);
    });
  });
}
