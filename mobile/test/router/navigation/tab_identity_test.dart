// ABOUTME: Pins the single RouteType <-> bottom-nav tab mapping (#3337)
// ABOUTME: RouteType.inbox -> 2 is the fix for Android back closing the app

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/navigation/tab_identity.dart';
import 'package:openvine/router/providers/page_context_provider.dart';

void main() {
  group('tabIndexFromRouteType', () {
    const owned = <RouteType, int>{
      RouteType.home: 0,
      RouteType.explore: 1,
      RouteType.hashtag: 1,
      RouteType.notifications: 2,
      RouteType.inbox: 2,
      RouteType.profile: 3,
    };

    owned.forEach((type, expected) {
      test('maps $type to tab $expected', () {
        expect(tabIndexFromRouteType(type), equals(expected));
      });
    });

    test('returns null for every route no bottom-nav tab owns', () {
      final unowned = RouteType.values.where((t) => !owned.containsKey(t));
      for (final type in unowned) {
        expect(
          tabIndexFromRouteType(type),
          isNull,
          reason:
              '$type gained a tab index without updating this test. Adding a '
              'tab arm changes tab history and Android back behaviour.',
        );
      }
    });

    test('inbox and notifications share tab 2, the inbox branch', () {
      expect(
        tabIndexFromRouteType(RouteType.inbox),
        equals(tabIndexFromRouteType(RouteType.notifications)),
      );
    });
  });

  group('routeTypeForTab', () {
    test('every tab resolves to a route the same tab owns', () {
      for (var tab = 0; tab <= 3; tab++) {
        expect(tabIndexFromRouteType(routeTypeForTab(tab)), equals(tab));
      }
    });

    test('falls back to home for an out-of-range index', () {
      expect(routeTypeForTab(-1), equals(RouteType.home));
      expect(routeTypeForTab(4), equals(RouteType.home));
    });
  });

  group('tabName', () {
    test('names tab 2 Inbox, matching the bottom-nav label', () {
      expect(tabName(2), equals('Inbox'));
    });
  });
}
