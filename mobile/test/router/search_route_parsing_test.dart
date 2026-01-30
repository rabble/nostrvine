// ABOUTME: Tests for search route parsing and navigation
// ABOUTME: Verifies /search route is correctly parsed and returns RouteType.search

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';

void main() {
  group('Search route parsing', () {
    test('parseRoute recognizes ${SearchScreenPure.path} path', () {
      final result = parseRoute(SearchScreenPure.path);

      expect(result.type, RouteType.search);
      expect(result.videoIndex, isNull);
      expect(result.npub, isNull);
      expect(result.hashtag, isNull);
    });

    test(
      'buildRoute creates ${SearchScreenPure.path} path for RouteType.search',
      () {
        const context = RouteContext(type: RouteType.search);

        final result = buildRoute(context);

        expect(result, SearchScreenPure.path);
      },
    );

    test('parseRoute handles root search path', () {
      // Verify search at root level without any path segments after
      final result = parseRoute(SearchScreenPure.path);

      expect(result.type, RouteType.search);
    });
  });
}
